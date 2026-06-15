#
# Be sure to run `pod lib lint SwiftCollections.podspec' to ensure this is a
# valid spec before submitting.
#
# refer: https://github.com/Danie1s/swift-collections-podspec

Pod::Spec.new do |s|
  s.name             = 'SwiftCollections'
  s.version          = '1.6.0'
  s.summary          = 'Swift Collections is an open-source package of data structure implementations for the Swift.'

  s.description      = <<-DESC
  Swift Collections is an open-source package of data structure implementations for the Swift programming language.
  DESC

  s.homepage         = 'https://github.com/apple/swift-collections'
  s.author           = { 'Apple' => 'Apple' }
  s.license          = { :type => 'Apache', :file => 'LICENSE.txt' }
  s.source           = { :git => 'https://github.com/apple/swift-collections.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '13.0'
  s.watchos.deployment_target = '6.0'

  # Use Swift 5.10 — RopeModule has broken _modify accessors in Swift 6 mode
  s.swift_version = '5.10'

  s.module_name = s.name

  # Use COLLECTIONS_SINGLE_MODULE so all sources share one namespace (same as Xcode project).
  # Experimental features are required by ContainersPreview (AddressableParameters, AddressableTypes)
  # and other modules (Lifetimes, InoutLifetimeDependence, etc.).
  s.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => 'COLLECTIONS_SINGLE_MODULE',
    'OTHER_SWIFT_FLAGS' => [
      '-package-name CollectionsInternal',
      '-enable-upcoming-feature MemberImportVisibility',
      '-enable-experimental-feature BuiltinModule',
      '-enable-experimental-feature Lifetimes',
      '-enable-experimental-feature InoutLifetimeDependence',
      '-enable-experimental-feature AddressableParameters',
      '-enable-experimental-feature AddressableTypes',
      '-enable-experimental-feature SuppressedAssociatedTypesWithDefaults',
      '-enable-experimental-feature "AvailabilityMacro=SwiftStdlib 5.0: macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2"',
      '-enable-experimental-feature "AvailabilityMacro=SwiftStdlib 5.1: macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0"',
      '-enable-experimental-feature "AvailabilityMacro=SwiftStdlib 5.6: macOS 12.3, iOS 15.4, watchOS 8.5, tvOS 15.4"',
      '-enable-experimental-feature "AvailabilityMacro=SwiftStdlib 5.7: macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0"',
      '-enable-experimental-feature "AvailabilityMacro=SwiftStdlib 5.8: macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4"',
      '-enable-experimental-feature "AvailabilityMacro=SwiftStdlib 5.9: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0"',
      '-enable-experimental-feature "AvailabilityMacro=SwiftStdlib 5.10: macOS 14.4, iOS 17.4, watchOS 10.4, tvOS 17.4, visionOS 1.1"',
      '-enable-experimental-feature "AvailabilityMacro=SwiftStdlib 6.0: macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0"',
      '-enable-experimental-feature "AvailabilityMacro=SwiftStdlib 6.1: macOS 15.4, iOS 18.4, watchOS 11.4, tvOS 18.4, visionOS 2.4"',
      '-enable-experimental-feature "AvailabilityMacro=SwiftStdlib 6.2: macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0"',
      '-enable-experimental-feature "AvailabilityMacro=SwiftStdlib 6.3: macOS 26.4, iOS 26.4, watchOS 26.4, tvOS 26.4, visionOS 26.4"',
      '-enable-experimental-feature "AvailabilityMacro=SwiftStdlib 6.4: macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, visionOS 9999"',
      '-enable-experimental-feature "AvailabilityMacro=SwiftStdlib 6.5: macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, visionOS 9999"',
    ].join(' '),
  }

  s.subspec 'InternalCollectionsUtilities' do |ss|
    ss.source_files = 'Sources/InternalCollectionsUtilities/**/*.swift'
  end

  # New in 1.5.x: base container protocols (no external dependencies)
  s.subspec 'ContainersPreview' do |ss|
    ss.source_files = 'Sources/ContainersPreview/**/*.swift'
    ss.dependency "#{s.name}/InternalCollectionsUtilities"
  end

  # New in 1.5.x: concrete container implementations built on ContainersPreview
  s.subspec 'BasicContainers' do |ss|
    ss.source_files = 'Sources/BasicContainers/**/*.swift'
    ss.dependency "#{s.name}/InternalCollectionsUtilities"
    ss.dependency "#{s.name}/ContainersPreview"
  end

  s.subspec 'BitCollections' do |ss|
    ss.source_files = 'Sources/BitCollections/**/*.swift'
    ss.dependency "#{s.name}/InternalCollectionsUtilities"
  end

  # DequeModule now depends on ContainersPreview (added in 1.5.x)
  s.subspec 'DequeModule' do |ss|
    ss.source_files = 'Sources/DequeModule/**/*.swift'
    ss.dependency "#{s.name}/InternalCollectionsUtilities"
    ss.dependency "#{s.name}/ContainersPreview"
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

  # SPM module name is _RopeModule; source directory is RopeModule
  s.subspec 'RopeModule' do |ss|
    ss.source_files = 'Sources/RopeModule/**/*.swift'
    ss.dependency "#{s.name}/InternalCollectionsUtilities"
  end

  s.subspec 'SortedCollections' do |ss|
    ss.source_files = 'Sources/SortedCollections/**/*.swift'
    ss.dependency "#{s.name}/InternalCollectionsUtilities"
  end

  # New in 1.5.x: trailing elements layout helpers (no external module dependencies)
  s.subspec 'TrailingElementsModule' do |ss|
    ss.source_files = 'Sources/TrailingElementsModule/**/*.swift'
  end

  s.subspec 'All' do |ss|
    ss.dependency "#{s.name}/InternalCollectionsUtilities"
    ss.dependency "#{s.name}/ContainersPreview"
    ss.dependency "#{s.name}/BasicContainers"
    ss.dependency "#{s.name}/BitCollections"
    ss.dependency "#{s.name}/DequeModule"
    ss.dependency "#{s.name}/HashTreeCollections"
    ss.dependency "#{s.name}/HeapModule"
    ss.dependency "#{s.name}/OrderedCollections"
    ss.dependency "#{s.name}/RopeModule"
    ss.dependency "#{s.name}/SortedCollections"
    ss.dependency "#{s.name}/TrailingElementsModule"
  end

  s.default_subspec = 'OrderedCollections'

end
