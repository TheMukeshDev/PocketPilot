# Keep Flutter entry points and plugin registrants during release shrinking.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep UPI payment library classes
-keep class com.upi.** { *; }
-keep interface com.upi.** { *; }
-dontwarn com.upi.**