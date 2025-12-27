# Mobile App for NumberNiceIC

This is the Flutter mobile application for the NumberNiceIC project.

## Project Setup

Because this project was generated in an environment without the `flutter` CLI tool, it strictly contains the Dart source code and configuration. You need to recreate the platform-specific folders (android, ios, web, etc.).

### Prerequisites
- Flutter SDK installed on your local machine.

### Installation

1. Open your terminal and navigate to this folder:
   ```bash
   cd mobile_app
   ```

2. Generate the platform-specific project files (Android, iOS, etc.):
   ```bash
   flutter create . --project-name=mobile_app
   ```
   *Note: The `.` indicates the current directory. This command will repair the missing platform folders while keeping your `lib/` and `pubspec.yaml`.*

3. Get dependencies:
   ```bash
   flutter pub get
   ```

4. Run the app:
   ```bash
   flutter run
   ```
