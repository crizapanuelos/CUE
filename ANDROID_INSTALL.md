# Install CUE on Android

1. Copy **CUE-Android.apk** from this computer to your Android phone, using USB, cloud storage, or another file-transfer method you normally use.
2. Open the APK on your phone using Files or your download manager.
3. If Android asks, allow that Files app or browser to install unknown apps, then return to the APK and tap **Install**.
4. Open **CUE** from your app drawer. Complete onboarding and choose **Continue as guest** or create a local account.

The Android app runs directly on your phone; a browser or local web server is not required. All 140 product photographs and the catalog are bundled. Shopping, wishlists, accounts, orders, and tracking work offline. Orders and payments are simulated.

Shopping data is saved separately on each device. Browser shopping data does not automatically transfer to the Android installation. Android application backup is disabled for this local demonstration.

The APK supports Android 7.0 or later and includes the supported phone CPU architectures. This installation build is for direct installation and testing, not a Google Play Store submission. It uses the project's local testing signing identity. A store release needs your own release signing configuration.

## Build from the Flutter source

Install Flutter, Java, and the Android SDK, then run from the source folder:

```sh
flutter pub get
flutter build apk --release
```

The installer is generated at `build/app/outputs/flutter-apk/app-release.apk`. The project uses SDK 36, NDK 28.2.13676358, and the compatible CMake toolchain. Development prerequisites are separate from the phone installer; you do not need Flutter or Android Studio on the phone.
