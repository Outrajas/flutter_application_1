# === TensorFlow Lite GPU Support Keep Rules ===
-keep class org.tensorflow.** { *; }
-keep class com.google.flatbuffers.** { *; }

# Preserve native methods
-keepclasseswithmembers class * {
    native <methods>;
}

# Preserve annotations and inner classes
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod

# Optional: keep Flutter plugins
-keep class io.flutter.plugin.** { *; }
