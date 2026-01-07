# 🚀 Social Login Migration - Complete Guide

## ✅ สิ่งที่ทำเสร็จแล้ว

### Backend (Go)
- ✅ สร้าง `social_auth_handler.go` - รองรับ Google, Facebook, LINE
- ✅ เพิ่ม API endpoint `/api/auth/social`
- ✅ อัปเดต `member_service.go` - ซิงค์ข้อมูล Provider อัตโนมัติ
- ✅ อัปเดต `postgres_member_repository.go` - รองรับการอัปเดต Provider
- ✅ Backend พร้อมใช้งาน

### Mobile App (Flutter)
- ✅ เพิ่ม Dependencies: `google_sign_in`, `flutter_facebook_auth`, `flutter_line_sdk`
- ✅ รื้อ `auth_service.dart` - ใช้ Social Login แทน Username/Password
- ✅ ออกแบบ `login_page.dart` ใหม่ - UI สวยงามพร้อมปุ่ม Social Login
- ✅ สร้าง `social_auth_config.dart` - Configuration สำหรับ LINE SDK
- ✅ อัปเดต `main.dart` - Initialize LINE SDK

## 📋 Checklist: สิ่งที่ต้องทำต่อ

### 1. ตั้งค่า Google Sign-In

#### Firebase Console
- [ ] ไปที่ [Firebase Console](https://console.firebase.google.com/)
- [ ] เลือก/สร้างโปรเจค
- [ ] เปิดใช้งาน Authentication → Sign-in method → Google
- [ ] ดาวน์โหลด `google-services.json` (Android)
- [ ] ดาวน์โหลด `GoogleService-Info.plist` (iOS)

#### Android
- [ ] วาง `google-services.json` ใน `android/app/`
- [ ] เพิ่ม Google Services plugin ใน `android/build.gradle`
- [ ] Apply plugin ใน `android/app/build.gradle`

#### iOS
- [ ] วาง `GoogleService-Info.plist` ใน `ios/Runner/`
- [ ] เพิ่มไฟล์ใน Xcode project
- [ ] อัปเดต `Info.plist` ด้วย REVERSED_CLIENT_ID
- [ ] รัน `cd ios && pod install`

### 2. ตั้งค่า Facebook Login

#### Facebook Developer Console
- [ ] ไปที่ [Facebook Developers](https://developers.facebook.com/)
- [ ] สร้าง App ใหม่หรือเลือก App ที่มีอยู่
- [ ] เปิดใช้งาน Facebook Login
- [ ] เพิ่ม Platform: Android และ iOS
- [ ] บันทึก App ID และ Client Token

#### Android
- [ ] สร้าง `android/app/src/main/res/values/strings.xml`
- [ ] เพิ่ม Facebook App ID และ Client Token
- [ ] อัปเดต `AndroidManifest.xml` ตามเอกสาร `ANDROID_SOCIAL_LOGIN_SETUP.md`
- [ ] เพิ่ม Key Hash ใน Facebook Console:
  ```bash
  keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore | openssl sha1 -binary | openssl base64
  ```

#### iOS
- [ ] อัปเดต `Info.plist` ด้วย Facebook App ID
- [ ] เพิ่ม URL Scheme `fbYOUR_APP_ID`
- [ ] เพิ่ม Bundle ID ใน Facebook Console

### 3. ตั้งค่า LINE Login

#### LINE Developers Console
- [ ] ไปที่ [LINE Developers](https://developers.line.biz/)
- [ ] สร้าง Channel ใหม่ (LINE Login)
- [ ] บันทึก Channel ID: `2006844854` (หรืออัปเดตใน code)
- [ ] เพิ่ม Callback URL สำหรับ Mobile

#### Android
- [ ] อัปเดต `AndroidManifest.xml` ด้วย LINE scheme
- [ ] ตรวจสอบ Channel ID ใน scheme: `line.sdk.2006844854`

#### iOS
- [ ] อัปเดต `Info.plist` ด้วย LINE Configuration
- [ ] เพิ่ม URL Scheme สำหรับ LINE
- [ ] รัน `pod install`

#### Code
- [ ] อัปเดต Channel ID ใน `lib/utils/social_auth_config.dart` (ถ้าต่างจากเดิม)

### 4. ทดสอบระบบ

#### Build และรัน
```bash
# Android
flutter run

# iOS
flutter run

# หรือเลือก device
flutter devices
flutter run -d <device-id>
```

#### ทดสอบแต่ละ Provider
- [ ] ทดสอบ Google Sign-In
- [ ] ทดสอบ Facebook Login
- [ ] ทดสอบ LINE Login
- [ ] ทดสอบการ Logout
- [ ] ทดสอบการ Login ซ้ำ

### 5. Production Deployment

#### Backend
- [ ] อัปเดต Environment Variables ใน Production
- [ ] Deploy Backend ใหม่
- [ ] ทดสอบ `/api/auth/social` endpoint

#### Mobile App
- [ ] สร้าง Release Build
- [ ] ทดสอบ Social Login ใน Release mode
- [ ] อัปโหลด Google Play Store / App Store

## 🔧 คำสั่งที่มีประโยชน์

```bash
# ติดตั้ง Dependencies
flutter pub get

# Clean และ Rebuild
flutter clean
flutter pub get
flutter run

# iOS Pods
cd ios
pod install
pod update
cd ..

# Android Build
flutter build apk --release
flutter build appbundle --release

# iOS Build
flutter build ios --release

# ดู Logs
flutter logs

# ตรวจสอบ Devices
flutter devices
```

## 📚 เอกสารเพิ่มเติม

- [ANDROID_SOCIAL_LOGIN_SETUP.md](./ANDROID_SOCIAL_LOGIN_SETUP.md) - คู่มือตั้งค่า Android
- [IOS_SOCIAL_LOGIN_SETUP.md](./IOS_SOCIAL_LOGIN_SETUP.md) - คู่มือตั้งค่า iOS

## ⚠️ หมายเหตุสำคัญ

1. **ระบบ Login เดิม (Username/Password) ถูก Deprecated แล้ว**
   - ฟังก์ชัน `login()` และ `register()` จะ return error message
   - ผู้ใช้ต้องใช้ Social Login เท่านั้น

2. **Email Linking**
   - ถ้า Email ซ้ำกัน ระบบจะ link บัญชีเดิมโดยอัตโนมัติ
   - Provider info จะอัปเดตเป็นของล่าสุดที่ใช้ Login

3. **Security**
   - Backend จะตรวจสอบ OAuth Token กับ Provider APIs
   - JWT Token มีอายุ 30 วัน
   - ข้อมูลผู้ใช้ถูกเข้ารหัสอย่างปลอดภัย

4. **Testing**
   - ใช้ Debug mode สำหรับ Development
   - ทดสอบ Release mode ก่อน Deploy จริง
   - ตรวจสอบ Logs หากมีปัญหา

## 🆘 Troubleshooting

### Google Sign-In ไม่ทำงาน
- ตรวจสอบ SHA-1 fingerprint ใน Firebase Console
- ตรวจสอบ `google-services.json` / `GoogleService-Info.plist`
- ตรวจสอบ Package Name / Bundle ID

### Facebook Login ไม่ทำงาน
- ตรวจสอบ App ID และ Client Token
- ตรวจสอบ Key Hash (Android)
- ตรวจสอบ Bundle ID (iOS)

### LINE Login ไม่ทำงาน
- ตรวจสอบ Channel ID
- ตรวจสอบ URL Scheme
- ตรวจสอบ Callback URL ใน LINE Console

### Backend Error
- ตรวจสอบ Logs: `tail -f app.log`
- ตรวจสอบ Database connection
- ตรวจสอบ API endpoint: `curl -X POST http://localhost:3000/api/auth/social`

## 🎉 เสร็จสิ้น!

เมื่อทำตาม Checklist ครบแล้ว Mobile App จะพร้อมใช้งาน Social Login แบบเดียวกับเว็บ!
