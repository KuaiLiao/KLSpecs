# XCFramework 实施与验证记录

最新本地验证日期：2026-10-12。工作分支：`xcframework`。

## 当前本地检查

- 自动测试：38 runs / 268 assertions / 0 failures / 0 errors。
- `scripts/xcframework/*.rb`、`tests/xcframework/*_test.rb` Ruby 语法检查通过。
- 全仓库规划：20 个最新 Git Pod；6 个最新非 Git Pod 被跳过。
- 跳过：LookInsideServer、OggKit、OpusFileKit、OpusKit、amrnb、amrwb。
- 原始 podspec 未修改；没有使用 `gh`。正在执行部署步骤，远端结果将在部署记录中单独说明。

本轮增加或修复的回归项：root 依赖不再被解析为 `B/B`；合法 `default_subspec = :none`；显式 subspec 不激活 root 默认功能；显式依赖 subspec、父级依赖、嵌套默认 subspec 和传递依赖闭包；多个 subspec 请求合并并写入 Podfile；传递依赖更新触发父 Pod 重建；历史无效约束/缺失 subspec 保守全量回退；指定名称只校验相关依赖闭包；Builder 的计划校验不扫描无关 root。

## 真实构建证据及边界

上一轮在本地 Xcode 27.0（27A266a）完成以下真实构建，本轮重新通过 aggregate 校验了已有 ZIP、SHA256 和内外元数据；**这不等于在最新代码下重新构建全部 Pod**。

| Pod | 已构建 SDK | 说明 |
| --- | --- | --- |
| YYCache 1.0.5 | iphoneos / iphonesimulator | archive、import 校验、XCFramework 与 ZIP |
| ZDTinyLayout 0.0.2 | iphoneos / iphonesimulator / appletvos / appletvsimulator / macosx / xros / xrsimulator | Swift import、privacy bundle、XCFramework 与 ZIP |

ZDTinyLayout 的 GitHub 网络不稳定，集成 harness 使用此前已由 `git ls-remote` 验证的 tag SHA `59039ddd1968512bb550c32d7ec0cde1b854b356`；真实 CocoaPods install、archive、校验和打包均执行。该 harness 位于忽略目录 `.tmp/validation/`，未加入生产 workflow。

BRPickerView 构建尝试被 GitHub 网络连接失败阻断，不能声称已通过。其余 Pod 尚未进行完整构建验收。

## 未验证/未部署

- `actionlint` 安装因 Go proxy 网络超时失败；workflow 目前通过 YAML 解析与静态回归断言，**未通过 actionlint 验证**。
- 官方 runner 镜像在线复核遇到网络错误/旧缓存；不能凭滚动 `xcode-27` 标签保证当前宿主是 macOS 26。Xcode 27 的运行时检查已加入 workflow。
- 远端 `xcframework` 分支未推送。
- main 监听模板未安装；main 尚未修改。
- GitHub Actions 矩阵、权限、Release 创建和附件上传尚未真实运行。
- 上传不是原子操作；失败批次可能留下不完整 Release，需核对 workflow 成功状态、manifest 和校验和。

## 启用顺序

1. 人工审查并提交、推送 `xcframework` 分支。
2. 在 main 单独安装 `docs/xcframework/sync-main.yml` 为 `.github/workflows/sync-xcframeworks.yml`，提交并推送。
3. 在 main 的 Actions 手动入口先指定 `YYCache` 验收，再执行全量构建。
4. 验证 Release 附件、manifest、SHA256SUMS；用消费项目进行链接与运行测试。

具体命令、权限要求、资源和依赖集成方式见 `docs/xcframework/README.md`。
