# -----------------------------------------------------------------------------
# ProGuard/R8 keep rules for the release build.
#
# Why this file matters
# ---------------------
# Release builds run R8 with proguard-android-optimize.txt, which aggressively
# strips and renames classes that aren't statically referenced. Several plugins
# resolve their native counterparts through reflection at runtime — R8 can't
# see those edges and silently drops the class, so the plugin loads but does
# nothing (camera opens but never emits a barcode; an HTTP client makes the
# request but the response handler is gone). Debug builds don't run R8, which
# is why the same code works in debug and breaks in release.
# -----------------------------------------------------------------------------

# ---------- Google ML Kit (barcode + text recognition) ----------
# mobile_scanner routes every barcode frame through com.google.mlkit.vision.barcode.*
# and google_mlkit_text_recognition through com.google.mlkit.vision.text.*.
# Without these keeps the QR scanner opens the camera but never detects a
# code, and the on-device OCR fails to instantiate the recognizer.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**

# The text recognizer references optional script recognizers we don't bundle —
# suppress the missing-class warnings that fail the R8 pass.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ---------- CameraX (mobile_scanner uses it under the hood on Android) ----------
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# ---------- Flutter plugin registrant + reflection surfaces ----------
# The generated GeneratedPluginRegistrant references plugin classes by fully
# qualified name; a stripped or renamed plugin class means the plugin never
# registers with the Flutter engine, and its Dart side receives no responses.
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.plugins.**

# Flutter's embedding ships a Play Store deferred-components manager that
# references Play Core. This app has no deferred components and doesn't bundle
# Play Core, so let R8 drop that path instead of failing on the missing classes.
-dontwarn com.google.android.play.core.**

# Plugins commonly use MethodChannel handlers looked up by name — keep any
# class annotated as a Flutter plugin registrant intact.
-keepclassmembers class * {
    @io.flutter.plugin.common.MethodCallHandler *;
}

# ---------- Our own MainActivity + MethodChannel handler ----------
# The `gate_reco/files` channel writes reports to Downloads via MediaStore.
# MainActivity is referenced from AndroidManifest so the class survives, but
# R8 can still rename/inline the Kotlin lambda's captured private methods
# (saveFileToDownloads/saveFileToLegacyDownloads) and their ContentValues/
# MediaStore call sites — which shows up as reports silently failing to save
# on release builds. Keep the whole class untouched.
-keep class com.example.gate_app.** { *; }

# ---------- share_plus + path_provider + printing ----------
# These plugins live under dev.fluttercommunity.plus.* and dev.ffi.* rather
# than io.flutter.plugins.*, so the generic Flutter keep above does NOT cover
# them. Missing these breaks the iOS share sheet fallback and any Android
# code path that uses temp dirs.
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class net.nfet.flutter.printing.** { *; }
-dontwarn dev.fluttercommunity.plus.**

# ---------- Kotlin metadata (used by ML Kit + several plugins) ----------
-keep class kotlin.Metadata { *; }
-keepattributes *Annotation*, InnerClasses, EnclosingMethod, Signature, Exceptions
