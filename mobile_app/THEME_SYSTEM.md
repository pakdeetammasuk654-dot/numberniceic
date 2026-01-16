# ระบบสลับ Theme (Dark/Light Mode)

## สรุปการเปลี่ยนแปลง

ได้สร้างระบบสลับ theme สำหรับ Flutter app ที่สามารถเลือกระหว่าง Dark Theme และ Light Theme ได้แล้ว

### ไฟล์ที่สร้างใหม่:

1. **`lib/providers/theme_provider.dart`**
   - จัดการสถานะของ theme (dark/light)
   - บันทึกค่าลง SharedPreferences เพื่อให้จำค่าที่เลือกไว้
   - มี Dark Theme และ Light Theme ที่ออกแบบมาพร้อมใช้งาน
   - Default คือ Dark Theme ตามที่ต้องการ

2. **`lib/widgets/theme_toggle_button.dart`**
   - Widget สำหรับปุ่มสลับ theme
   - มี 3 รูปแบบ:
     - Icon only (ใช้ใน header)
     - With label (ใช้ในหน้าอื่นๆ)
     - Switch (ใช้ในเมนูการตั้งค่า)
   - มี animation เมื่อสลับ theme

### ไฟล์ที่แก้ไข:

1. **`lib/main.dart`**
   - เพิ่ม `ThemeProvider` ใน MultiProvider
   - ตั้งค่า MaterialApp ให้รองรับ dark/light theme
   - ใช้ Consumer เพื่อ listen การเปลี่ยนแปลง theme

2. **`lib/screens/dashboard_page.dart`**
   - เพิ่มปุ่มสลับ theme ใน header (ข้างๆ notification bell)
   - เพิ่ม ThemeToggleSwitch ในเมนูการตั้งค่า

## วิธีใช้งาน:

### สำหรับผู้ใช้:
1. **สลับ theme จาก header**: กดปุ่มไอคอนดวงจันทร์/ดวงอาทิตย์ที่มุมบนขวาของหน้า Dashboard
2. **สลับ theme จากเมนู**: เลื่อนลงไปที่เมนูบัญชีผู้ใช้ แล้วใช้ switch "โหมดมืด"

### สำหรับนักพัฒนา:

#### การใช้งาน ThemeProvider ในหน้าอื่นๆ:

```dart
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

// อ่านค่า theme ปัจจุบัน
final themeProvider = Provider.of<ThemeProvider>(context);
bool isDark = themeProvider.isDarkMode;

// สลับ theme
themeProvider.toggleTheme();

// ตั้งค่า theme แบบเฉพาะเจาะจง
themeProvider.setThemeMode(ThemeMode.dark);
themeProvider.setThemeMode(ThemeMode.light);
```

#### การใช้ ThemeToggleButton:

```dart
// แบบ Icon only
ThemeToggleButton(showLabel: false, iconSize: 20)

// แบบมี Label
ThemeToggleButton(showLabel: true, iconSize: 24)

// แบบ Switch (สำหรับเมนู)
ThemeToggleSwitch()
```

## คุณสมบัติ:

✅ สลับระหว่าง Dark และ Light theme ได้
✅ จำค่าที่เลือกไว้ (บันทึกใน SharedPreferences)
✅ Default เป็น Dark theme
✅ มี animation เมื่อสลับ theme
✅ ปุ่มสลับ theme อยู่ใน header และเมนู
✅ ใช้ Google Fonts (Kanit) ในทั้งสอง theme
✅ สีสันที่สวยงามและเหมาะสมกับแอป

## Theme Colors:

### Dark Theme:
- Background: `#121212`
- Surface: `#1E1E1E`
- Primary: Teal
- Accent: Gold (`#FFD700`)

### Light Theme:
- Background: `#F8F9FA` (Soft light gray)
- Surface: White
- Primary: Teal
- Accent: Gold (`#FFD700`)

## หมายเหตุ:

- การเปลี่ยน theme จะมีผลทันทีโดยไม่ต้อง restart แอป
- ค่าที่เลือกจะถูกบันทึกไว้ และจะยังคงอยู่แม้ปิดแอปแล้วเปิดใหม่
- สามารถปรับแต่งสีของแต่ละ theme ได้ที่ `lib/providers/theme_provider.dart`
