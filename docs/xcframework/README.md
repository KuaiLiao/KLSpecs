# 最新源码 Pod → XCFramework → GitHub Release

> 部署状态（2026-10-12）：默认 `ios` 范围的 Actions run `38257128218` 已完成，20/20 个最新 Git Pod 成功，Release `xcframeworks-38257128218-1` 已创建。此前使用 `all` 范围的历史 run `38224786309` 有 3 个非 iOS 平台源码兼容性失败；详见 `validation.md`。

## 1. 已实现的范围

- 构建脚本和 workflow 已合入 `main`；直接构建 main 的确切提交，不再依赖已删除的 `xcframework` 分支，也不修改原始 podspec。
- 对每个 root Pod 按 CocoaPods 的 `Pod::Version` 选取最高版本，再判断来源；只有 `source.git` 生成任务。
- 最新版本是 `source.http` 时直接跳过，**不会退回旧的 Git 版本**。
- 默认平台范围是 `ios`：只处理 podspec 声明 iOS 的 Pod，构建 iOS 真机和模拟器。通过 `--platforms all` 或 Actions 的 `platforms: all` 可恢复按 podspec 声明的平台构建；不会额外添加 Catalyst 或未声明平台。
- 每个 Pod 一个矩阵任务；每个平台单独使用 CocoaPods 创建项目、执行 `prepare_command`、构建静态 framework，最后合并为一个 XCFramework。
- 使用 `softprops/action-gh-release@v3` 创建 Release 和上传附件，整个流程没有 `gh` 命令。
- 不需要个人访问令牌/PAT。创建 Release 使用 Actions 自动提供的 `GITHUB_TOKEN` 和相应的 `contents: write` 权限，不再生成或推送同步提交。

### Xcode 与最低系统版本

按“优先 Xcode 27”的要求，构建 job 使用 `runs-on: xcode-27`，并检查 `xcodebuild -version` 确实是 27，不静默降级到 Xcode 26。

构建 job 使用 GitHub Actions 官方当前可用的 `xcode-27` runner。macOS 版本跟随该 runner 的最新兼容版本，不要求固定为 macOS 26；workflow 会在 job 内校验 `xcodebuild -version` 必须为 Xcode 27。

官方参考：`actions/runner-images` 的 `images/macos/xcode-27-arm64-Readme.md` 和公告 #14404。不要把宿主 macOS 版本和 Xcode 自带的 macOS SDK 版本混为一谈。

实际 deployment target 是 `max(podspec 最低版本, 本仓库依赖最低版本, 当前 SDK 支持下限)`。声明值和实际值都写入元数据。Xcode 27 下不能把 iOS 15 构建的产物宣传为仍支持 iOS 7；消费方以 manifest 的实际最低版本为准。SDK 架构同样从 `SDKSettings.json` 读取，不硬塞不支持的架构。默认 iOS 范围下，真机为 `arm64`；模拟器为实际 `arm64 + x86_64`，其中 arm64 模拟器在元数据中标记为 `arm64_sim`。`arm64_sim` 是平台/切片标签，不是 `lipo -archs` 单独返回的 Mach-O 架构名。

## 2. 文件职责

| 文件 | 作用 |
| --- | --- |
| `.github/workflows/sync-xcframeworks.yml` | main 推送 / 手动入口，调用同提交的 reusable workflow |
| `.github/workflows/build-xcframeworks.yml` | 手动 / reusable 构建、验证、发布；不单独监听 push，避免重复构建 |
| `docs/xcframework/sync-main.yml` | 与 main 入口一致的部署模板 |
| `scripts/xcframework/catalog.rb`、`plan.rb` | 最高版本选择、平台及本仓库依赖分析、增量指纹、固定构建计划 |
| `scripts/xcframework/builder.rb`、`build.rb` | Git ref 固定为提交、CocoaPods 安装、archive、验证、ZIP 打包 |
| `scripts/xcframework/artifacts.rb`、`aggregate.rb` | 批次完整性、ZIP / SHA256 / 内外元数据校验和 Release 说明 |
| `scripts/xcframework/sync.rb` | 保留的历史分支镜像工具；当前 CI 不调用 |
| `config/xcframework-build.yml` | 必要的平台 subspec 选择覆盖 |
| `tests/xcframework/` | 规划、构建配置、资源、同步和发布校验回归测试 |
| `Gemfile`、`Gemfile.lock` | 固定 Ruby 依赖，支持 macOS ARM 与 Linux |

BlocksKit 默认选择 UIKit，但根 spec 同时声明 macOS/watchOS。配置中只对这两个平台明确选择 `Core` 与 `DynamicDelegate`；这不增加平台，也不修改原 podspec。其他 Pod 默认使用其默认 subspec，而不是强制构建所有可选 subspec。

