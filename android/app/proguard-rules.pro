# Keep rules for Flutter and common plugins.
# Most apps can keep this minimal; R8 will shrink/obfuscate safely.

# Flutter engine + embedding
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }

# Firebase / Play Services (generally safe; keep minimal)
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Fix for Missing class com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

