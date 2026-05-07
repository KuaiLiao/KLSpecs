Pod::Spec.new do |spec|
  spec.name         = "LookInsideServer"
  spec.version      = "0.2.0"
  spec.summary      = "LookInside Server library"
  spec.homepage     = "https://github.com/LookInsideApp/LookInside-Release"
  spec.license      = "MIT"
  spec.author       = {
    "Lakr233" => "launchctl@outlook.com",
    "kyle" => "kyle201817146@gmail.com"
  }
  spec.ios.deployment_target = "15.0"
  spec.osx.deployment_target = "15.0"
  spec.source       = {
    :http => "https://github.com/LookInsideApp/LookInside-Release/releases/download/0.2.0/LookInsideServer.xcframework.zip",
    :sha256 => "684d3cc213b26153c3891d16c26757c51dd53faa6a9283274e1636298bdaa6d5"
  }
  spec.vendored_frameworks = "LookInsideServer.xcframework"
end
