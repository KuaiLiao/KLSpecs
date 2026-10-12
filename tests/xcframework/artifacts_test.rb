require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "json"
require "digest"
require_relative "../../scripts/xcframework/artifacts" if File.exist?(File.expand_path("../../scripts/xcframework/artifacts.rb", __dir__))

class ArtifactsTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir
  end
  def teardown
    FileUtils.remove_entry(@root)
  end
  def artifacts_class
    assert defined?(XCFramework::Artifacts), "Artifacts implementation is missing"
    XCFramework::Artifacts
  end
  def fixture(id = "A-1", valid = true)
    package = File.join(@root, id, "Metadata")
    FileUtils.mkdir_p(package)
    metadata = {"id" => id, "name" => "A", "version" => "1", "fingerprint" => "abc", "repository_commit" => "sha",
                "validated" => valid, "slices" => [{"platform" => "ios", "minimum" => "15.0"}]}
    File.write(File.join(package, "build-info.json"), JSON.generate(metadata))
    system("zip", "-qr", "#{id}.xcframework.zip", id, chdir: @root) or raise "zip failed"
    metadata["asset"] = "#{id}.xcframework.zip"
    metadata["sha256"] = Digest::SHA256.file(File.join(@root, metadata["asset"])).hexdigest
    File.write(File.join(@root, "#{id}.build.json"), JSON.generate(metadata))
    metadata
  end
  def plan
    {"repository_commit" => "sha", "tasks" => [{"id" => "A-1", "fingerprint" => "abc"}]}
  end
  def test_missing_task_blocks_release
    assert_raises(ArgumentError) { artifacts_class.aggregate(plan, @root) }
  end
  def test_checksum_mismatch_blocks_release
    m = fixture
    File.open(File.join(@root, m["asset"]), "a") { |f| f.write("corrupt") }
    assert_raises(ArgumentError) { artifacts_class.aggregate(plan, @root) }
  end
  def test_unvalidated_package_blocks_release
    fixture("A-1", false)
    assert_raises(ArgumentError) { artifacts_class.aggregate(plan, @root) }
  end
  def test_fingerprint_and_commit_mismatch_block_release
    fixture
    bad = Marshal.load(Marshal.dump(plan))
    bad["tasks"][0]["fingerprint"] = "wrong"
    assert_raises(ArgumentError) { artifacts_class.aggregate(bad, @root) }
    bad = Marshal.load(Marshal.dump(plan))
    bad["repository_commit"] = "wrong"
    assert_raises(ArgumentError) { artifacts_class.aggregate(bad, @root) }
  end
  def test_complete_plan_writes_manifest_checksums_and_notes
    fixture
    result = artifacts_class.aggregate(plan, @root)
    assert_equal 1, result.fetch("packages").size
    assert File.file?(File.join(@root, "manifest.json"))
    assert_includes File.read(File.join(@root, "SHA256SUMS")), "A-1.xcframework.zip"
    assert_includes File.read(File.join(@root, "release-notes.md")), "A"
  end
  def test_unexpected_or_duplicate_assets_block_release
    fixture
    fixture("B-1")
    assert_raises(ArgumentError) { artifacts_class.aggregate(plan, @root) }
  end
end
