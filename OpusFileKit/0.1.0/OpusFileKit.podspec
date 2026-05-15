Pod::Spec.new do |s|
  s.name                  = 'OpusFileKit'
  s.version               = '0.1.0'
  s.summary               = 'A totally open, royalty-free, highly versatile audio codec.'
  s.homepage              = 'https://github.com/Saafo/opus-builder'
  s.author                = 'Trey Ethridge'
  s.license               = "MIT"
  s.source                = {
    :http => "https://github.com/Saafo/opus-builder/releases/download/v#{s.version}/darwin-static.zip"
  }
  s.swift_version         = '5.0'
  s.ios.deployment_target = '12.0'
  s.vendored_frameworks   = 'darwin-static/lib/darwin/libopusfile-0.12.xcframework'
end
