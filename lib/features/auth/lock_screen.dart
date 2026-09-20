import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/app/theme/app_colors.dart';
import 'package:journal/core/auth/pin_hasher.dart';
import 'package:journal/core/errors.dart';
import 'package:journal/features/auth/lock_controller.dart';
import 'package:journal/features/auth/pin_pad.dart';
import 'package:journal/features/providers.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String pin = '';
  String? error;
  bool prompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometrics());
  }

  Future<void> _tryBiometrics({bool manual = false}) async {
    if (prompted && !manual) return;
    final lock = ref.read(lockProvider);
    if (!lock.canUseBiometrics || lock.unlocked) return;
    if (!manual) prompted = true;
    try {
      await ref.read(lockProvider.notifier).unlockWithBiometrics();
    } on AppException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> _onPin(String value) async {
    setState(() {
      pin = value;
      error = null;
    });
    if (value.length != PinHasher.length) return;
    try {
      final ok = await ref.read(lockProvider.notifier).unlockWithPin(value);
      if (!ok && mounted) {
        setState(() {
          pin = '';
          error = 'Incorrect PIN.';
        });
      }
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          pin = '';
          error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockProvider);
    final name = ref.watch(journalProvider).profile.displayName;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.show_chart, color: AppColors.gold, size: 44),
              const SizedBox(height: 16),
              Text(
                'Welcome back${name.isEmpty ? '' : ', $name'}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your PIN to open the journal',
                style: TextStyle(color: AppColors.secondary),
              ),
              const Spacer(),
              PinPad(
                value: pin,
                onChanged: _onPin,
                enabled: !lock.busy && !lock.isLockedOut,
                error: error,
              ),
              if (lock.canUseBiometrics) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: lock.busy
                      ? null
                      : () => _tryBiometrics(manual: true),
                  icon: Icon(
                    lock.biometric == DeviceBiometric.faceId
                        ? Icons.face
                        : Icons.fingerprint,
                  ),
                  label: Text(lock.biometric.unlockLabel),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
