# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep app entry points
-keep class com.nexusshield.** { *; }

# Google Fonts
-keep class com.google.** { *; }

# OkHttp / HTTP client
-dontwarn okhttp3.**
-dontwarn okio.**

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# Serialization — keep data classes used for JSON
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Don't warn about missing classes in unused libs
-dontwarn java.lang.instrument.**
-dontwarn sun.misc.**
