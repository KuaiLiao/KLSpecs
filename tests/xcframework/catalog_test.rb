require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"
require_relative "../../scripts/xcframework/catalog" if File.exist?(File.expand_path("../../scripts/xcframework/catalog.rb", __dir__))

class CatalogTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def spec(name, version, source: "git", platforms: {"ios" => "12.0"}, dependencies: {})
    dir = File.join(@root, name, version)
    FileUtils.mkdir_p(dir)
    attrs = {"name" => name, "version" => version, "summary" => "Test", "homepage" => "https://example.com",
             "license" => "MIT", "authors" => "Test", "platforms" => platforms,
             "source" => source == "git" ? {"git" => "https://example.com/#{name}.git", "tag" => "v#{version}"} : {"http" => "https://example.com/prebuilt.zip"},
             "source_files" => "Sources/*.swift", "dependencies" => dependencies}
    File.write(File.join(dir, "#{name}.podspec.json"), JSON.generate(attrs))
  end


  def ruby_spec(name, version, body = "")
    dir = File.join(@root, name, version)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "#{name}.podspec"), <<~RUBY)
      Pod::Spec.new do |s|
        s.name = "#{name}"
        s.version = "#{version}"
        s.summary = "Test"
        s.homepage = "https://example.com"
        s.license = "MIT"
        s.author = "Test"
        s.platform = :ios, "12"
        s.source = { :git => "https://example.com/#{name}.git", :tag => "v#{version}" }
        s.source_files = "Sources/*.swift"
        #{body}
      end
    RUBY
  end

  def catalog
    assert defined?(XCFramework::Catalog), "Catalog implementation is missing"
    XCFramework::Catalog.new(@root)
  end

  def git(*args)
    out, status = Open3.capture2e("git", "-C", @root, *args)
    assert status.success?, out
    out.strip
  end

  def commit
    git("add", ".")
    git("-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "fixture")
    git("rev-parse", "HEAD")
  end

  def test_numeric_latest_and_declared_platforms_only
    spec("A", "1.9", platforms: {"ios" => "12"})
    spec("A", "1.10", platforms: {"osx" => "10.15", "visionos" => "1.0"})
    task = catalog.plan.fetch("tasks").first
    assert_equal "1.10", task.fetch("version")
    assert_equal %w[osx visionos], task.fetch("platforms").keys.sort
    assert_equal "v1.10", task.fetch("source").fetch("tag")
  end

  def test_latest_http_does_not_fall_back_to_old_git
    spec("A", "1.0")
    spec("A", "2.0", source: "http")
    assert_empty catalog.plan.fetch("tasks")
  end

  def test_local_dependency_uses_latest_and_rejects_incompatible_constraint
    spec("A", "1", dependencies: {"B" => ["~> 2.0"]})
    spec("B", "2.1")
    spec("B", "2.9")
    a = catalog.plan.fetch("tasks").find { |task| task["name"] == "A" }
    assert_equal "2.9", a.fetch("local_dependencies").first.fetch("version")
    spec("B", "3.0")
    assert_raises(ArgumentError) { catalog.plan }
  end

  def test_local_http_dependency_fails_explicitly
    spec("A", "1", dependencies: {"B" => []})
    spec("B", "1", source: "http")
    assert_raises(ArgumentError) { catalog.plan }
  end

  def test_old_spec_edit_is_ignored_but_dependency_update_rebuilds_dependents
    git("init", "-q")
    spec("A", "1", dependencies: {"B" => [">= 1"]})
    spec("B", "1")
    spec("B", "2")
    base = commit
    spec("B", "1", platforms: {"ios" => "13"})
    commit
    assert_empty catalog.plan(base: base).fetch("tasks")
    spec("B", "3")
    commit
    assert_equal %w[A B], catalog.plan(base: base).fetch("tasks").map { |t| t["name"] }
  end

  def test_latest_deletion_reselects_previous_version
    git("init", "-q")
    spec("A", "1")
    spec("A", "2")
    base = commit
    FileUtils.rm_rf(File.join(@root, "A", "2"))
    commit
    assert_equal "1", catalog.plan(base: base).fetch("tasks").first.fetch("version")
  end

  def test_tooling_changes_force_full_plan
    git("init", "-q")
    spec("A", "1")
    base = commit
    FileUtils.mkdir_p(File.join(@root, "scripts", "xcframework"))
    File.write(File.join(@root, "scripts", "xcframework", "build.rb"), "# updated")
    commit
    assert_equal 1, catalog.plan(base: base).fetch("tasks").size
  end

  def test_unknown_pod_filter_is_not_silently_ignored
    spec("A", "1")
    assert_raises(ArgumentError) { catalog.plan(names: ["Typo"]) }
  end
  def test_requested_local_subspec_and_nested_defaults_produce_complete_dependency_closure
    ruby_spec("A", "1", <<~RUBY)
      s.dependency "B/Extra"
    RUBY
    ruby_spec("B", "1", <<~RUBY)
      s.default_subspec = "Core"
      s.subspec "Core" do |ss|
        ss.source_files = "Sources/Core/*.swift"
      end
      s.subspec "Extra" do |ss|
        ss.dependency "C"
        ss.source_files = "Sources/Extra/*.swift"
      end
    RUBY
    spec("C", "1")
    task = catalog.plan.fetch("tasks").find { |t| t["name"] == "A" }
    assert_equal %w[B C], task.fetch("local_dependencies").map { |d| d.fetch("name") }
    b = task.fetch("local_dependencies").find { |d| d["name"] == "B" }
    assert_includes b.fetch("subspecs"), "B/Extra"

    ruby_spec("D", "1", <<~RUBY)
      s.default_subspec = "Group"
      s.subspec "Group" do |ss|
        ss.default_subspec = "Leaf"
        ss.subspec "Leaf" do |sss|
          sss.dependency "C"
        end
      end
    RUBY
    d = catalog.plan.fetch("tasks").find { |t| t["name"] == "D" }
    assert_equal ["C"], d.fetch("local_dependencies").map { |dep| dep.fetch("name") }
  end

  def test_invalid_history_falls_back_to_full_current_plan
    git("init", "-q")
    spec("A", "1", dependencies: {"B" => ["~> 1.0"]})
    spec("B", "2")
    base = commit
    FileUtils.rm_rf(File.join(@root, "A"))
    spec("A", "1", dependencies: {"B" => ["~> 2.0"]})
    commit
    result = nil
    _, err = capture_io { result = catalog.plan(base: base) }
    assert_includes err, "Historical catalog cannot be compared"
    assert_equal %w[A B], result.fetch("tasks").map { |t| t.fetch("name") }
  end

  def test_named_plan_ignores_unrelated_invalid_root
    spec("Good", "1")
    spec("Bad", "1", dependencies: {"B" => ["~> 1"]})
    spec("B", "2")
    assert_equal ["Good"], catalog.plan(names: ["Good"]).fetch("tasks").map { |t| t.fetch("name") }
  end

  def test_default_subspec_none_is_supported
    ruby_spec("A", "1", <<~RUBY)
      s.default_subspec = :none
      s.subspec "Optional" do |ss|
        ss.dependency "B"
      end
    RUBY
    spec("B", "1")
    task = catalog.plan(names: ["A"]).fetch("tasks").first
    assert_empty task.fetch("local_dependencies")
    assert_equal ["A"], task.fetch("subspecs").fetch("ios")
  end

  def test_explicit_subspec_does_not_activate_root_default_subspec
    ruby_spec("A", "1", 's.dependency "B/Extra"')
    ruby_spec("B", "1", <<~RUBY)
      s.default_subspec = "Core"
      s.subspec "Core" do |ss|
        ss.dependency "C"
      end
      s.subspec "Extra" do |ss|
        ss.dependency "D"
      end
    RUBY
    spec("C", "1")
    spec("D", "1")
    deps = catalog.plan(names: ["A"]).fetch("tasks").first.fetch("local_dependencies")
    assert_equal ["B", "D"], deps.map { |dep| dep.fetch("name") }
  end

  def test_multiple_requests_union_defaults_ancestors_and_transitive_subspec_dependencies
    ruby_spec("A", "1", 's.dependency "B/Extra"; s.dependency "B"')
    ruby_spec("B", "1", <<~RUBY)
      s.default_subspec = "Core"
      s.subspec "Core" do |ss|
        ss.dependency "C"
      end
      s.subspec "Extra" do |ss|
        ss.dependency "D/Group/Leaf"
      end
    RUBY
    spec("C", "1")
    ruby_spec("D", "1", <<~RUBY)
      s.default_subspec = :none
      s.subspec "Group" do |ss|
        ss.dependency "E"
        ss.subspec "Leaf" do |sss|
          sss.dependency "F"
        end
      end
    RUBY
    spec("E", "1")
    spec("F", "1")
    deps = catalog.plan(names: ["A"]).fetch("tasks").first.fetch("local_dependencies")
    assert_equal %w[B C D E F], deps.map { |dep| dep.fetch("name") }
    b = deps.find { |dep| dep["name"] == "B" }
    assert_equal %w[B B/Extra], b.fetch("requested").sort
    assert_includes b.fetch("subspecs"), "B/Core"
    d = deps.find { |dep| dep["name"] == "D" }
    assert_includes d.fetch("subspecs"), "D/Group"
  end

  def test_nested_subspec_without_explicit_defaults_selects_all_children
    ruby_spec("A", "1", <<~RUBY)
      s.subspec "Group" do |ss|
        ss.subspec "Leaf" do |sss|
          sss.dependency "B"
        end
      end
    RUBY
    spec("B", "1")
    assert_equal ["B"], catalog.plan(names: ["A"]).fetch("tasks").first.fetch("local_dependencies").map { |dep| dep.fetch("name") }
  end

  def test_subspec_transitive_dependency_update_rebuilds_selected_root
    git("init", "-q")
    ruby_spec("A", "1", 's.dependency "B/Extra"')
    ruby_spec("B", "1", <<~RUBY)
      s.default_subspec = "Core"
      s.subspec "Core" do |ss|
        ss.source_files = "Sources/Core/*.swift"
      end
      s.subspec "Extra" do |ss|
        ss.dependency "C"
      end
    RUBY
    spec("C", "1")
    base = commit
    spec("C", "2")
    commit
    assert_equal ["A"], catalog.plan(base: base, names: ["A"]).fetch("tasks").map { |task| task.fetch("name") }
  end

  def test_bad_historical_subspec_is_recoverable_but_current_errors_are_not
    git("init", "-q")
    ruby_spec("A", "1", 's.dependency "B/DoesNotExist"')
    spec("B", "1")
    base = commit
    ruby_spec("A", "1", 's.dependency "B"')
    commit
    result = nil
    _, err = capture_io { result = catalog.plan(base: base) }
    assert_includes err, "Historical catalog cannot be compared"
    assert_equal %w[A B], result.fetch("tasks").map { |task| task.fetch("name") }
    ruby_spec("A", "1", 's.dependency "B/DoesNotExist"')
    assert_raises(Pod::Informative) { catalog.plan(base: base) }
  end

end
