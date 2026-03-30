Pod::Spec.new do |s|
  s.name             = "ZDTinyLayout"
  s.version          = "0.0.1"
  s.summary          = "A collection of operators and utilities that simplify iOS layout code."
  s.description      = <<-DESC
                       Create constraints using intuitive operators built directly on top of the NSLayoutAnchor API. Layout has never been simpler!
                       DESC
  s.homepage         = "https://github.com/faimin/ZDTinyLayout"
  s.license          = 'MIT'
  s.author           = { 
	"Rob Visentin" => "jvisenti@gmail.com",
	"Zero.D.Saber" => "fuxianchao@gmail.com"
  }
  s.source           = { :git => "https://github.com/faimin/ZDTinyLayout.git", :tag => s.version.to_s }
  s.swift_versions    = ['5.9']

  s.ios.deployment_target = '9.0'
  s.tvos.deployment_target = '9.0'
  s.osx.deployment_target = '10.11'
  s.visionos.deployment_target = '1.0'
  s.requires_arc = true

  s.source_files = "Source/**/*.swift"

  s.resource_bundles = {
    "#{s.name}_Privacy" => ["Source/Resource/PrivacyInfo.xcprivacy"],
  }
end
