#!/bin/bash

# Social Login Setup Script for Mobile App
# This script helps automate some setup steps

echo "🚀 Social Login Setup Script"
echo "================================"
echo ""

# Check if we're in the mobile_app directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Please run this script from the mobile_app directory"
    exit 1
fi

echo "📦 Step 1: Installing Flutter dependencies..."
flutter pub get

if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi

echo "✅ Dependencies installed successfully"
echo ""

echo "🔍 Step 2: Checking for required configuration files..."
echo ""

# Check Android configuration
echo "Android Configuration:"
if [ -f "android/app/google-services.json" ]; then
    echo "  ✅ google-services.json found"
else
    echo "  ⚠️  google-services.json NOT found"
    echo "     Download from Firebase Console and place in android/app/"
fi

if [ -f "android/app/src/main/res/values/strings.xml" ]; then
    echo "  ✅ strings.xml found"
else
    echo "  ⚠️  strings.xml NOT found"
    echo "     Use android_strings_template.xml as a template"
fi

echo ""

# Check iOS configuration
echo "iOS Configuration:"
if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo "  ✅ GoogleService-Info.plist found"
else
    echo "  ⚠️  GoogleService-Info.plist NOT found"
    echo "     Download from Firebase Console and place in ios/Runner/"
fi

echo ""

# iOS Pods
if [ -d "ios" ]; then
    echo "📱 Step 3: Installing iOS Pods..."
    cd ios
    pod install
    if [ $? -eq 0 ]; then
        echo "✅ iOS Pods installed successfully"
    else
        echo "⚠️  Pod install had some warnings (this might be okay)"
    fi
    cd ..
else
    echo "⚠️  iOS directory not found, skipping pod install"
fi

echo ""
echo "================================"
echo "✅ Setup Complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Review SOCIAL_LOGIN_MIGRATION_GUIDE.md for complete checklist"
echo "2. Configure Facebook App ID in strings.xml (Android) and Info.plist (iOS)"
echo "3. Add google-services.json and GoogleService-Info.plist if not already done"
echo "4. Update LINE Channel ID in lib/utils/social_auth_config.dart if needed"
echo "5. Run 'flutter run' to test the app"
echo ""
echo "📚 Documentation:"
echo "  - SOCIAL_LOGIN_MIGRATION_GUIDE.md (Main guide)"
echo "  - ANDROID_SOCIAL_LOGIN_SETUP.md (Android details)"
echo "  - IOS_SOCIAL_LOGIN_SETUP.md (iOS details)"
echo ""
