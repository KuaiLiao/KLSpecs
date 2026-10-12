# XCFramework Platform Scope Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Add a configurable platform scope whose default builds only iOS device and simulator XCFramework slices, while retaining an explicit all-platform mode.

**Architecture:** Carry a normalized `ios` or `all` scope from workflow input to `plan.rb`, through `Catalog#plan`, into the immutable build plan. The catalog filters each latest Git pod's declared platforms before calculating subspec and local dependency closures; the builder remains platform-agnostic and builds the platforms present in the plan. Simulator metadata labels the actual `arm64` simulator architecture as `arm64_sim` without pretending it is a separate Mach-O lipo architecture.

**Tech Stack:** Ruby, CocoaPods, Minitest, GitHub Actions reusable workflows, Xcode 27.

**Spec:** `docs/superpowers/specs/2026-10-11-xcframework-design.md`

## Global Constraints

- Default scope is `ios`; it includes only podspec-declared iOS platforms and builds iOS device plus iOS simulator.
- Default iOS device architecture is `arm64`; default simulator architectures are `arm64` (`arm64_sim` metadata label) and `x86_64` when supported by SDKSettings.
- `all` preserves the existing behavior of building every platform declared by the podspec.
- `source.http` latest pods remain skipped and latest-version selection is unchanged.
- No original podspec is modified; no `gh` command is used.
- Xcode 27 remains required and `softprops/action-gh-release@v3` remains the Release action.

## Review Focus

- A latest Pod declaring only macOS must be omitted from the default iOS plan but included by `all`; catalog scope tests pin this.
- A Pod with iOS plus non-iOS declarations must have only iOS in the default task and only iOS dependency closure; catalog tests pin this.
- Invalid or empty scopes must fail clearly instead of silently producing an empty build; catalog/CLI tests pin this.
- Workflow dispatch and reusable-call inputs must default to `ios` and pass the selected scope; workflow tests pin this.
- Existing all-platform behavior must remain available; regression tests run the `all` scope.

### Task 1: Catalog and plan scope

**Files:**
- Modify: `scripts/xcframework/catalog.rb`
- Modify: `scripts/xcframework/plan.rb`
- Test: `tests/xcframework/catalog_test.rb`

- [x] Add failing tests for default iOS filtering, explicit all-platform mode, and invalid scope.
- [x] Run the focused catalog tests and observe the expected failures.
- [x] Implement normalized scope handling, filtered platform/dependency selection, and scope metadata in the plan.
- [x] Add `--platforms ios|all` to the plan CLI with default `ios`.
- [x] Run focused tests and the full unit suite.

### Task 2: Workflow option propagation

**Files:**
- Modify: `.github/workflows/build-xcframeworks.yml`
- Modify: `docs/xcframework/sync-main.yml`
- Modify: `tests/xcframework/workflow_test.rb`

- [x] Add failing assertions for default `ios` workflow inputs and forwarding to the plan/reusable workflow.
- [x] Run workflow tests and observe the expected failures.
- [x] Add workflow-dispatch and workflow-call inputs, defaulting to `ios`, and pass `BUILD_PLATFORMS` to `plan.rb`.
- [x] Forward the main workflow input to the reusable workflow.
- [x] Run workflow tests and YAML parsing checks.

### Task 3: iOS architecture metadata and documentation

**Files:**
- Modify: `scripts/xcframework/builder.rb`
- Modify: `tests/xcframework/builder_test.rb`
- Modify: `docs/xcframework/README.md`
- Modify: `docs/xcframework/validation.md`

- [x] Add a failing builder test for the `arm64_sim` metadata label.
- [x] Implement labels while keeping actual archive/lipo architectures valid.
- [x] Update usage, manual dispatch, release notes, and validation status for the new default.
- [x] Run full tests, syntax checks, plan generation, and diff checks.

### Task 4: Commit and remote verification

**Files:**
- All files above.

- [x] Review the diff for accidental podspec or generated-artifact changes.
- [ ] Commit the implementation on `xcframework`.
- [ ] Push the branch without using `gh`.
- [ ] Verify the pushed commit and workflow YAML through repository checks/API where available.
