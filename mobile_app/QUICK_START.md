# 🚀 Quick Start Guide - ทดสอบ Social Login ใน 5 นาที!

## ขั้นตอนที่ 1: สร้าง Firebase Project (2 นาที)

1. ไปที่ https://console.firebase.google.com/
2. คลิก "Add project" หรือ "Create a project"
3. ตั้งชื่อโปรเจค: `numberniceic-mobile` (หรือชื่ออื่นที่ชอบ)
4. ปิด Google Analytics (ไม่จำเป็นสำหรับการทดสอบ)
5. คลิก "Create project"

## ขั้นตอนที่ 2: เพิ่ม Android App (1 นาที)

1. ใน Firebase Console คลิก Android icon (รูปหุ่นยนต์สีเขียว)
2. กรอก Package name: `com.example.mobile_app`
3. App nickname: `NumberNiceIC Mobile`
4. คลิก "Register app"
5. **ดาวน์โหลด `google-services.json`**
6. คลิก "Next" → "Next" → "Continue to console"

## ขั้นตอนที่ 3: เพิ่ม iOS App (1 นาที)

1. ใน Firebase Console คลิก iOS icon (รูป Apple)
2. กรอก Bundle ID: `com.example.mobileApp`
3. App nickname: `NumberNiceIC Mobile`
4. คลิก "Register app"
5. **ดาวน์โหลด `GoogleService-Info.plist`**
6. คลิก "Next" → "Next" → "Continue to console"

## ขั้นตอนที่ 4: เปิดใช้งาน Google Sign-In (30 วินาที)

1. ใน Firebase Console ไปที่ "Authentication"
2. คลิก "Get started"
3. เลือก "Sign-in method"
4. คลิกที่ "Google"
5. เปิด Enable
6. เลือก Support email (อีเมลของคุณ)
7. คลิก "Save"

## ขั้นตอนที่ 5: วางไฟล์ Configuration (30 วินาที)

```bash
# วาง google-services.json
cp ~/Downloads/google-services.json /Users/tayap/apps-go/numberniceic/mobile_app/android/app/

# วาง GoogleService-Info.plist  
cp ~/Downloads/GoogleService-Info.plist /Users/tayap/apps-go/numberniceic/mobile_app/ios/Runner/
```

## ขั้นตอนที่ 6: รัน App! (1 นาที)

```bash
cd /Users/tayap/apps-go/numberniceic/mobile_app

# ติดตั้ง iOS Pods
cd ios && pod install && cd ..

# รัน App
flutter run
```

## 🎉 เสร็จแล้ว!

ตอนนี้คุณสามารถ:
- กดปุ่ม "เข้าสู่ระบบด้วย Google" ใน App
- เลือก Google Account
- Login สำเร็จ!

---

## ⚠️ หมายเหตุ:

- **Facebook และ LINE** จะยังใช้ไม่ได้ในตอนนี้ (ต้องตั้งค่าเพิ่ม)
- แต่ **Google Sign-In จะใช้งานได้เต็มรูปแบบ**
- ข้อมูลจะถูกบันทึกใน Database เหมือนกับเว็บ
- ใช้ Backend API เดียวกันกับเว็บ

## 🔧 Troubleshooting:

### ถ้า Google Sign-In ไม่ทำงาน:

**Android:**
```bash
# ดู SHA-1 fingerprint
cd android
./gradlew signingReport
```
คัดลอก SHA-1 ไปใส่ใน Firebase Console → Project Settings → Your apps → Android app → Add fingerprint

**iOS:**
- ตรวจสอบว่า Bundle ID ตรงกับที่ตั้งใน Xcode
- เปิด `ios/Runner.xcworkspace` ใน Xcode
- ตรวจสอบ Signing & Capabilities

---

## 📱 ทดสอบบน Device จริง:

### Android:
```bash
flutter run -d ce0517151aee3c680d  # Samsung Galaxy S8
```

### iPhone:
```bash
flutter run -d 00008120-001C15D11420C01E  # iPhone (wireless)
```

---

**ใช้เวลารวมทั้งหมด: ~5 นาที** ⏱️
