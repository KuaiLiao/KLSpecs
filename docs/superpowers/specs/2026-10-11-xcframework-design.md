# XCFramework build design

## Confirmed scope
- Work on branch `xcframework`; use the `xcode-27` GitHub-hosted runner, prioritizing Xcode 27 over macOS 26.
- Select the highest `Pod::Version` per root pod before filtering; skip roots whose latest spec is not `source.git`.
- Build only explicitly declared podspec platforms. Device and simulator are variants, not additional platforms. Do not add Catalyst.
- Preserve local podspec source refs, preparation commands, dependencies and resources. Use default subspecs, with an explicit BlocksKit non-iOS override because its default UIKit subspec is iOS-only.
- Create Releases using `softprops/action-gh-release`, never the gh CLI.

## Architecture and builder decisions
A Ruby planner emits a versioned JSON plan. Each pod is one matrix job, generating a CocoaPods project separately per platform, archiving device/simulator slices and assembling one XCFramework. CocoaPods downloads using local external podspecs, so prepare_command runs. Compatible source dependencies from this spec repo are pinned locally; external dependencies remain resolved by CocoaPods and recorded in lockfiles. Local HTTP-only dependencies fail explicitly instead of downloading them.
Use SDKSettings.json to determine supported architectures and deployment floors: effective minimum is max(spec minimum, SDK minimum, dependency minimum). Record both original and effective minimum; never claim old-OS compatibility silently. Do not disable library evolution to hide Swift failures.
Bundle resource products are shipped beside the XCFramework under platform-specific Resources directories, with original spec, dependency locks, licenses and metadata. Dependencies are not merged into the root binary. Validation checks all expected slices, actual architectures, headers/modules and compiles imports for each slice with dependency search paths.

## Automation
The build workflow lives on xcframework and supports direct branch pushes, manual runs and workflow_call. A lightweight main workflow (provided as an installation template, not applied to main here) checks out xcframework, copies only podspec files from the latest fetched main snapshot (the triggering commit must be its ancestor; old-event reruns cannot roll back specs), commits/pushes if needed, then calls the reusable build workflow at @xcframework with the exact synchronized SHA and previous SHA. This avoids suppressed token-push triggers and workflow_dispatch default-branch requirements. Only trusted main pushes initiate synchronization. Workflows serialize updates and do not cancel in-flight publication. Remote branch creation and installing the main bridge require deployment by the user.
Incremental plans compare latest spec fingerprints and selected local dependency closures across commits; old-version-only edits do not rebuild unchanged latest selections. Changes to build tooling rebuild everything. Manual runs rebuild all (or named roots). Empty plans skip matrix and publication. Each successful batch gets a unique release tag; all tasks must succeed before publication. Failed jobs retain logs.

## Non-goals and limitations
No HTTP pod repackaging, no changes to original podspecs, no automatic push from this local session, no XCFramework signing, no merging dependency symbols. Releases are binary downloads, not a fully implemented binary CocoaPods spec repository. GitHub full-matrix execution is the final integration gate; local tests cannot establish compatibility of every upstream source with Xcode 27.
