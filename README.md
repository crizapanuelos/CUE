# CUE

[Download the latest Android APK](https://github.com/crizapanuelos/CUE/releases/latest/download/CUE-Android.apk) · [Release history](https://github.com/crizapanuelos/CUE/releases)

Download the APK on an Android 7.0+ phone, open it, and allow installation from your Files app if prompted. Install over the existing CUE app to keep its local data.

CUE 1.3.0 is an offline billiards shop demonstration using the widgets in Lessons 1 and 2, ordinary StatefulWidget/setState, and the explicitly retained local storage. It includes 140 bundled product photos, search/filter/sort, grid/list browsing, wishlist, cart/coupons, delivery and simulated checkout, orders/tracking, local accounts/OTP, profiles/themes, support and local inventory administration.

## Run and build

Verified toolchain: Flutter 3.47.2 / Dart 3.13.2, Android SDK 36 and Java 21. Run flutter pub get, then flutter run. Build with flutter build apk --release or flutter build web --no-web-resources-cdn. Android 7.0 or newer is supported. Native Windows and iOS builds require their platform toolchains.

## Course implementation

See LESSON_APPLICATION.md and LESSON_WIDGET_AUDIT.json. All 23 directly authored Flutter UI widget types appear in the lesson text or code examples. SDK internal widgets are outside that source restriction. Card and FloatingActionButton are present in the lesson examples. Custom components compose only the allowed types. Riverpod is removed. Plain Dart services preserve existing storage, pricing and account formats.

## Limitations

The interface uses explicit buttons and text inputs instead of untaught dropdowns, sliders, switches, modal sheets and custom navigation widgets. Admin reporting uses text totals instead of a custom chart. The app is a local demonstration: no money is collected, no physical delivery occurs and no support messages are sent. Data does not synchronize across devices. Preferences are not encrypted secure storage; use fictional details. Product photos are AI-generated representations.

## Validation

Run flutter analyze and flutter test. The six focused tests cover persistence compatibility, catalog assets/prices, commerce consistency and the main shopping flow at 360/390 pixels. See VALIDATION.md for build verification. ANDROID_INSTALL.md explains installation. The current APK uses a local test signing key and is not a Play Store release.