## 3. 平台范围与运行方式

默认构建 iOS：

```sh
bundle exec ruby scripts/xcframework/plan.rb --platforms ios --output build-plan.json
```

如需保留所有 podspec 声明的平台：

```sh
bundle exec ruby scripts/xcframework/plan.rb --platforms all --output build-plan.json
```

main 入口、构建 workflow 和模板 `docs/xcframework/sync-main.yml` 均支持 `platforms` 参数，默认值为 `ios`，可选 `all`。计划中的 `platform_scope`、每个任务的 `platforms`、实际架构和 `architecture_labels` 会写入元数据。

## 4. 首次部署

> 原独立分支方案已迁移到 main。两个 workflow 必须随构建脚本一起提交；不需要重建 `xcframework` 分支。

### 第一步：将构建文件合入 main

检查构建脚本、配置、依赖、测试和两个 workflow，通过正常 PR 流程合入 main：

```sh
git status --short --branch
git add .gitignore .github Gemfile Gemfile.lock config docs scripts tests
git commit -m "ci: build xcframeworks directly from main"
```

构建脚本变更会做全量规划。入口使用 `./.github/workflows/build-xcframeworks.yml`，与调用方使用同一个提交中的 workflow，不需要远程分支引用，也不含固定仓库名。

### 第二步：保持入口与模板一致

`.github/workflows/sync-xcframeworks.yml` 是唯一的 push 入口。修改入口时同步更新模板；新仓库可从模板安装：

```sh
mkdir -p .github/workflows
cp docs/xcframework/sync-main.yml .github/workflows/sync-xcframeworks.yml
```

不要只把调用入口复制到不包含构建 workflow 和脚本的仓库。

### 第三步：权限和第一次运行

1. 仓库启用 GitHub Actions，组织策略允许使用本 workflow 中的第三方 Actions。
2. 入口向发布 job 授予 `contents: write`。确认 Actions token 没有被组织策略限制为只读；不需要允许 bot 推送分支。
3. 在 Actions 页面运行 **Build XCFrameworks from main**，选择 **main**：`pods` 留空做全量；填 `YYCache` 可先小批验收，填 `YYCache,SnapKit` 可做指定 Pod 重建。
4. 全部所选任务通过后，Release 包含 `*.xcframework.zip`、`manifest.json`、`SHA256SUMS`。

也可直接手动运行 **Build latest source XCFrameworks**，同样选择 main；非 main 分支会跳过构建。

## 5. 后续更新如何自动执行

```text
main 新增/修改/删除 podspec
  → main 监听 workflow
  → 直接调用同一提交中的 reusable workflow
  → checkout 事件的确切 main SHA，并校验它属于 main 历史
  → 使用 push 事件的 before SHA 进行增量比较（手动入口不传 base）
  → 规划变化的最新 Pod 和受本仓库依赖影响的 Pod
  → Xcode 27 分平台 archive / 校验 / 打包
  → 所选批次全部成功后 softprops 创建 Release 并上传
```

- 入口直接调用同提交的 reusable workflow，不推送同步提交，也不需要 PAT 或 REST dispatch。构建 workflow 不再独立监听 push，避免同一次更新重复发布。
- 重跑旧事件仍构建该事件的确切 SHA，不会回写或回滚仓库中的 spec；如需最新状态，手动选择 main 发起新运行。
- 依赖分析会展开实际请求的 subspec、父级依赖、嵌套默认 subspec 和传递依赖；Podfile 会保留这些明确请求，不把 `B/Extra` 错换成 `B` 的默认功能。
- 指定 `--pods` 时，只校验所选 root 和其依赖闭包，不被无关 Pod 的无效约束阻断。历史 catalog 无法解析或约束已失效时，放弃增量比较，保守地重建当前所选任务；当前 catalog 仍严格校验。
- 本仓库只选择最新依赖版本；如果不能满足依赖约束，会显式失败，**不偷偷下载本仓库的旧版本依赖**。本仓库 HTTP-only 依赖也会显式失败。
- 上游不在本仓库的依赖交给 CocoaPods 解析，结果写入 `Podfile-*.lock`；它们不是当前仓库的独立打包任务。
- 旧版本文件修改但最高版本和依赖指纹没变，不构建。最新版本删除后重新选择当前剩余的最高版本。只有被跳过的 HTTP Pod 变化也不发布空 Release。
- 脚本、依赖锁文件、配置、workflow 或测试变更导致全量重建。
- 入口和构建并发组按确切提交区分，不替换不同提交的等待运行；多个提交可能并行构建，失败批次需使用手动全量重建补齐。push 增量比较该事件的 before/after。
- 某个构建任务失败会阻止整批发布，其他任务继续完成并保存日志。修复后使用 main 手动入口全量或指定名称重建；不能指望之后无关 Pod 更新自动补发之前失败的 Pod。
- Release 创建与多个附件上传不是原子操作：上传阶段网络或权限失败时可能留下附件不完整的 Release。只消费成功运行发布的批次，并核对 manifest 与 SHA256SUMS；通过仓库页面删除失败批次，再重跑生成新批次。构建失败不会进入 Release job。
- 每批使用 `xcframeworks-<run_id>-<run_attempt>` 新标签，不覆盖原附件，也不替换仓库默认 Latest Release。增量 Release 只含本批发生变化的 Pod，不是全仓库所有 Pod 的快照。
- 如果 source 使用可变 branch/tag 而 podspec 文件本身没更新，不会因为远端 Git 变化自动触发；需要更新 spec 或手动重建。

