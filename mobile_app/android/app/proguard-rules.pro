# Flutter Specific
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-keep class com.google.android.play.core.** { *; }

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# LINE SDK
-keep class com.linecorp.** { *; }
-keep interface com.linecorp.** { *; }

# Facebook SDK
-keep class com.facebook.** { *; }
-keep interface com.facebook.** { *; }

# Google Sign In
-keep class com.google.android.gms.** { *; }
-keep interface com.google.android.gms.** { *; }

# Shared Preferences
-keep class com.google.gson.** { *; }

# Firebase Messaging
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.RuntimeType { *; }

# Keep notification resources
-keep class com.taya.numberniceic.R$drawable { *; }
-keep class com.taya.numberniceic.R$mipmap { *; }
-keep class com.taya.numberniceic.R$string { *; }

# Prevent obfuscation of generic types
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Keep Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
