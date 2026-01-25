Pod::Spec.new do |s|
  s.name                  = 'Builders'
  s.version               = '0.10.0'
  s.summary               = 'Result builders for Swift and Foundation types.'
  s.description           = 'A collection of useful result builders for Swift and Foundation value types.'
  s.homepage              = 'https://github.com/davdroman/swift-builders'
  s.author                = 'davdroman'
  s.license               = "MIT"
  s.source           	  = { 
	:git => 'https://github.com/davdroman/swift-builders.git', 
	:tag => s.version.to_s 
  }
  s.source_files 		  = 'Sources/Builders/*.swift'
  s.prefix_header_file 	  = false
  s.swift_version         = '6.0'
  s.ios.deployment_target = '12.0'
end