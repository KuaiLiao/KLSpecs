require "minitest/autorun"
require "tmpdir"
require "json"
require_relative "../../scripts/xcframework/builder" if File.exist?(File.expand_path("../../scripts/xcframework/builder.rb", __dir__))

class BuilderTest < Minitest::Test
  def builder_class
    assert defined?(XCFramework::Builder), "Builder implementation is missing"
    XCFramework::Builder
  end

  def test_declared_platform_maps_to_device_and_simulator_not_catalyst
    definitions = builder_class.slices("visionos")
    assert_equal %w[xros xrsimulator], definitions.map { |s| s.fetch("sdk") }
    assert_equal [nil, "simulator"], definitions.map { |s| s["variant"] }
    assert_equal 1, builder_class.slices("osx").size
    assert_raises(ArgumentError) { builder_class.slices("unknown") }
  end

  def test_sdk_architectures_and_floor_are_taken_from_sdk_settings
    target = {"MinimumDeploymentTarget" => "15.0", "Archs" => %w[arm64 arm64e]}
    info = builder_class.sdk_configuration("ios", "iphoneos", "7.0", {"SupportedTargets" => {"iphoneos" => target}})
    assert_equal "15.0", info.fetch("minimum")
    assert_equal ["arm64"], info.fetch("architectures")
    assert_equal ["arm64"], info.fetch("architecture_labels")
    simulator = builder_class.sdk_configuration("ios", "iphonesimulator", "7.0", {"SupportedTargets" => {"iphonesimulator" => {"MinimumDeploymentTarget" => "15.0", "Archs" => %w[arm64 x86_64]}}})
    assert_equal %w[arm64 x86_64], simulator.fetch("architectures")
    assert_equal %w[arm64_sim x86_64], simulator.fetch("architecture_labels")
    info = builder_class.sdk_configuration("ios", "iphoneos", "16.0", {"SupportedTargets" => {"iphoneos" => target}})
    assert_equal "16.0", info.fetch("minimum")
  end

  def test_builder_revalidates_against_the_plan_platform_scope
    task = {"id" => "MacOnly-1.0", "name" => "MacOnly", "fingerprint" => "fingerprint"}
    plan = {"platform_scope" => "all", "repository_commit" => "abcdef"}
    requested = nil
    catalog = Object.new
    catalog.define_singleton_method(:tasks) do |names:, platforms:|
      requested = [names, platforms]
      [task]
    end
    catalog.define_singleton_method(:git) { |*_args| "abcdef\n" }

    Dir.mktmpdir do |root|
      XCFramework::Catalog.stub(:new, catalog) do
        builder_class.new(root, plan, task, File.join(root, "dist"))
      end
    end

    assert_equal [["MacOnly"], "all"], requested
  end

  def test_generated_podfile_uses_external_specs_and_not_path_install
    task = {"name" => "A", "path" => "A/1/A.podspec", "subspecs" => {"ios" => ["A"]}}
    dependencies = [{"name" => "B", "path" => "B/2/B.podspec"}]
    text = builder_class.podfile(task, "ios", "15.0", "/repo", dependencies)
    assert_includes text, ':podspec => "/repo/A/1/A.podspec"'
    assert_includes text, ':podspec => "/repo/B/2/B.podspec"'
    refute_includes text, ':path =>'
    assert_includes text, 'use_frameworks! :linkage => :static'
    assert_includes text, 'BUILD_LIBRARY_FOR_DISTRIBUTION'
    assert_includes text, 'XCScheme'
    assert_includes text, 'xcframework-raw-resources.json'
  end

  def test_archive_commands_set_distribution_skip_install_and_architectures
    args = builder_class.archive_arguments(project: "/p/Pods.xcodeproj", scheme: "A", destination: "generic/platform=iOS", archive: "/a", derived: "/d", architectures: %w[arm64])
    assert_includes args, "SKIP_INSTALL=NO"
    assert_includes args, "BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
    assert_includes args, "ARCHS=arm64"
    assert_includes args, "CODE_SIGNING_ALLOWED=NO"
  end
  def test_collect_resources_from_archive_build_products_not_intermediate_copies
    Dir.mktmpdir do |root|
      derived = File.join(root, "derived")
      products = File.join(derived, "ArchiveIntermediates", "A", "BuildProductsPath", "Release-iphoneos", "A")
      intermediate = File.join(derived, "ArchiveIntermediates", "A", "IntermediateBuildFilesPath", "UninstalledProducts", "iphoneos", "Privacy.bundle")
      FileUtils.mkdir_p([products, intermediate])
      File.write(File.join(intermediate, "PrivacyInfo.xcprivacy"), "privacy")
      File.symlink(intermediate, File.join(products, "Privacy.bundle"))
      spec = Pod::Specification.new do |s|
        s.name = "A"
        s.version = "1.0"
        s.ios.deployment_target = "15.0"
        s.resource_bundles = {"Privacy" => ["PrivacyInfo.xcprivacy"]}
      end
      catalog = Object.new
      catalog.define_singleton_method(:selections) { |*_args| [[], [spec]] }
      builder = builder_class.allocate
      builder.instance_variable_set(:@catalog, catalog)
      builder.instance_variable_set(:@task, {"name" => "A"})
      builder.instance_variable_set(:@staging, File.join(root, "package"))
      assert_equal ["Privacy.bundle"], builder.collect_resources(derived, "iphoneos")
      assert_equal "privacy", File.read(File.join(root, "package", "Resources", "iphoneos", "Privacy.bundle", "PrivacyInfo.xcprivacy"))
    end
  end

  def test_copies_uncompiled_pod_resources_and_preserves_localizations
    Dir.mktmpdir do |root|
      source = File.join(root, "source", "Assets.bundle")
      localized = File.join(root, "source", "zh-Hans.lproj", "Localizable.strings")
      FileUtils.mkdir_p([source, File.dirname(localized)])
      File.write(File.join(source, "image.png"), "image")
      File.write(localized, "translation")
      builder = builder_class.allocate
      destination = File.join(root, "package")
      names = builder.copy_raw_resources([source, localized], destination, [])
      assert_equal ["Assets.bundle", "zh-Hans.lproj/Localizable.strings"], names.sort
      assert_equal "image", File.read(File.join(destination, "Assets.bundle", "image.png"))
      assert_equal "translation", File.read(File.join(destination, "zh-Hans.lproj", "Localizable.strings"))
      assert_raises(RuntimeError) { builder.copy_raw_resources([source], destination, ["Assets.bundle"]) }
    end
  end

  def test_collects_macos_bundles_moved_into_archive_with_dangling_build_product_links
    Dir.mktmpdir do |root|
      derived = File.join(root, "derived")
      products = File.join(derived, "ArchiveIntermediates", "A", "BuildProductsPath", "Release", "A")
      archive = File.join(root, "macosx.xcarchive")
      bundle = File.join(archive, "Products", "Library", "Bundles", "Privacy.bundle")
      FileUtils.mkdir_p([products, bundle])
      File.write(File.join(bundle, "privacy"), "privacy")
      File.symlink("/missing/InstallationBuildProductsLocation/Privacy.bundle", File.join(products, "Privacy.bundle"))
      spec = Pod::Specification.new do |s|
        s.name = "A"
        s.version = "1.0"
        s.osx.deployment_target = "12.0"
        s.resource_bundles = {"Privacy" => ["privacy"]}
      end
      catalog = Object.new
      catalog.define_singleton_method(:selections) { |*_args| [[], [spec]] }
      builder = builder_class.allocate
      builder.instance_variable_set(:@catalog, catalog)
      builder.instance_variable_set(:@task, {"name" => "A"})
      builder.instance_variable_set(:@staging, File.join(root, "package"))
      assert_equal ["Privacy.bundle"], builder.collect_resources(derived, "macosx", [], archive: archive)
      assert File.file?(File.join(root, "package", "Resources", "macosx", "Privacy.bundle", "privacy"))
    end
  end

  def test_generated_podfile_preserves_all_requested_dependency_subspecs
    task = {"name" => "A", "path" => "A.podspec", "subspecs" => {"ios" => ["A"]}}
    deps = [{"name" => "B", "path" => "B.podspec", "requested" => ["B", "B/Extra"]}]
    text = builder_class.podfile(task, "ios", "15", "/repo", deps)
    assert_includes text, 'pod "B", :podspec => "/repo/B.podspec"'
    assert_includes text, 'pod "B/Extra", :podspec => "/repo/B.podspec"'
  end

  def test_failed_command_exposes_compiler_diagnostics_before_long_archive_tail
    Dir.mktmpdir do |root|
      builder = builder_class.allocate
      builder.instance_variable_set(:@root, root)
      builder.instance_variable_set(:@logs, root)
      script = "puts 'Sources/View.m:12:3: error: unavailable on tvOS'; 80.times { |i| puts \"Archive progress \#{i}\" }; exit 65"
      error = assert_raises(RuntimeError) { builder.run(RbConfig.ruby, "-e", script) }
      assert_includes error.message, "error: unavailable on tvOS"
      assert_includes error.message, "Archive progress 79"
      assert_includes error.message, "Command failed (65)"
      assert_includes File.read(Dir.glob(File.join(root, "*.log")).first), "Archive progress 0"
    end
  end

end
