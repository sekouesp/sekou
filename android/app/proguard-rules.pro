# ESP Sekou ProGuard Rules
# Keep Flutter wrapper classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Firebase classes
-keep class com.google.firebase.** { *; }

# Keep OneSignal classes
-keep class com.onesignal.** { *; }

# Keep Supabase classes
-keep class io.github.jan-tennert.supabase.** { *; }
