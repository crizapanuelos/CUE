# CUE 1.3 lesson interface

All directly authored Flutter UI widget types are shown in the supplied lessons. Flutter SDK internals naturally compose additional framework widgets; those internal implementations are not student-authored interface code.

## Lesson 1

- StatelessWidget: LessonButton and LessonPanel in lib/lesson_widgets.dart.
- StatefulWidget, createState, initState, setState and dispose: CueApp in lib/main.dart and LessonForm in lib/lesson_widgets.dart.
- MaterialApp, Scaffold and AppBar: application and screen structure.
- Text, Icon, Image, Container, Row, Column, Center, Expanded and SizedBox: shop layout and assets. Expanded and Center appear in the lesson code examples.
- FloatingActionButton (p. 36): all action buttons and navigation. Extended/small constructors use this same widget type; no FilledButton, IconButton or NavigationBar is authored.
- Placeholder (p. 34): missing-image fallback, not a replacement for finished product photos.
- Keys, child and children: composed widgets, form identity and product gallery identity.

## Lesson 2

- CarouselView: swipable home collections and product photographs.
- GridView and ListView: catalog grid/list, horizontal choices and scrolling screens.
- Align, Padding, SizedBox and Transform: placement, spacing and the rotated sale label.
- Card: product and information panels; explicitly present in pp. 13 and 15 code examples.
- Form, GlobalKey<FormState>, TextFormField and validators: sign-in, registration, OTP, profile, checkout, filters, product editor and support.
- TextInputType.emailAddress, visiblePassword and number: appropriate keyboards. obscureText controls password visibility.

## Deliberate replacements

Riverpod and consumer/provider widgets are removed. CueApp owns shared state, passes dependencies directly and calls setState after successful operations. NavigationBar and dialogs are replaced by Row/Column navigation and ordinary pages. Dropdowns, range sliders, checkboxes and switches are replaced by validated TextFormField inputs or FloatingActionButton choices. PageView, Hero, animated wrappers, chips, badges, custom painting, expansion tiles and layout wrappers beyond the lessons are absent from authored UI. Admin revenue charts become text totals.

## Authorized supporting code

The student explicitly requested retaining local storage. SharedPreferences and the existing JSON schemas remain; salted demo password hashing is retained so existing accounts still work. These support services, Dart models, asset loading, pricing and validation are not claimed as classroom widgets. Styling values, controllers, async functions and Flutter startup APIs support the taught widgets. The same Android application ID and test signing key permit updating the existing installation without intentionally clearing data.

## Files to present

lib/main.dart contains the complete shop composition and root StatefulWidget. lib/lesson_widgets.dart contains three reusable lesson components and form handling. lib/services/shop.dart contains ordinary Dart commerce/account operations. lib/services/local_store.dart retains device storage. LESSON_WIDGET_AUDIT.json lists the 23 directly authored Flutter widget types checked against the lessons.

## Verification

Six tests cover 140 catalog assets, centavo pricing, saved account/cart/inventory compatibility, serialized mutations, checkout, immutable historical receipts, password reset, form validation and the shopping UI at 360/390 pixels. These tests replace the previous Riverpod-specific suite. Orders and payments remain simulations.
