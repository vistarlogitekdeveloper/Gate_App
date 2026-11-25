# Android release signing

Android only installs an APK as an **update** when it is signed with the same
key as the installed one and has a higher `versionCode`. Until November 2026
the Gate APK was signed with the build machine's debug key, so a copy built on
another machine (or after the debug key changed) had to be uninstalled first.

## One-time: create the release key (keep it forever)

Run this on the machine that builds the app. It asks for a password, and for
your name and organisation. Pick a strong password and **store it in the
company password manager**. `keytool` is not on PATH on the build PC, so use
the one that ships with Android Studio:

```
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v -keystore C:\keys\vistar-gate-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias vistar-gate
```

(The leading `&` is for PowerShell; drop it in `cmd`.)

Then create `android/key.properties` (git-ignored, never commit it):

```
storeFile=C:/keys/vistar-gate-release.jks
storePassword=<the password>
keyAlias=vistar-gate
keyPassword=<the password>
```

**Back up `vistar-gate-release.jks` and the password** somewhere safe, outside
this PC. This key is Gate's own; do not reuse another app's keystore.

## Every APK you hand out

1. Raise `version:` in `pubspec.yaml`. Raise the number after `+` by one each
   time, e.g. `1.0.1+2` → `1.0.2+3`.
2. Build: `flutter build apk --release`.
3. The APK is at `build/app/outputs/flutter-apk/app-release.apk`.

The build prints which key it used. Without `key.properties` it falls back to
the debug key, which is fine for a test build only.

## The first release-signed APK

The app id changed from `com.example.gate_app` to `com.vistarlogitek.gate`
with this setup, so the new app installs **next to** any old Gate APK instead
of over it. Uninstall the old "gate_app" once; after that, every new
release-signed APK installs over the previous one.

## Google Play (app id `com.vistarlogitek.gate`)

Play takes an **app bundle**, not an APK:

1. Raise `version:` in `pubspec.yaml` (the `+` number must go up for every
   upload, Play refuses a number it has seen).
2. `flutter build appbundle --release` (the build must say it used the release
   key; Play rejects a debug-signed bundle).
3. Upload `build/app/outputs/bundle/release/app-release.aab` in Play Console.

Check which key signed a bundle:

```
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
```

The keystore above is the **upload key**. On the first upload, accept *Play App
Signing*: Google keeps the key that signs the app phones download. If the upload
key is lost, Play support can reset it, but keep the backup anyway.

APKs from Play are signed by Google's key, so a hand-built APK can't install
over a Play install (or the other way round). Once Gate is on Play, install it
from Play only.
