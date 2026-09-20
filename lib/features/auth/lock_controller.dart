import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/core/auth/biometric_service.dart';
import 'package:journal/core/auth/pin_hasher.dart';
import 'package:journal/core/auth/secure_pin_store.dart';
import 'package:journal/core/errors.dart';

export 'package:journal/core/auth/biometric_service.dart';

class AppLockState {
  const AppLockState({
    required this.ready,
    required this.pinSet,
    required this.unlocked,
    required this.biometricsEnabled,
    required this.biometric,
    this.busy = false,
    this.lockoutUntil,
  });

  final bool ready;
  final bool pinSet;
  final bool unlocked;
  final bool biometricsEnabled;
  final DeviceBiometric biometric;
  final bool busy;
  final DateTime? lockoutUntil;

  bool get canUseBiometrics =>
      pinSet && biometricsEnabled && biometric.isAvailable;

  bool get isLockedOut =>
      lockoutUntil != null && DateTime.now().isBefore(lockoutUntil!);

  AppLockState copyWith({
    bool? ready,
    bool? pinSet,
    bool? unlocked,
    bool? biometricsEnabled,
    DeviceBiometric? biometric,
    bool? busy,
    DateTime? lockoutUntil,
    bool clearLockout = false,
  }) {
    return AppLockState(
      ready: ready ?? this.ready,
      pinSet: pinSet ?? this.pinSet,
      unlocked: unlocked ?? this.unlocked,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      biometric: biometric ?? this.biometric,
      busy: busy ?? this.busy,
      lockoutUntil: clearLockout ? null : (lockoutUntil ?? this.lockoutUntil),
    );
  }
}

class LockNotifier extends StateNotifier<AppLockState> {
  LockNotifier(this._store, this._biometrics)
    : super(
        const AppLockState(
          ready: false,
          pinSet: false,
          unlocked: false,
          biometricsEnabled: false,
          biometric: DeviceBiometric.none,
        ),
      ) {
    reload();
  }

  final SecurePinStore _store;
  final BiometricService _biometrics;
  int _failures = 0;
  int _externalUi = 0;
  bool authenticating = false;

  bool get _keepUnlocked => authenticating || _externalUi > 0;

  Future<T> runWhileUnlocked<T>(Future<T> Function() action) async {
    _externalUi++;
    try {
      return await action();
    } finally {
      if (_externalUi > 0) _externalUi--;
    }
  }

  Future<void> reload() async {
    final pinSet = await _store.hasPin;
    var biometricsEnabled = pinSet && await _store.biometricsEnabled;
    final biometric = await _biometrics.available();
    if (biometricsEnabled && !biometric.isAvailable) {
      biometricsEnabled = false;
      await _store.setBiometricsEnabled(false);
    }
    if (!pinSet && biometricsEnabled) {
      biometricsEnabled = false;
      await _store.setBiometricsEnabled(false);
    }
    state = AppLockState(
      ready: true,
      pinSet: pinSet,
      unlocked: false,
      biometricsEnabled: biometricsEnabled,
      biometric: biometric,
    );
  }

  void lock() {
    if (!state.pinSet || _keepUnlocked) return;
    state = state.copyWith(unlocked: false);
  }

  Future<void> setPin(String pin) async {
    _assertValid(pin);
    final salt = PinHasher.createSalt();
    await _store.savePin(hash: PinHasher.hash(pin, salt), salt: salt);
    _failures = 0;
    state = state.copyWith(pinSet: true, unlocked: true, clearLockout: true);
  }

  Future<void> changePin({
    required String current,
    required String next,
  }) async {
    if (!await unlockWithPin(current)) {
      throw AppException('Current PIN is incorrect.');
    }
    await setPin(next);
  }

  Future<bool> unlockWithPin(String pin) async {
    _throwIfLockedOut();
    final credentials = await _store.credentials();
    if (credentials == null) {
      throw AppException('No PIN is set yet.');
    }
    final ok = PinHasher.matches(
      pin: pin,
      salt: credentials.salt,
      expectedHash: credentials.hash,
    );
    if (!ok) {
      _registerFailure();
      return false;
    }
    _failures = 0;
    state = state.copyWith(unlocked: true, clearLockout: true);
    return true;
  }

  Future<bool> unlockWithBiometrics() async {
    if (!state.canUseBiometrics) {
      throw AppException('Set a PIN before using ${state.biometric.label}.');
    }
    authenticating = true;
    state = state.copyWith(busy: true);
    try {
      final ok = await _biometrics.authenticate(state.biometric);
      if (ok) {
        _failures = 0;
        state = state.copyWith(unlocked: true, busy: false, clearLockout: true);
      } else {
        state = state.copyWith(busy: false);
      }
      return ok;
    } finally {
      authenticating = false;
    }
  }

  Future<void> enableBiometrics() async {
    if (!state.pinSet) {
      throw AppException(
        'Set a PIN first. ${state.biometric.label} cannot be turned on without a PIN.',
      );
    }
    if (!state.biometric.isAvailable) {
      throw AppException(
        '${state.biometric.label} is not available on this device.',
      );
    }
    authenticating = true;
    state = state.copyWith(busy: true);
    try {
      final ok = await _biometrics.authenticate(state.biometric);
      if (!ok) {
        throw AppException('${state.biometric.label} was not confirmed.');
      }
      await _store.setBiometricsEnabled(true);
      state = state.copyWith(biometricsEnabled: true, busy: false);
    } finally {
      authenticating = false;
      if (state.busy) state = state.copyWith(busy: false);
    }
  }

  Future<void> disableBiometrics() async {
    await _store.setBiometricsEnabled(false);
    state = state.copyWith(biometricsEnabled: false);
  }

  void _assertValid(String pin) {
    if (!PinHasher.isValid(pin)) {
      throw AppException('PIN must be exactly ${PinHasher.length} digits.');
    }
  }

  void _throwIfLockedOut() {
    if (state.isLockedOut) {
      final seconds = state.lockoutUntil!.difference(DateTime.now()).inSeconds;
      throw AppException('Too many attempts. Try again in $seconds seconds.');
    }
  }

  void _registerFailure() {
    _failures += 1;
    if (_failures >= 5) {
      _failures = 0;
      state = state.copyWith(
        lockoutUntil: DateTime.now().add(const Duration(seconds: 20)),
      );
    }
  }
}

final securePinStoreProvider = Provider((ref) => SecurePinStore());
final biometricServiceProvider = Provider((ref) => BiometricService());

final lockProvider = StateNotifierProvider<LockNotifier, AppLockState>(
  (ref) => LockNotifier(
    ref.watch(securePinStoreProvider),
    ref.watch(biometricServiceProvider),
  ),
);
