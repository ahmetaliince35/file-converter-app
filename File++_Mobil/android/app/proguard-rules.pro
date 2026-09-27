# Google Play Services & ML Kit (OCR & Document Scanner)
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Flutter platform channels
-keepattributes *Annotation*
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}