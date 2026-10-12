# XCFramework Implementation Plan

> **For agentic workers:** Use executing-plans to implement locally, task-by-task. No parallel delegation is requested.

**Goal:** Build the latest Git-sourced pods on their declared platforms and publish validated archives from xcframework.
**Architecture:** Ruby planner, per-platform CocoaPods installer/archive builder, manifest-based validator and aggregator; reusable GitHub workflow and main synchronization bridge.
**Tech Stack:** Ruby 3.3, CocoaPods, xcodeproj, Minitest, Xcode 27, GitHub Actions.
**Spec:** docs/superpowers/specs/2026-10-11-xcframework-design.md

## Global Constraints
- Skip source.http; choose the latest version before filtering.
- Only declared platforms; prioritize Xcode 27 using xcode-27 runner.
- Never use gh; use softprops/action-gh-release.
- Original specs remain unchanged; work stays on xcframework locally; no automatic remote push.

## Review Focus
- Numeric versions and latest HTTP transitions must not select old source pods.
- Old-spec edits must not rebuild latest; latest dependencies must propagate changes.
- Main synchronization must preserve tooling and deletion semantics without token-trigger loops.
- Missing slices/resources and mismatched checksums must block release.
- SDK floors and platform-specific subspec selection must be recorded, not silently broaden platforms.

### Task 1: Planning and dependency selection
Files: Gemfile/lock, config/xcframework-build.yml, scripts/xcframework/catalog.rb, plan.rb, tests/xcframework/catalog_test.rb.
- [x] Write tests for numeric latest, HTTP exclusion, exact platform selection, dependency constraints and incremental closure.
- [x] Run tests RED, implement Catalog and planner, run GREEN.

### Task 2: Build and verify artifacts
Files: scripts/xcframework/build.rb, artifacts.rb, aggregate.rb, tests/xcframework/artifacts_test.rb, builder_test.rb.
- [x] Write tests for slice mapping, SDK floors, Podfile/scheme generation and artifact integrity.
- [x] Run RED, implement CocoaPods install, archives, packaging, validation and aggregation; run GREEN.
- [x] Try one real source build locally using Xcode 27; retain honest execution limitations.

### Task 3: Branch automation and deployment documentation
Files: scripts/xcframework/sync.rb, .github/workflows/build-xcframeworks.yml, docs/xcframework/sync-main.yml, docs/xcframework/README.md, tests/xcframework/sync_test.rb, workflow_test.rb, .gitignore.
- [x] Test branch sync preserving tooling, additions/deletions, workflow gating and no gh invocation RED then GREEN.
- [x] Add reusable build workflow and main bridge template with fixed-SHA checkout.
- [x] Document pushing xcframework, installing bridge in main, manual rebuild and consuming resources/dependencies.
- [x] Run all tests, syntax checks, real catalog plan and git diff checks; review complete diff locally.

## Execution notes
No commits or pushes are performed without a separate deployment request. Tests are the completion evidence; unexecuted full-matrix builds remain explicitly unverified.


## Verification record (2026-10-11)

- RED/GREEN observed for planner, builder settings, artifact integrity and synchronization; additional regressions cover archive product paths, macOS archive resource relocation, raw/localized resources, target symlink refusal and latest-main synchronization.
- Fresh suite: 28 runs / 207 assertions / 0 failures / 0 errors. All 12 Ruby files passed `ruby -c`; workflow YAML parsed by unit tests. Catalog produced 20 latest Git roots and 6 skipped latest non-Git roots. No original podspec file was modified.
- Real YYCache 1.0.5 integration: Git download, iOS device/simulator archive, import validation, XCFramework/ZIP and aggregator succeeded.
- Real ZDTinyLayout 0.0.2 integration: ios/tvos/osx/visionos, seven SDK slices, Swift interfaces and all privacy bundles, XCFramework/ZIP and aggregator succeeded. Integration harness substituted the already verified tag SHA `59039ddd1968512bb550c32d7ec0cde1b854b356` for an unreliable network ls-remote; CocoaPods install, every archive, import validation and packaging were real. Harness stays ignored under .tmp and is not CI code.
- BRPickerView integration was attempted but blocked during remote Git ref resolution by connection failures; raw-resource behavior has automated unit coverage but this Pod's real build remains unverified.
- actionlint installation was attempted and blocked by proxy.golang.org connectivity; YAML tests are not a substitute for full Actions service validation.
- Independent read-only review requested for planner/branch automation. Review findings and fixes recorded below after completion.
- No remote branch push, commit, main workflow installation, GitHub matrix run or Release upload has been performed. These are deployment / integration gates, not implied by local tests.
