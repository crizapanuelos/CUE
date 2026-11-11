import '../utils/format.dart';

const deliveryFields = [
  'Full name',
  'Contact number',
  'Email address',
  'Shipping address',
  'City',
  'Province',
  'Zip code',
];
const paymentMethods = ['Cash on Delivery', 'GCash', 'Maya', 'Bank Transfer'];
String? deliveryError(String key, String? value) {
  final v = value?.trim();
  if (key == 'Email address') {
    return emailError(v);
  }
  if (key == 'Contact number') {
    return RegExp(r'^\+?[\d\s-]{10,16}$').hasMatch(v ?? '')
        ? null
        : 'Enter a valid 10–15 digit number';
  }
  if (key == 'Zip code') {
    return RegExp(r'^\d{4}$').hasMatch(v ?? '')
        ? null
        : 'Enter a four-digit Philippine ZIP code';
  }
  return requiredText(v);
}
