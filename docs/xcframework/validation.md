# XCFramework 实施与验证记录

最新本地验证日期：2026-10-12。工作分支：`xcframework`。

## 当前本地检查

- 自动测试：43 runs / 305 assertions / 0 failures / 0 errors（包含平台范围、arm64_sim 和失败命令诊断回归测试）。
- `scripts/xcframework/*.rb`、`tests/xcframework/*_test.rb` Ruby 语法检查通过。
- 默认 iOS 计划的模拟器切片使用 SDKSettings 支持的 `arm64` / `x86_64`，并在 metadata 中将 simulator arm64 标记为 `arm64_sim`。
- 默认 iOS 范围规划：仅包含声明 iOS 的最新 Git Pod；不声明 iOS 的 Git Pod 会记录为 scope skip。
- `all` 范围仍可规划全部 20 个最新 Git Pod；6 个最新非 Git Pod 被跳过：LookInsideServer、OggKit、OpusFileKit、OpusKit、amrnb、amrwb。
- 原始 podspec 未修改；没有使用 `gh`。
- 构建命令失败时现在会把前 15 条 `error:`/`fatal:` 编译诊断和末尾 Xcode 清理日志同时写入异常，完整日志仍保存在 `logs/<task-id>/`。

本轮增加或修复的回归项：root 依赖不再被解析为 `B/B`；合法 `default_subspec = :none`；显式 subspec 不激活 root 默认功能；显式依赖 subspec、父级依赖、嵌套默认 subspec 和传递依赖闭包；多个 subspec 请求合并并写入 Podfile；传递依赖更新触发父 Pod 重建；历史无效约束/缺失 subspec 保守全量回退；指定名称只校验相关依赖闭包；Builder 的计划校验不扫描无关 root；失败 archive 的关键编译错误不会被 Xcode 尾部清理日志遮蔽。

## 真实构建证据及边界

本地 Xcode 27.0（27A266a）已完成 YYCache、ZDTinyLayout 的真实构建；远端 GitHub Actions 已完成默认 `ios` 范围的计划、矩阵、完整性校验和 Release 发布。`all` 范围的历史运行仍暴露了非 iOS 平台源码兼容性问题。

| Pod | 已构建 SDK | 说明 |
| --- | --- | --- |
| YYCache 1.0.5 | iphoneos / iphonesimulator | archive、import 校验、XCFramework 与 ZIP |
| ZDTinyLayout 0.0.2 | iphoneos / iphonesimulator / appletvos / appletvsimulator / macosx / xros / xrsimulator | Swift import、privacy bundle、XCFramework 与 ZIP |

ZDTinyLayout 的 GitHub 网络不稳定，集成 harness 使用此前已由 `git ls-remote` 验证的 tag SHA `59039ddd1968512bb550c32d7ec0cde1b854b356`；真实 CocoaPods install、archive、校验和打包均执行。该 harness 位于忽略目录 `.tmp/validation/`，未加入生产 workflow。

历史 `all` 范围运行（2026-10-12，run `38224786309`）结果：plan 成功，20 个矩阵任务中 17 个成功；Diagnostics 7.0.0、SDWebImageWebPCoder 0.15.0.1、Masonry 1.2.5 因源码平台兼容性失败，Release 按门禁正确跳过。随后默认 `ios` 范围运行（2026-10-12，run `38257128218`）20/20 成功，Release `xcframeworks-38257128218-1` 创建成功，包含 20 个 Pod ZIP、manifest 和 SHA256SUMS。通过公共 GitHub API 下载 manifest 验证：`platform_scope=ios`，全部 slice 均为 iOS，模拟器架构为 `arm64 + x86_64`，标签集合包含 `arm64_sim`。

已在本地重现并确认根因：Masonry 在 tvOS 无条件调用 `keyboardLayoutGuide`；Diagnostics 的 tvOS 源码使用高于声明最低版本的 API 且调用 tvOS 不提供的容量属性；SDWebImageWebPCoder 的 macOS 分支调用仅在 UIKit/watchOS 条件下定义的方法。这些不是构建器可以安全隐式修复的问题，当前保持严格失败，避免发布不可用二进制。

## 已部署与未验证项

- `xcframework` 分支已推送：`09f9a0c9c941730e64bbc7e92a0ca7d83d5f6524`。
- main 监听桥已推送：`21479c7`，只新增 `.github/workflows/sync-xcframeworks.yml`。本轮只更新了 `xcframework` 中的模板，未更改 main；自动构建使用 reusable workflow 的默认 `ios`，main 手动入口的 `all` 下拉选项需另行同步模板。
- 默认 `ios` Actions 已真实执行并发布成功：20/20 成功，Release 已创建；`all` 范围的历史运行仍为 17/20，Release 未创建。
- `actionlint` 安装因 Go proxy 网络超时失败；workflow 通过 YAML 解析与静态回归断言，**仍未通过 actionlint 验证**。
- 官方镜像清单访问未成功，因此不能可靠确认当前宿主 macOS 版本。`xcode-27` 标签和运行时 Xcode 27 检查已通过远端验证；严格锁定 macOS 26 + Xcode 27 仍需经过验证的 runner。
- 上传不是原子操作；当前 workflow 只有全矩阵成功才进入 `softprops/action-gh-release@v3`，并由 aggregate 校验 manifest/SHA256。

## 失败 Pod 的定位证据

| Pod / 首个失败平台 | 本地编译错误 | 修复边界 |
| --- | --- | --- |
| Masonry 1.2.5 / tvOS | `View+MASAdditions.m:175` 起，`keyboardLayoutGuide` unavailable on tvOS | 需要为键盘 guide 的声明/实现补充 tvOS 条件；不能删除整个 tvOS 平台 |
| Diagnostics 7.0.0 / tvOS | `UpdateAvailableInsight.swift:24` 的 `region`、`AppSystemMetadataReporter.swift:105` 的 `language/languageCode` 要求 tvOS 16；`Device.swift:56` 的容量属性在 tvOS 不存在 | 需要 availability fallback 和平台适配；仅抬高最低版本不能修复容量属性 |
| SDWebImageWebPCoder 0.15.0.1 / macOS | `SDImageWebPCoder.m:354`，no known class method for selector `animatedImageWithFrames:` | 定义位于 `SD_UIKIT || SD_WATCH` 条件内，调用却无条件；需要确认 macOS 语义再适配，不能盲目替换成返回类型不同的 SDImageCoderHelper 方法 |

三个任务都通过生产 `plan.rb` / `build.rb` 本地重建定位，没有跳过编译、替换下载引用或修改原始 podspec。历史 `all` 构建在首个错误平台停止，**其中后续非 iOS 平台尚未完整验收**；这三个 Pod 的 iOS slice 已在 run `38257128218` 中通过。完整日志分别位于 `logs/Masonry-1.2.5/`、`logs/Diagnostics-7.0.0/`、`logs/SDWebImageWebPCoder-0.15.0.1/`；这些目录被 gitignore 忽略，不提交编译产物。

## 后续验收

1. 分支和 main 监听桥已经部署，不必再次合并或安装。
2. 默认 `ios` Release、manifest、SHA256SUMS 已通过远端验证；仍需用消费项目进行链接与运行测试。
3. 如选择 `all`，需要先修复并验收三个失败 Pod 的非 iOS 声明平台；当前不隐式改变第三方源码。

具体命令、权限要求、资源和依赖集成方式见 `docs/xcframework/README.md`。
