Pod::Spec.new do |s|
  s.name             = 'ExceptionCatcher'
  s.version          = '2.2.0'
  s.summary          = 'Catch Objective-C exceptions in Swift'
  s.homepage         = 'https://github.com/sindresorhus/ExceptionCatcher'
  s.license          = { :type => 'MIT', :file => 'license' }
  s.author           = { 'Sindre Sorhus' => 'sindresorhus@gmail.com' }
  s.source           = { :git => 'https://github.com/sindresorhus/ExceptionCatcher.git', :tag => "v#{s.version}" }

  s.ios.deployment_target     = '12.0'
  s.macos.deployment_target    = '10.13'
  s.tvos.deployment_target     = '12.0'
  s.watchos.deployment_target  = '4.0'

  s.swift_versions = ['6.0']

  s.source_files = 'Sources/ExceptionCatcher/**/*.swift'

  s.dependency 'ExceptionCatcherInternal', '~> 2.2.0'
end
