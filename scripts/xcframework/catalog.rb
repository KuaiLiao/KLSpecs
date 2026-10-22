# frozen_string_literal: true
require "cocoapods"
require "json"
require "yaml"
require "digest"
require "open3"
require "pathname"

module XCFramework
  class Catalog
    SPEC_PATTERN = /\.podspec(?:\.json)?\z/
    TOOLING_PATTERN = %r{\A(?:scripts/xcframework/|config/xcframework-build\.yml|Gemfile(?:\.lock)?$|\.github/workflows/|tests/xcframework/)}
    PLATFORMS = %w[ios osx tvos watchos visionos].freeze
    attr_reader :root, :entries, :config

    def initialize(root, ref: nil)
      @root = File.expand_path(root)
      config_path = "config/xcframework-build.yml"
      config_text = ref ? git("show", "#{ref}:#{config_path}", allow_failure: true) : (File.read(File.join(@root, config_path)) if File.file?(File.join(@root, config_path)))
      @config = config_text ? YAML.safe_load(config_text) || {} : {}
      paths = ref ? git("ls-tree", "-r", "--name-only", ref).lines.map(&:strip).grep(SPEC_PATTERN) : Dir.glob("**/*.{podspec,podspec.json}", base: @root).sort.reject { |p| p.start_with?(".tmp/", "vendor/") }
      @entries = paths.map do |path|
        text = ref ? git("show", "#{ref}:#{path}") : File.read(File.join(@root, path))
        spec = Pod::Specification.from_string(text, Pathname.new(File.join(@root, path)))
        {"spec" => spec, "path" => path, "sha256" => Digest::SHA256.hexdigest(text)}
      end.group_by { |entry| entry["spec"].name }.transform_values do |versions|
        highest = versions.map { |entry| entry["spec"].version }.max
        matches = versions.select { |entry| entry["spec"].version == highest }
        raise ArgumentError, "Duplicate latest spec: #{matches.map { |e| e['path'] }.join(', ')}" unless matches.size == 1
        matches.first
      end
    end

    def git(*args, allow_failure: false)
      stdout, stderr, status = Open3.capture3("git", "-C", root, *args)
      return nil if allow_failure && !status.success?
      raise "git #{args.first}: #{stderr}" unless status.success?
      stdout
    end

    def selections(name, platform, requested: nil)
      entry = entries.fetch(name)
      spec = entry.fetch("spec")
      overrides = requested || config.dig("pods", name, "subspecs", platform)
      requested_names = overrides ? Array(overrides).map { |sub| normalize_subspec_name(name, sub) } : [name]
      [requested_names, selected_specs(spec, platform, overrides && Array(overrides))]
    end

    def normalize_subspec_name(parent_name, name)
      text = name.to_s
      root_name = parent_name.split("/").first
      text == root_name || text.start_with?("#{root_name}/") ? text : "#{parent_name}/#{text}"
    end

    def default_specs(spec, root_spec)
      defaults = Array(spec.default_subspecs)
      return [] if defaults.any? { |sub| sub.to_s == "none" }
      return spec.subspecs if defaults.empty?
      defaults.map do |sub|
        root_spec.subspec_by_name(normalize_subspec_name(spec.name, sub))
      end
    end

    def selected_specs(root_spec, platform, overrides = nil)
      result = []
      expanded = []
      queue = overrides ? overrides.map { |sub| root_spec.subspec_by_name(normalize_subspec_name(root_spec.name, sub)) } : [root_spec]
      until queue.empty?
        spec = queue.shift
        next if expanded.include?(spec)
        expanded << spec
        # Explicit leaf selections inherit parent dependencies, but do not select the parent's defaults.
        ancestors = []
        node = spec
        while node
          ancestors.unshift(node)
          node = node.parent
        end
        ancestors.each do |ancestor|
          next if result.include?(ancestor)
          raise ArgumentError, "#{ancestor.name} does not support #{platform}" unless ancestor.available_platforms.any? { |p| p.name.to_s == platform }
          result << ancestor
          ancestor.consumer(platform.to_sym).dependencies.each do |dependency|
            next unless dependency.root_name == root_spec.name && dependency.name != root_spec.name
            queue << root_spec.subspec_by_name(dependency.name)
          end
        end
        # A requested subspec does not implicitly activate the root's default
        # subspecs. Defaults are expanded only for the actual selected node;
        # the root node is actual only when it was requested as root.
        queue.concat(default_specs(spec, root_spec))
      end
      result
    end

    def local_dependencies(name, platform)
      grouped = {}
      visited = []
      queue = [[name, nil]]
      until queue.empty?
        current_name, requested = queue.shift
        key = [current_name, requested]
        next if visited.include?(key)
        visited << key
        requested_names, selected = selections(current_name, platform, requested: requested)
        unless current_name == name
          entry = entries.fetch(current_name)
          spec = entry.fetch("spec")
          record = (grouped[current_name] ||= {"name" => current_name, "version" => spec.version.to_s, "path" => entry["path"], "sha256" => entry["sha256"], "subspecs" => [], "requested" => []})
          record["requested"] |= requested_names
          record["subspecs"] |= selected.map(&:name)
        end
        selected.flat_map { |spec| spec.consumer(platform.to_sym).dependencies }.each do |dependency|
          next if dependency.root_name == current_name
          entry = entries[dependency.root_name]
          next unless entry # Non-local dependencies remain CocoaPods-resolved and are recorded in the lockfile.
          spec = entry.fetch("spec")
          raise ArgumentError, "#{current_name}: latest #{spec.name} #{spec.version} fails #{dependency.requirement}" unless dependency.requirement.satisfied_by?(spec.version)
          raise ArgumentError, "#{current_name}: HTTP/non-git local dependency #{spec.name} is excluded" unless spec.source["git"] || spec.source[:git]
          raise ArgumentError, "#{current_name}: #{spec.name} does not declare #{platform}" unless spec.attributes_hash.fetch("platforms", {}).key?(platform)
          queue << [spec.name, dependency.name == dependency.root_name ? nil : dependency.name]
        end
      end
      grouped.values.each { |record| record["requested"].sort!; record["subspecs"].sort! }.sort_by { |record| record["name"] }
    end

    def normalize_platform_scope(scope)
      values = Array(scope).flat_map { |value| value.to_s.split(",") }.map(&:strip).reject(&:empty?).uniq
      raise ArgumentError, "platform scope must be ios or all" if values.empty?
      return PLATFORMS if values == ["all"]
      raise ArgumentError, "platform scope must be ios or all" unless values == ["ios"]
      ["ios"]
    end

    def tasks(names: nil, platforms: "ios")
      platform_scope = normalize_platform_scope(platforms)
      selected_names = names ? names : entries.keys
      entries.keys.sort.filter_map do |name|
        next unless selected_names.include?(name)
        entry = entries.fetch(name)
        spec = entry.fetch("spec")
        source = spec.source.transform_keys(&:to_s)
        next unless source["git"]
        declared_platforms = spec.attributes_hash.fetch("platforms", {}).transform_values { |v| v || "0" }
        raise ArgumentError, "#{name}: explicit platforms required" if declared_platforms.empty?
        raise ArgumentError, "#{name}: unknown platforms #{declared_platforms.keys - PLATFORMS}" unless (declared_platforms.keys - PLATFORMS).empty?
        platforms = declared_platforms.select { |platform, _| platform_scope.include?(platform) }
        next if platforms.empty?
        local = platforms.keys.flat_map { |platform| local_dependencies(name, platform) }.uniq { |dependency| dependency["name"] }.sort_by { |dependency| dependency["name"] }
        task = {"id" => "#{name}-#{spec.version}".gsub(/[^A-Za-z0-9_.-]/, "_"), "name" => name, "version" => spec.version.to_s,
                "path" => entry["path"], "spec_sha256" => entry["sha256"], "source" => source,
                "module_name" => spec.module_name, "platforms" => platforms, "local_dependencies" => local,
                "subspecs" => platforms.keys.to_h { |platform| [platform, selections(name, platform).first] }}
        task["fingerprint"] = Digest::SHA256.hexdigest(JSON.generate(task))
        task
      end
    end

    def plan(base: nil, names: [], platforms: "ios")
      platform_scope = normalize_platform_scope(platforms)
      unknown = names - entries.keys
      raise ArgumentError, "Unknown pods: #{unknown.join(', ')}" unless unknown.empty?
      current = tasks(names: names.empty? ? nil : names, platforms: platforms)
      if base && !base.empty? && base !~ /\A0+\z/
        changed = git("diff", "--name-only", base, "HEAD").lines.map(&:strip)
        unless changed.any? { |path| path.match?(TOOLING_PATTERN) }
          begin
            previous = Catalog.new(root, ref: base).tasks(platforms: platforms).to_h { |task| [task["name"], task["fingerprint"]] }
            current = current.reject { |task| previous[task["name"]] == task["fingerprint"] }
          rescue StandardError => error
            warn "Historical catalog cannot be compared; rebuilding current selections: #{error.message}"
            # A broken historical catalog cannot be compared safely. Validate and rebuild current selections instead.
          end
        end
      end
      skipped = entries.filter_map do |name, entry|
        spec = entry.fetch("spec")
        source = spec.source
        unless source.keys.any? { |key| key.to_s == "git" }
          {"name" => name, "version" => spec.version.to_s, "reason" => "latest source is not git"}
        else
          declared = spec.attributes_hash.fetch("platforms", {}).keys.map(&:to_s)
          next unless (declared & platform_scope).empty?
          {"name" => name, "version" => spec.version.to_s, "reason" => "podspec does not declare #{platform_scope.join(', ')}"}
        end
      end
      {"schema" => 1, "platform_scope" => (platform_scope == PLATFORMS ? "all" : "ios"), "tasks" => current, "skipped" => skipped}
    end
  end
end
