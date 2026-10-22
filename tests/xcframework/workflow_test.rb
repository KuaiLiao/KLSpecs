require "minitest/autorun"
require "yaml"

class WorkflowTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  def file(path)
    full = File.join(ROOT, path)
    assert File.file?(full), "Missing workflow #{path}"
    YAML.load_file(full)
  end
  def test_build_uses_xcode_27_reusable_interface_and_empty_plan_gate
    workflow = file(".github/workflows/build-xcframeworks.yml")
    assert workflow.fetch("on").key?("workflow_call")
    assert_equal ["xcframework"], workflow.dig("on", "push", "branches")
    assert_equal "xcode-27", workflow.dig("jobs", "build", "runs-on")
    assert_equal "ios", workflow.dig("on", "workflow_dispatch", "inputs", "platforms", "default")
    assert_equal "ios", workflow.dig("on", "workflow_call", "inputs", "platforms", "default")
    assert_includes workflow.dig("jobs", "plan", "steps").map { |step| step["run"] }.compact.join("\n"), "--platforms"
    assert_includes workflow.dig("jobs", "plan", "steps").map { |step| step["env"] }.compact.join("\n"), "BUILD_PLATFORMS"
    assert_includes workflow.dig("jobs", "build", "if"), "has_tasks"
    refute workflow.dig("jobs", "build", "strategy", "fail-fast")
    release = workflow.dig("jobs", "release")
    assert_equal "write", release.dig("permissions", "contents")
    action = release.fetch("steps").find { |s| s["uses"]&.start_with?("softprops/") }
    assert_equal "softprops/action-gh-release@v3", action["uses"]
    assert_equal true, action.dig("with", "fail_on_unmatched_files")
  end
  def test_main_bridge_calls_reusable_workflow_without_dispatch_or_gh
    workflow = file("docs/xcframework/sync-main.yml")
    assert_equal ["main"], workflow.dig("on", "push", "branches")
    assert workflow.dig("jobs", "build", "uses").end_with?("/build-xcframeworks.yml@xcframework")
    assert_includes workflow.dig("jobs", "build", "with", "revision"), "revision"
    assert_equal "ios", workflow.dig("on", "workflow_dispatch", "inputs", "platforms", "default")
    assert_includes workflow.dig("jobs", "build", "with").keys, "platforms"
    text = File.read(File.join(ROOT, "docs/xcframework/sync-main.yml"))
    refute_match(/\bgh\s+(api|release|workflow|run)/, text)
    refute_includes text, "createWorkflowDispatch"
    assert_includes text, 'SOURCE_SHA=$(git rev-parse origin/main)'
  end
end
