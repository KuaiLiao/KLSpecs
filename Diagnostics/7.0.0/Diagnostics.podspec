Pod::Spec.new do |s|
  s.name             = 'Diagnostics'
  s.version          = '7.0.0'
  s.summary          = 'Allow users to easily share Diagnostics with your support team to improve the flow of fixing bugs.'
  s.homepage         = 'https://github.com/AvdLee/Diagnostics'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Antoine van der Lee' => 'contact@avanderlee.com' }
  s.source           = { :git => 'https://github.com/AvdLee/Diagnostics.git', :tag => s.version.to_s }

  # 平台支持 (与 Package.swift 保持一致)
  s.ios.deployment_target = '16.0'
  s.macos.deployment_target = '13.0'
  s.tvos.deployment_target = '14.0'
  s.watchos.deployment_target = '6.0'

  s.swift_versions = ['5.9', '6.0']

  # 源码路径 (映射自 SPM 的 .target(name: "Diagnostics", path: "Sources"))
  s.source_files = 'Sources/**/*.{swift}'

  # 资源文件 (映射自 SPM 的 resources: [.process("Resources")])
  s.resource_bundles = {
    'Diagnostics' => ['Sources/**/*.{js,css,xcprivacy}']
  }

  # 依赖项 (映射自 SPM 中的 .package(url: "...ExceptionCatcher", from: "2.0.0"))
  s.dependency 'ExceptionCatcher', '~> 2.0'

  # 为 CocoaPods 生成 Bundle.module 兼容扩展
  s.prepare_command = <<-CMD
    cat > Sources/Bundle+CocoaPods.swift <<'EOF'
import Foundation

private class BundleFinder {}

extension Foundation.Bundle {
    static let module: Bundle = {
        let bundleName = "Diagnostics"
        let candidates = [
            Bundle.main.resourceURL,
            Bundle(for: BundleFinder.self).resourceURL,
            Bundle.main.bundleURL
        ]
        for candidate in candidates {
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                return bundle
            }
        }
        return Bundle(for: BundleFinder.self)
    }()
}
EOF
  CMD
end
