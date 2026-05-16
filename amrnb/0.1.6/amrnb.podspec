Pod::Spec.new do |s|
  s.name                  = 'amrnb'
  s.version               = '0.1.6'
  s.summary               = 'iOS port of opencore-amr, with prebuilt XCFrameworks available.'
  s.homepage              = 'https://sourceforge.net/projects/opencore-amr'
  s.author                = 'opencore-amr'
  s.license               = "MIT"
  s.source                = {
    :http => "https://github.com/KuaiLiao/opencore-amr-iOS/releases/download/v#{s.version}/opencore-amrnb.xcframework.zip"
  }
  s.swift_version         = '5.0'
  s.ios.deployment_target = '12.0'
  s.vendored_frameworks   = 'opencore-amrnb.xcframework'
end