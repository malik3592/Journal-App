import 'dart:io';

import 'package:local_auth/local_auth.dart';

enum DeviceBiometric { none, faceId, touchId, fingerprint }

extension DeviceBiometricLabel on DeviceBiometric {
  String get label => switch (this) {
        DeviceBiometric.faceId => 'Face ID',
        DeviceBiometric.touchId => 'Touch ID',
        DeviceBiometric.fingerprint => 'Fingerprint',
        DeviceBiometric.none => 'Biometrics',
      };

  String get unlockLabel => switch (this) {
        DeviceBiometric.faceId => 'Unlock with Face ID',
        DeviceBiometric.touchId => 'Unlock with Touch ID',
        DeviceBiometric.fingerprint => 'Unlock with fingerprint',
        DeviceBiometric.none => 'Unlock with biometrics',
      };

  bool get isAvailable => this != DeviceBiometric.none;
}

class BiometricService {
  BiometricService({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<DeviceBiometric> available() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!supported || !canCheck) return DeviceBiometric.none;
      final types = await _auth.getAvailableBiometrics();
      if (types.isEmpty) return DeviceBiometric.none;
      if (Platform.isIOS) {
        if (types.contains(BiometricType.face)) return DeviceBiometric.faceId;
        if (types.contains(BiometricType.fingerprint)) return DeviceBiometric.touchId;
        return DeviceBiometric.none;
      }
      if (types.contains(BiometricType.fingerprint) || types.contains(BiometricType.strong)) {
        return DeviceBiometric.fingerprint;
      }
      return DeviceBiometric.none;
    } catch (_) {
      return DeviceBiometric.none;
    }
  }

  Future<bool> authenticate(DeviceBiometric biometric) async {
    if (!biometric.isAvailable) return false;
    try {
      return await _auth.authenticate(
        localizedReason: biometric.unlockLabel,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
