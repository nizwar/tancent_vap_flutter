#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint vap.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'vap'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for VAP (Video Animation Player) integration.'
  s.description      = <<-DESC
A Flutter plugin that provides VAP (Video Animation Player) integration for iOS and Android.
VAP is a high-performance animation framework developed by Tencent for playing transparent video animations.
                       DESC
  s.homepage         = 'https://laskarmedia.id'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Laskarmedia' => 'support@laskarmedia.id' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.dependency 'QGVAPlayer', '= 1.0.19'

  
  # VAP iOS SDK dependency (users need to add the git source in their Podfile)
  # s.dependency 'QGVAPlayer'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'vap_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
