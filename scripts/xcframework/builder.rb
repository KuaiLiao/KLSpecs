# frozen_string_literal: true
require_relative "catalog"
require "xcodeproj"
require "fileutils"
require "shellwords"

module XCFramework
  class Builder
    PLATFORM = {
      "ios" => ["ios", "IPHONEOS_DEPLOYMENT_TARGET", [["iphoneos", "iOS"], ["iphonesimulator", "iOS Simulator"]]],
      "osx" => ["macos", "MACOSX_DEPLOYMENT_TARGET", [["macosx", "macOS"]]],
      "tvos" => ["tvos", "TVOS_DEPLOYMENT_TARGET", [["appletvos", "tvOS"], ["appletvsimulator", "tvOS Simulator"]]],
      "watchos" => ["watchos", "WATCHOS_DEPLOYMENT_TARGET", [["watchos", "watchOS"], ["watchsimulator", "watchOS Simulator"]]],
      "visionos" => ["xros", "XROS_DEPLOYMENT_TARGET", [["xros", "visionOS"], ["xrsimulator", "visionOS Simulator"]]]
    }.freeze

    def self.slices(platform)
      definition = PLATFORM.fetch(platform) { raise ArgumentError, "Unknown platform #{platform}" }
      definition[2].map do |sdk, display|
        {"platform" => platform, "supported_platform" => definition[0], "sdk" => sdk,
         "destination" => "generic/platform=#{display}", "variant" => ("simulator" if sdk.end_with?("simulator"))}
      end
    end

    def self.sdk_configuration(platform, sdk, declared, settings)
      target = settings.fetch("SupportedTargets").fetch(sdk)
      preferred = platform == "watchos" && sdk == "watchos" ? %w[arm64 arm64_32] : (sdk.end_with?("simulator") || sdk == "macosx" ? %w[arm64 x86_64] : %w[arm64])
      archs = preferred & target.fetch("Archs")
      raise ArgumentError, "No supported architectures for #{sdk}" if archs.empty?
      labels = archs.map { |arch| sdk.end_with?("simulator") && arch == "arm64" ? "arm64_sim" : arch }
      {"minimum" => [Pod::Version.new(declared), Pod::Version.new(target.fetch("MinimumDeploymentTarget"))].max.to_s,
       "architectures" => archs, "architecture_labels" => labels}
    end

    def self.podfile(task, platform, minimum, root, dependencies)
      declarations = task.fetch("subspecs").fetch(platform).map { |name| [name, task.fetch("path")] }
      declarations += dependencies.flat_map { |d| d.fetch("requested", [d.fetch("name")]).map { |name| [name, d.fetch("path")] } }
      lines = declarations.map { |name, path| "  pod #{name.inspect}, :podspec => #{File.join(root, path).inspect}" }
      <<~RUBY
        source 'https://cdn.cocoapods.org/'
        platform #{platform.to_sym.inspect}, #{minimum.inspect}
        install! 'cocoapods', :integrate_targets => false, :deterministic_uuids => true
        use_frameworks! :linkage => :static
        target 'BinaryHost' do
        #{lines.join("\n")}
        end
        post_install do |installer|
          raw_resources = installer.pod_targets.flat_map do |pod_target|
            pod_target.file_accessors.select { |accessor| accessor.spec.library_specification? }.flat_map do |accessor|
              accessor.resources.flatten.reject { |path| Pod::Target.resource_extension_compilable?(File.extname(path.to_s)) }.map(&:to_s)
            end
          end.uniq
          File.write('xcframework-raw-resources.json', JSON.generate(raw_resources))
          installer.pods_project.targets.each do |target|
            target.build_configurations.each do |configuration|
              configuration.build_settings[#{PLATFORM.fetch(platform)[1].inspect}] = #{minimum.inspect}
              configuration.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
              configuration.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
              if target.product_type == 'com.apple.product-type.framework'
                configuration.build_settings['SKIP_INSTALL'] = 'NO'
                configuration.build_settings['INSTALL_PATH'] = '$(LOCAL_LIBRARY_DIR)/Frameworks'
              end
            end
            next unless target.product_type == 'com.apple.product-type.framework'
            scheme = Xcodeproj::XCScheme.new
            scheme.add_build_target(target)
            scheme.set_launch_target(target)
            scheme.archive_action.build_configuration = 'Release'
            scheme.save_as(installer.pods_project.path, target.name, true)
          end
        end
      RUBY
    end

    def self.archive_arguments(project:, scheme:, destination:, archive:, derived:, architectures:)
      ["xcodebuild", "archive", "-project", project, "-scheme", scheme, "-configuration", "Release",
       "-destination", destination, "-archivePath", archive, "-derivedDataPath", derived,
       "SKIP_INSTALL=NO", "BUILD_LIBRARY_FOR_DISTRIBUTION=YES", "CODE_SIGNING_ALLOWED=NO",
       "ONLY_ACTIVE_ARCH=NO", "ARCHS=#{architectures.join(' ')}"]
    end

    def initialize(root, plan, task, output)
      @root, @plan, @task = root, plan, task
      @output = File.expand_path(output)
      @work = File.join(root, ".tmp", "xcframework", task.fetch("id"))
      @logs = File.join(root, "logs", task.fetch("id"))
      @staging = File.join(@work, task.fetch("id"))
      FileUtils.rm_rf(@work)
      FileUtils.mkdir_p([@work, @logs, @output, File.join(@staging, "Metadata"), File.join(@staging, "Licenses")])
      @catalog = Catalog.new(root)
      current = @catalog.tasks(names: [task.fetch("name")], platforms: plan.fetch("platform_scope", "ios")).find { |t| t["id"] == task["id"] }
      raise ArgumentError, "Stale or altered build plan" unless current && current["fingerprint"] == task["fingerprint"]
      sha = @catalog.git("rev-parse", "HEAD").strip
      raise ArgumentError, "Plan checkout does not match HEAD" unless sha == plan.fetch("repository_commit")
      @metadata = task.merge("platform_scope" => plan.fetch("platform_scope", "ios"), "repository_commit" => sha,
                             "validated" => false, "slices" => [], "sources" => {})
    end

    def run(*args, chdir: @root)
      label = args.first.gsub(/[^A-Za-z0-9]/, "_")
      log = File.join(@logs, "#{label}.log")
      puts "+ #{Shellwords.join(args)}"
      text = +""
      status = nil
      File.open(log, "a") do |file|
        file.puts "$ #{Shellwords.join(args)}"
        Open3.popen2e(*args, chdir: chdir) do |stdin, stdout, wait|
          stdin.close
          stdout.each_line { |line| file.write(line); text << line }
          status = wait.value
        end
      end
      unless status.success?
        # Archive errors often occur long before Xcode's final cleanup output.
        # Keep the full log on disk, but surface diagnostics in the CI console.
        diagnostics = text.lines.grep(/\b(?:error|fatal):/i).uniq.first(15)
        summary = (diagnostics + text.lines.last(35)).uniq.map { |line| line.chomp[0, 1500] }.join("\n")
        raise "Command failed (#{status.exitstatus}); #{log}\n#{summary}"
      end
      text
    end

    def pin_specs
      names = [@task["name"]] + @task["local_dependencies"].map { |d| d["name"] }
      names.each do |name|
        spec = @catalog.entries.fetch(name).fetch("spec")
        source = spec.source.transform_keys(&:to_s)
        commit = source["commit"]
        unless commit && commit.match?(/\A[0-9a-f]{40}\z/i)
          ref = source["tag"] ? "refs/tags/#{source['tag']}" : source["branch"] ? "refs/heads/#{source['branch']}" : "HEAD"
          refs = run("git", "ls-remote", "--exit-code", source.fetch("git"), ref, "#{ref}^{}").lines.map { |line| line.split(/\s+/) }.to_h { |sha, key| [key, sha] }
          commit = refs["#{ref}^{}"] || refs[ref]
          raise "Cannot resolve declared commit #{source['commit']}" if source["commit"] && source["commit"] != commit
        end
        raise "Cannot resolve source for #{name}" unless commit && commit.match?(/\A[0-9a-f]{40}\z/i)
        @metadata["sources"][name] = {"declared" => source, "commit" => commit}
        attrs = spec.to_hash
        attrs["source"] = source.reject { |key, _| %w[tag branch commit].include?(key) }.merge("commit" => commit)
        FileUtils.mkdir_p(File.join(@work, "specs"))
        File.write(File.join(@work, "specs", "#{name}.podspec.json"), JSON.pretty_generate(attrs))
      end
      File.write(File.join(@staging, "Metadata", "original.podspec.json"), JSON.pretty_generate(@catalog.entries.fetch(@task["name"]).fetch("spec").to_hash))
    end

    def build
      version = run("xcodebuild", "-version").strip
      raise "Xcode 27 required, found #{version}" unless version.match?(/\AXcode 27(?:\.|\s)/)
      @metadata["xcode"] = version
      @metadata["swift"] = run("xcrun", "swift", "--version").strip
      @metadata["cocoapods"] = Pod::VERSION
      pin_specs
      inputs = []
      @task.fetch("platforms").each do |platform, declared|
        definitions = self.class.slices(platform)
        dependencies = @catalog.local_dependencies(@task["name"], platform)
        required = ([declared] + dependencies.map { |d| @catalog.entries.fetch(d["name"]).fetch("spec").attributes_hash.fetch("platforms").fetch(platform) }).map { |v| Pod::Version.new(v) }.max.to_s
        definitions.each do |slice|
          sdk_path = run("xcrun", "--sdk", slice.fetch("sdk"), "--show-sdk-path").strip
          settings = JSON.parse(File.read(File.join(sdk_path, "SDKSettings.json")))
          slice.merge!(self.class.sdk_configuration(platform, slice["sdk"], required, settings))
          slice["declared_minimum"] = declared
          slice["sdk_path"] = sdk_path
        end
        minimum = definitions.map { |s| Pod::Version.new(s["minimum"]) }.max.to_s
        definitions.each { |s| s["minimum"] = minimum }
        work = File.join(@work, platform)
        FileUtils.mkdir_p(work)
        pinned_task = @task.merge("path" => "specs/#{@task['name']}.podspec.json")
        pinned_dependencies = dependencies.map { |d| d.merge("path" => "specs/#{d['name']}.podspec.json") }
        File.write(File.join(work, "Podfile"), self.class.podfile(pinned_task, platform, minimum, @work, pinned_dependencies))
        run("bundle", "exec", "pod", "install", chdir: work)
        project_path = File.join(work, "Pods", "Pods.xcodeproj")
        project = Xcodeproj::Project.open(project_path)
        target = project.targets.find { |t| t.name == @task["name"] && t.product_type == "com.apple.product-type.framework" }
        raise "No unique root framework target #{@task['name']}" unless target
        product = File.basename(target.product_reference.path, ".framework")
        raise "Product mismatch #{product} != #{@task['module_name']}" unless product == @task["module_name"]
        FileUtils.cp(File.join(work, "Podfile.lock"), File.join(@staging, "Metadata", "Podfile-#{platform}.lock"))
        root_source = File.join(work, "Pods", @task["name"])
        license = @catalog.entries.fetch(@task["name"]).fetch("spec").license
        license_file = license.is_a?(Hash) ? license[:file] || license["file"] : nil
        if license_file
          source_file = File.join(root_source, license_file)
          FileUtils.cp(source_file, File.join(@staging, "Licenses", File.basename(license_file))) if File.file?(source_file)
        end
        Dir.glob(File.join(root_source, "{LICENSE*,license*,COPYING*,NOTICE*}"), File::FNM_CASEFOLD).each { |f| FileUtils.cp(f, File.join(@staging, "Licenses", File.basename(f))) if File.file?(f) }
        definitions.each do |slice|
          sdk = slice.fetch("sdk")
          archive = File.join(work, "#{sdk}.xcarchive")
          derived = File.join(work, "derived-#{sdk}")
          run(*self.class.archive_arguments(project: project_path, scheme: target.name, destination: slice["destination"], archive: archive, derived: derived, architectures: slice["architectures"]), chdir: work)
          framework = File.join(archive, "Products", "Library", "Frameworks", "#{product}.framework")
          raise "Missing archive framework #{framework}" unless File.directory?(framework)
          resources = collect_resources(derived, sdk, JSON.parse(File.read(File.join(work, "xcframework-raw-resources.json"))), archive: archive)
          slice["resources"] = resources
          validate_framework(framework, slice, work, derived)
          @metadata["slices"] << slice.reject { |k, _| k == "sdk_path" }
          inputs += ["-framework", framework]
        end
      end
      xcframework = File.join(@staging, "#{@task['module_name']}.xcframework")
      run("xcodebuild", "-create-xcframework", *inputs, "-output", xcframework)
      validate_xcframework(xcframework)
      @metadata["validated"] = true
      File.write(File.join(@staging, "Metadata", "build-info.json"), JSON.pretty_generate(@metadata))
      asset = "#{@task['id']}.xcframework.zip"
      path = File.join(@output, asset)
      FileUtils.rm_f(path)
      run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", @staging, path)
      @metadata["asset"] = asset
      @metadata["sha256"] = Digest::SHA256.file(path).hexdigest
      File.write(File.join(@output, "#{@task['id']}.build.json"), JSON.pretty_generate(@metadata))
      puts "Validated #{path}"
    end

    def build_products(derived, extension)
      roots = [File.join(derived, "Build", "Products")]
      roots += Dir.glob(File.join(derived, "ArchiveIntermediates", "*", "BuildProductsPath"))
      roots.flat_map { |root| Dir.glob(File.join(root, "**", "*.#{extension}")) }.uniq
    end

    def collect_resources(derived, sdk, raw_resources = [], archive: nil)
      candidates = (archive ? Dir.glob(File.join(archive, "Products", "**", "*.bundle")) : []) + build_products(derived, "bundle")
      bundles = candidates.select { |p| File.directory?(p) }.reject { |p| p.match?(%r{\.bundle/.+\.bundle$}) }.uniq { |p| File.realpath(p) }
      destination = File.join(@staging, "Resources", sdk)
      FileUtils.mkdir_p(destination)
      names = bundles.map { |p| File.basename(p) }
      raise "Duplicate resource bundles for #{sdk}" unless names.uniq.size == names.size
      bundles.each { |p| FileUtils.cp_r(p, destination, preserve: true) }
      expected = @catalog.selections(@task['name'], self.class::PLATFORM.keys.find { |p| self.class.slices(p).any? { |s| s['sdk'] == sdk } }).last.flat_map { |s| s.consumer(self.class::PLATFORM.keys.find { |p| self.class.slices(p).any? { |t| t['sdk'] == sdk } }.to_sym).resource_bundles.keys }.uniq.map { |n| "#{n}.bundle" }
      raise "Missing resource bundles #{expected - names}" unless (expected - names).empty?
      (names + copy_raw_resources(raw_resources, destination, names)).sort
    end

    def copy_raw_resources(paths, destination, occupied)
      copied = []
      paths.uniq.each do |path|
        raise "Missing raw resource #{path}" unless File.exist?(path)
        # CocoaPods installs localized files below their language directory.
        parts = Pathname.new(path).each_filename.to_a
        localized = parts.rindex { |part| part.end_with?(".lproj") }
        name = localized ? File.join(*parts[localized..]) : File.basename(path)
        raise "Duplicate raw resource #{name}" if occupied.include?(name) || copied.include?(name)
        target = File.join(destination, name)
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp_r(path, target, preserve: true)
        copied << name
      end
      copied
    end

    def validate_framework(framework, slice, work, derived)
      binary = File.join(framework, @task["module_name"])
      archs = run("xcrun", "lipo", "-archs", binary).strip.split
      raise "Missing architectures #{slice['sdk']}: #{archs}" unless archs.sort == slice["architectures"].sort
      modules = File.join(framework, "Modules")
      raise "Missing module map for #{framework}" unless File.file?(File.join(modules, "module.modulemap"))
      swift_dir = File.join(modules, "#{@task['module_name']}.swiftmodule")
      raise "Missing Swift interfaces" if File.directory?(swift_dir) && Dir.glob(File.join(swift_dir, "*.swiftinterface")).empty?
      source = File.join(work, "ImportCheck.swift")
      File.write(source, "import #{@task['module_name']}\n")
      search_paths = ([File.dirname(framework)] + build_products(derived, "framework").map { |f| File.dirname(f) }).uniq
      slice["architectures"].each do |arch|
        os = {"ios" => "ios", "osx" => "macosx", "tvos" => "tvos", "watchos" => "watchos", "visionos" => "xros"}.fetch(slice["platform"])
        triple = "#{arch}-apple-#{os}#{slice['minimum']}#{'-simulator' if slice['variant']}"
        args = ["xcrun", "swiftc", "-typecheck", "-sdk", slice["sdk_path"], "-target", triple, source]
        args += search_paths.flat_map { |p| ["-F", p] }
        args += ["-I", File.join(work, "Pods", "Headers", "Public")]
        run(*args)
      end
    end

    def validate_xcframework(path)
      info = Xcodeproj::Plist.read_from_path(File.join(path, "Info.plist"))
      libraries = info.fetch("AvailableLibraries")
      raise "Unexpected slice count" unless libraries.size == @metadata["slices"].size
      @metadata["slices"].each do |slice|
        matches = libraries.select { |l| l["SupportedPlatform"] == slice["supported_platform"] && l["SupportedPlatformVariant"] == slice["variant"] }
        raise "Missing or duplicate #{slice['sdk']} slice" unless matches.size == 1
        library = matches.first
        raise "Wrong slice architectures" unless library.fetch("SupportedArchitectures").sort == slice["architectures"].sort
        raise "Missing slice payload" unless File.directory?(File.join(path, library.fetch("LibraryIdentifier"), library.fetch("LibraryPath")))
      end
    end
  end
end
