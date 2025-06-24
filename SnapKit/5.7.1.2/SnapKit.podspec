Pod::Spec.new do |s|
  s.name = 'SnapKit'
  s.version = '5.7.1.2'
  s.license = 'MIT'
  s.summary = 'Harness the power of auto layout with a simplified, chainable, and compile time safe syntax.'
  s.homepage = 'https://github.com/SnapKit/SnapKit'
  s.authors = { 'Robert Payne' => 'robertpayne@me.com' }
  s.social_media_url = 'http://twitter.com/robertjpayne'
  s.source = { :git => 'https://github.com/KuaiLiao/SnapKit.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.13'
  s.tvos.deployment_target = '12.0'

  s.subspec 'Default' do |ss|
    ss.source_files = 'Sources/*.swift'
  end

  s.subspec 'Deprecated' do |ss|
    ss.source_files = 'Sources/Deprecated/*.swift'
    ss.dependency 'SnapKit/Default'
  end

  s.default_subspec = 'Default'

  s.libraries = 'swiftCoreGraphics'

  s.xcconfig = {
      'LIBRARY_SEARCH_PATHS' => '$(SDKROOT)/usr/lib/swift',
  }

  s.resource_bundles = {
    'SnapKit_Privacy' => ['Sources/PrivacyInfo.xcprivacy'],
  }

  s.swift_versions = ['5.0']
end
