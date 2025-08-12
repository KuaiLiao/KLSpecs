#
# Be sure to run `pod lib lint swift-collections.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#
# refer: https://github.com/Danie1s/swift-collections-podspec

Pod::Spec.new do |s|
  s.name             = 'SwiftCollections'
  s.version          = '1.2.1'
  s.summary          = 'Swift Collections is an open-source package of data structure implementations for the Swift.'

  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  Swift Collections is an open-source package of data structure implementations for the Swift programming language.
  DESC

  s.homepage         = 'https://github.com/apple/swift-collections'
  s.author           = { 'Apple' => 'Apple' }
  s.license          = { :type => 'Apache', :file => 'LICENSE.txt' }
  s.source           = { :git => 'https://github.com/apple/swift-collections.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '3.0'

  s.swift_version = '5.0'

  s.module_name = s.name

  # add macro: COLLECTIONS_SINGLE_MODULE
  s.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => 'COLLECTIONS_SINGLE_MODULE',
  }

  s.subspec 'InternalCollectionsUtilities' do |ss|
    ss.source_files = 'Sources/InternalCollectionsUtilities/**/*.swift'
  end

  s.subspec 'BitCollections' do |ss|
    ss.source_files = 'Sources/BitCollections/**/*.swift'
    ss.dependency "#{s.name}/InternalCollectionsUtilities"
  end

  s.subspec 'DequeModule' do |ss|
    ss.source_files = 'Sources/DequeModule/**/*.swift'
    ss.dependency "#{s.name}/InternalCollectionsUtilities"
  end

  s.subspec 'HashTreeCollections' do |ss|
    ss.source_files = 'Sources/HashTreeCollections/**/*.swift'
    ss.dependency "#{s.name}/InternalCollectionsUtilities"
  end

  s.subspec 'HeapModule' do |ss|
    ss.source_files = 'Sources/HeapModule/**/*.swift'
    ss.dependency "#{s.name}/InternalCollectionsUtilities"
  end

  s.subspec 'OrderedCollections' do |ss|
    ss.source_files = 'Sources/OrderedCollections/**/*.swift'
    ss.dependency "#{s.name}/InternalCollectionsUtilities"
  end

  s.subspec 'RopeModule' do |ss|
    ss.source_files = 'Sources/RopeModule/**/*.swift'
    ss.dependency "#{s.name}/InternalCollectionsUtilities"
  end

  s.subspec 'SortedCollections' do |ss|
    ss.source_files = 'Sources/SortedCollections/**/*.swift'
    ss.dependency "#{s.name}/InternalCollectionsUtilities"
  end

  s.subspec 'All' do |ss|
    ss.dependency "#{s.name}/InternalCollectionsUtilities"
    ss.dependency "#{s.name}/DequeModule"
    ss.dependency "#{s.name}/BitCollections"
    ss.dependency "#{s.name}/HeapModule"
    ss.dependency "#{s.name}/HashTreeCollections"
    ss.dependency "#{s.name}/OrderedCollections"
    ss.dependency "#{s.name}/RopeModule"
    ss.dependency "#{s.name}/SortedCollections"
  end

  s.default_subspec = 'OrderedCollections'

  # This section is used to set up the test specifications.
  # s.test_spec 'Tests' do |ts|
  #   ts.source_files = 'Tests/**/*.swift'
  #   ts.dependency "#{s.name}/OrderedCollections"
  #   ts.dependency "#{s.name}/DequeModule"
  #   ts.dependency "#{s.name}/BitCollections"
  #   ts.dependency "#{s.name}/HeapModule"
  #   ts.dependency "#{s.name}/HashTreeCollections"
  #   ts.dependency "#{s.name}/RopeModule"
  #   ts.dependency "#{s.name}/SortedCollections"
  # end

end
