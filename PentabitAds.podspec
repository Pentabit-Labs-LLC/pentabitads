Pod::Spec.new do |s|
  s.name         = 'PentabitAds'
  s.version      = '0.1.0.2'
  s.summary      = 'Pentabit Ads SDK for iOS'
  s.homepage     = 'https://www.pentabitlabs.com/'
  s.license      = { :type => 'Proprietary' }
  s.author       = 'Pentabit Labs'
  s.source       = { :http => 'https://pentabit-labs-llc.github.io/pentabitads/ios/0.1.0.2/PentabitAds-iOS.zip' }
  s.vendored_frameworks = ['PentabitAds.xcframework', 'PentabitAdsVideo.xcframework', 'PentabitAnalytics.xcframework']
  s.ios.deployment_target = '14.0'
end