## 6. 产物结构与集成注意事项

```text
<Pod>-<Version>.xcframework.zip
└── <Pod>-<Version>/
    ├── <Module>.xcframework/
    ├── Resources/<sdk>/              # 编译后的 bundle 和未编译的 resources
    ├── Licenses/
    └── Metadata/
        ├── original.podspec.json
        ├── build-info.json           # source commit、平台、实际最低版本、验证结果
        └── Podfile-<platform>.lock
```

消费方：

1. 校验 ZIP 的 SHA256，解压后集成 XCFramework；这些是静态 framework，不应按动态 framework 设置 Embed & Sign。
2. 仅复制当前 SDK 切片目录的资源到最终应用；`iphoneos` 和 `iphonesimulator` 的同名 bundle 不要一起复制。保留 `.lproj` 本地化目录结构。已编译并放在 framework 中的资源保留在对应 framework 内。
3. **依赖二进制不合并到 root binary**。查看 lockfile、原 spec 的依赖和系统库声明，分别集成兼容的源码或二进制依赖，添加所需的系统框架、库、链接选项（例如 ObjC 分类的 `-ObjC`）。可选依赖 subspec 的功能不保证存在于依赖 root Pod 的默认二进制中。
4. 不要同时源码和二进制集成同一个 Pod，避免重复符号。
5. 这里提供 Release 下载，**没有自动生成指向这些 ZIP 的 binary podspec 或 SPM Package**。需要 CocoaPods 自动消费时，应另加 binary spec 仓库配置资源、依赖和系统库。

验证包含 archive 成功、所需架构、module map、Swift interface、逐架构 Swift import typecheck、XCFramework 切片及 ZIP 完整性。不等同于完整消费应用链接、启动和功能测试；上游兼容性仍需要消费方验收。

## 7. 本地执行和排错

需要 Ruby 3.3、Xcode 27 和网络访问。所有命令都通过 Bundler 使用锁定版本：

```sh
bundle install
bundle exec ruby -Itests -e 'Dir["tests/xcframework/*_test.rb"].sort.each { |f| require_relative f }'
bundle exec ruby scripts/xcframework/plan.rb --pods YYCache --output build-plan.json
bundle exec ruby scripts/xcframework/build.rb --plan build-plan.json --task YYCache-1.0.5 --output dist
bundle exec ruby scripts/xcframework/aggregate.rb --plan build-plan.json --input dist
```

`--pods` 为空规划全部。`--base <上次 xcframework SHA>` 进行增量比较。构建必须在计划的 repository_commit 上执行；旧计划或改变了 spec 的计划会被拒绝。

日志位于 `logs/<task-id>/`，失败时 Actions 也上传 `logs-<task-id>`（保存 14 天）。按安装日志、archive 日志和 import 日志依次检查。网络失败可重跑；Swift library evolution 或源代码不兼容必须修复上游源码/选择配置，不能以关闭 `BUILD_LIBRARY_FOR_DISTRIBUTION` 冒充通过。

原始 podspec 和 `prepare_command` 是可执行代码，本 workflow 只面向受信任仓库提交，不接收外部 PR/fork 的不受信任构建输入。

## 8. 验收边界

构建分支和 main 监听桥已经部署。默认 `ios` 范围的 GitHub Actions run `38257128218` 中 20/20 个 Pod 成功，Release `xcframeworks-38257128218-1` 已创建并包含 20 个 XCFramework ZIP、manifest 和 SHA256SUMS。使用 `all` 范围时，历史 run `38224786309` 仍有 Diagnostics、Masonry、SDWebImageWebPCoder 的非 iOS 平台源码兼容性错误；具体日志和修复边界见 `docs/xcframework/validation.md`。消费方的链接/运行测试仍需按实际项目单独验收。
