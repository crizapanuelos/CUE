# CUE 1.3 validation

- Flutter analysis and six tests are run against the rebuilt lesson interface, not the retired Riverpod interface.
- A source audit resolves Flutter widget inheritance from the installed SDK and checks direct constructor usage under lib against a lesson allowlist. Result: 23 allowed types; no Riverpod imports. Supporting styling/data classes are not counted as UI widgets.
- Tests verify 140 unique bundled photos, centavo calculations, account/cart/wishlist/inventory reload, serialized cart mutations, checkout and stock changes, immutable historical receipts, local password reset, form errors/visibility and the UI at 360/390 logical pixels.
- Current screenshots are captured from actual widget renders using fictional data, retained under test/screenshots.
- Storage is retained at the user's explicit request. Existing JSON keys, account hash format and Android application ID are unchanged. Installed-device update behavior still needs confirmation after installing version 1.3.
- All payments, orders, tracking and support are local simulations.

## Release verification

- Flutter analyze --no-pub: no issues. Flutter test --no-pub: all six tests passed.
- Optimized web build and Android release build succeeded. Android label CUE, version 1.3.0 code 5, minimum API 24 and target API 36. APK v2 signature verified with the same testing certificate used for installed version 1.2.1.
- All 140 JPEGs and the new CUE logo are bundled. APK ZIP checksums passed and built Dart sources match delivered sources.
- APK size: 73580596 bytes; SHA-256: A2A6DE87EFDDA1F9C946301377E7B435416AB9C2BB7428AE4A7E1B1FE3C27953.
- The TECNO was not connected during the 1.3.0 installation check, so this update has not been installed on the phone yet. Version 1.2.1 was previously installed and launched successfully.
