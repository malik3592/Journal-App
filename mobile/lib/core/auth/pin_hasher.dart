import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PinHasher {
  static const length = 6;

  static bool isValid(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);

  static String createSalt() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String hash(String pin, String salt) {
    return sha256.convert(utf8.encode('journal|$salt|$pin')).toString();
  }

  static bool matches({
    required String pin,
    required String salt,
    required String expectedHash,
  }) {
    return hash(pin, salt) == expectedHash;
  }
}
