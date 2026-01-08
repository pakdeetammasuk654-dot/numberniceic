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
