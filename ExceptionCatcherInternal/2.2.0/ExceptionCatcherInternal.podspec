Pod::Spec.new do |s|
  s.name             = 'ExceptionCatcherInternal'
  s.version          = '2.2.0'
  s.summary          = 'Internal ObjC module for ExceptionCatcher'
  s.homepage         = 'https://github.com/sindresorhus/ExceptionCatcher'
  s.license          = { :type => 'MIT', :file => 'license' }
  s.author           = { 'Sindre Sorhus' => 'sindresorhus@gmail.com' }
  s.source           = { :git => 'https://github.com/sindresorhus/ExceptionCatcher.git', :tag => "v#{s.version}" }

  s.ios.deployment_target     = '12.0'
  s.macos.deployment_target    = '10.13'
  s.tvos.deployment_target     = '12.0'
  s.watchos.deployment_target  = '4.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }

  s.source_files = 'Sources/ExceptionCatcherInternal/**/*.{h,m}'
  s.public_header_files = 'Sources/ExceptionCatcherInternal/include/**/*.h'
end
