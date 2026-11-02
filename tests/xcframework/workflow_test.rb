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
    refute workflow.fetch("on").key?("push")
    assert_includes workflow.dig("jobs", "plan", "if"), "refs/heads/main"
    revision_step = workflow.dig("jobs", "plan", "steps").find { |step| step["id"] == "revision" }
    assert_includes revision_step.fetch("run"), '"$REQUESTED_REVISION" origin/main'
    plan_step = workflow.dig("jobs", "plan", "steps").find { |step| step["id"] == "plan" }
    assert_equal "${{ inputs.base || '' }}", plan_step.dig("env", "BUILD_BASE")
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
  def test_main_workflow_calls_reusable_workflow_from_the_same_commit
    workflow = file(".github/workflows/sync-xcframeworks.yml")
    assert_equal ["main"], workflow.dig("on", "push", "branches")
    assert_equal ["build"], workflow.fetch("jobs").keys
    assert_equal "github.ref == 'refs/heads/main'", workflow.dig("jobs", "build", "if")
    reference = workflow.dig("jobs", "build", "uses")
    assert_equal "./.github/workflows/build-xcframeworks.yml", reference
    assert file(reference).fetch("on").key?("workflow_call")
    assert_equal "${{ github.sha }}", workflow.dig("jobs", "build", "with", "revision")
    assert_equal "${{ github.event_name == 'push' && github.event.before || '' }}", workflow.dig("jobs", "build", "with", "base")
    assert_equal "${{ inputs.pods || '' }}", workflow.dig("jobs", "build", "with", "pods")
    assert_equal "${{ inputs.platforms || 'ios' }}", workflow.dig("jobs", "build", "with", "platforms")
    assert_equal "ios", workflow.dig("on", "workflow_dispatch", "inputs", "platforms", "default")
    paths = workflow.dig("on", "push", "paths")
    %w[**/*.podspec **/*.podspec.json scripts/xcframework/** tests/xcframework/** config/xcframework-build.yml Gemfile Gemfile.lock .github/workflows/build-xcframeworks.yml .github/workflows/sync-xcframeworks.yml].each do |path|
      assert_includes paths, path
    end
    text = File.read(File.join(ROOT, ".github/workflows/sync-xcframeworks.yml"))
    refute_match(/\bgh\s+(api|release|workflow|run)/, text)
    refute_includes text, "createWorkflowDispatch"
    refute_includes text, "git push"
  end
  def test_active_workflows_do_not_depend_on_the_deleted_branch
    Dir[File.join(ROOT, ".github/workflows/*.yml")].each do |path|
      refute_match(/@xcframework\b|origin\/xcframework\b|refs\/heads\/xcframework\b|ref: xcframework\b/, File.read(path))
    end
  end
  def test_documented_entrypoint_matches_the_installed_workflow
    assert_equal File.read(File.join(ROOT, ".github/workflows/sync-xcframeworks.yml")), File.read(File.join(ROOT, "docs/xcframework/sync-main.yml"))
  end
  def test_incremental_builds_do_not_replace_runs_for_other_commits
    caller = file(".github/workflows/sync-xcframeworks.yml").fetch("concurrency")
    callee = file(".github/workflows/build-xcframeworks.yml").fetch("concurrency")
    [caller, callee].each do |concurrency|
      assert_equal false, concurrency.fetch("cancel-in-progress")
    end
    assert_equal "xcframework-main-${{ github.sha }}", caller.fetch("group")
    assert_equal "xcframework-build-${{ inputs.revision || github.sha }}", callee.fetch("group")
    refute_equal caller.fetch("group"), callee.fetch("group")
  end
end
