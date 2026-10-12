require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"
require_relative "../../scripts/xcframework/sync" if File.exist?(File.expand_path("../../scripts/xcframework/sync.rb", __dir__))

class SyncTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir
    git("init", "-q", "-b", "main")
    write("A/1/A.podspec", "old")
    commit
    git("checkout", "-qb", "xcframework")
    write("scripts/xcframework/build.rb", "keep me")
    commit
  end
  def teardown
    FileUtils.remove_entry(@root)
  end
  def git(*args)
    out, status = Open3.capture2e("git", "-C", @root, *args)
    assert status.success?, out
    out.strip
  end
  def write(path, content)
    FileUtils.mkdir_p(File.dirname(File.join(@root, path)))
    File.write(File.join(@root, path), content)
  end
  def commit
    git("add", ".")
    git("-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "fixture")
    git("rev-parse", "HEAD")
  end
  def synchronizer(sha)
    assert defined?(XCFramework::Sync), "Sync implementation missing"
    XCFramework::Sync.new(@root, sha)
  end
  def test_copies_specs_and_removes_deleted_specs_without_overwriting_tools
    git("checkout", "main")
    FileUtils.rm_f(File.join(@root, "A/1/A.podspec"))
    write("A/2/A.podspec.json", '{"version":"2"}')
    write("README.md", "main content not mirrored")
    sha = commit
    git("checkout", "xcframework")
    changes = synchronizer(sha).call
    assert_equal ["A/1/A.podspec", "A/2/A.podspec.json"], changes.sort
    refute File.exist?(File.join(@root, "A/1/A.podspec"))
    assert_equal '{"version":"2"}', File.read(File.join(@root, "A/2/A.podspec.json"))
    assert_equal "keep me", File.read(File.join(@root, "scripts/xcframework/build.rb"))
    refute File.exist?(File.join(@root, "README.md"))
  end
  def test_noop_has_no_changes
    sha = git("rev-parse", "main")
    assert_empty synchronizer(sha).call
  end
  def test_rejects_symbolic_link_specs
    git("checkout", "main")
    File.symlink("/etc/passwd", File.join(@root, "A/1/Unsafe.podspec"))
    sha = commit
    git("checkout", "xcframework")
    assert_raises(ArgumentError) { synchronizer(sha).call }
  end
  def test_rejects_non_sha_source
    assert_raises(ArgumentError) { synchronizer("main; malicious") }
  end
  def test_rejects_symlink_directory_in_target_checkout
    Dir.mktmpdir do |outside|
      git("checkout", "main")
      write("B/1/B.podspec", "new")
      sha = commit
      git("checkout", "xcframework")
      File.symlink(outside, File.join(@root, "B"))
      assert_raises(ArgumentError) { synchronizer(sha).call }
      refute File.exist?(File.join(outside, "1", "B.podspec"))
    end
  end

end
