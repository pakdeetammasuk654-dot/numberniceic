#!/bin/bash

echo "🚀 NumberNiceIC Mobile - Quick Test Setup"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ Error: Please run this script from the mobile_app directory${NC}"
    exit 1
fi

echo "📋 Pre-flight Checklist:"
echo ""

# Check for google-services.json
if [ -f "android/app/google-services.json" ]; then
    echo -e "${GREEN}✅${NC} google-services.json found"
else
    echo -e "${YELLOW}⚠️${NC}  google-services.json NOT found"
    echo "   👉 Download from Firebase Console and place in android/app/"
    echo "   📖 See QUICK_START.md for instructions"
    MISSING_FILES=true
fi

# Check for GoogleService-Info.plist
if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo -e "${GREEN}✅${NC} GoogleService-Info.plist found"
else
    echo -e "${YELLOW}⚠️${NC}  GoogleService-Info.plist NOT found"
    echo "   👉 Download from Firebase Console and place in ios/Runner/"
    echo "   📖 See QUICK_START.md for instructions"
    MISSING_FILES=true
fi

echo ""

if [ "$MISSING_FILES" = true ]; then
    echo -e "${YELLOW}⚠️  Missing configuration files!${NC}"
    echo ""
    echo "To test Google Sign-In, you need to:"
    echo "1. Create a Firebase project (takes 2 minutes)"
    echo "2. Download the config files"
    echo "3. Place them in the correct locations"
    echo ""
    echo "📖 Full instructions: open QUICK_START.md"
    echo ""
    read -p "Continue anyway to see the UI? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "🔧 Installing dependencies..."
flutter pub get

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to install dependencies${NC}"
    exit 1
fi

echo ""
echo "📱 Installing iOS Pods..."
cd ios
pod install --repo-update
cd ..

echo ""
echo "🎯 Available devices:"
flutter devices

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "To run the app:"
echo "  flutter run                    # Auto-select device"
echo "  flutter run -d <device-id>     # Specific device"
echo ""
echo "Available devices from above list:"
echo "  - Android: flutter run -d ce0517151aee3c680d"
echo "  - iPhone:  flutter run -d 00008120-001C15D11420C01E"
echo ""
echo "📖 For complete setup guide: open QUICK_START.md"
echo "=========================================="
