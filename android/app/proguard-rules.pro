# Keep Flutter entry points and plugin registrants during release shrinking.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep UPI payment library classes
-keep class com.upi.** { *; }
-keep interface com.upi.** { *; }
-dontwarn com.upi.**

# Firebase optimizations
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**

# Google ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# MongoDB
-keep class com.mongodb.** { *; }
-keep class org.bson.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}