# iOS Configuration for Social Login

## 1. Info.plist Configuration

Add the following to `ios/Runner/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Existing keys... -->
    
    <!-- Google Sign-In -->
    <key>CFBundleURLTypes</key>
    <array>
        <!-- Google URL Scheme -->
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <!-- Replace with your REVERSED_CLIENT_ID from GoogleService-Info.plist -->
                <string>com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID</string>
            </array>
        </dict>
        
        <!-- Facebook URL Scheme -->
        <dict>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>fbYOUR_FACEBOOK_APP_ID</string>
            </array>
        </dict>
        
        <!-- LINE URL Scheme -->
        <dict>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>line3rdp.$(PRODUCT_BUNDLE_IDENTIFIER)</string>
            </array>
        </dict>
    </array>
    
    <!-- Facebook Configuration -->
    <key>FacebookAppID</key>
    <string>YOUR_FACEBOOK_APP_ID</string>
    <key>FacebookClientToken</key>
    <string>YOUR_FACEBOOK_CLIENT_TOKEN</string>
    <key>FacebookDisplayName</key>
    <string>ชื่อดี</string>
    
    <!-- LINE Configuration -->
    <key>LineSDKConfig</key>
    <dict>
        <key>ChannelID</key>
        <string>2006844854</string>
    </dict>
    
    <!-- App Transport Security -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    
    <!-- Queries Schemes for Social Login -->
    <key>LSApplicationQueriesSchemes</key>
    <array>
        <string>fbapi</string>
        <string>fb-messenger-share-api</string>
        <string>fbauth2</string>
        <string>fbshareextension</string>
        <string>lineauth2</string>
    </array>
</dict>
</plist>
```

## 2. GoogleService-Info.plist

1. Download `GoogleService-Info.plist` from Firebase Console
2. Place it in `ios/Runner/GoogleService-Info.plist`
3. Add it to Xcode project (Right-click Runner → Add Files to "Runner")

## 3. Podfile Configuration

Update `ios/Podfile`:

```ruby
platform :ios, '12.0'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  
  # Google Sign-In
  pod 'GoogleSignIn'
  
  # Facebook SDK
  pod 'FBSDKLoginKit'
  
  # LINE SDK
  pod 'LineSDKSwift', '~> 5.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
```

## 4. Install Pods

Run in terminal:

```bash
cd ios
pod install
cd ..
```

## 5. Xcode Configuration

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target → Signing & Capabilities
3. Enable "Sign in with Apple" capability (if needed)
4. Set your Team and Bundle Identifier

## 6. Important Notes

- Replace `YOUR_FACEBOOK_APP_ID` with actual Facebook App ID
- Replace `YOUR_FACEBOOK_CLIENT_TOKEN` with actual Facebook Client Token
- Replace `YOUR_REVERSED_CLIENT_ID` with value from GoogleService-Info.plist
- LINE Channel ID is already set to `2006844854` (update if different)
