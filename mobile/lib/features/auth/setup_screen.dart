import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:journal/app/theme/app_colors.dart';
import 'package:journal/core/auth/pin_hasher.dart';
import 'package:journal/core/errors.dart';
import 'package:journal/core/formatters.dart';
import 'package:journal/features/auth/lock_controller.dart';
import 'package:journal/features/auth/pin_pad.dart';
import 'package:journal/features/providers.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final name = TextEditingController();
  final timezone = TextEditingController(text: 'UTC');
  final currency = TextEditingController(text: 'USD');
  final starting = TextEditingController(text: '0');
  int step = 0;
  String pin = '';
  String confirm = '';
  String? error;
  bool busy = false;
  bool primed = false;

  @override
  void dispose() {
    name.dispose();
    timezone.dispose();
    currency.dispose();
    starting.dispose();
    super.dispose();
  }

  void _prime() {
    if (primed) return;
    primed = true;
    final profile = ref.read(journalProvider).profile;
    if (profile.displayName.isNotEmpty && profile.displayName != 'Trader') {
      name.text = profile.displayName;
    }
    timezone.text = profile.timezone;
    currency.text = profile.currency;
    starting.text = ref.read(journalProvider).startingBalance;
  }

  Future<void> _nextFromProfile() async {
    if (name.text.trim().length < 2) {
      setState(() => error = 'Enter your name.');
      return;
    }
    final lock = ref.read(lockProvider);
    if (lock.pinSet) {
      setState(() => busy = true);
      try {
        await ref
            .read(journalProvider.notifier)
            .completeSetup(
              displayName: name.text.trim(),
              timezone: timezone.text.trim().isEmpty
                  ? 'UTC'
                  : timezone.text.trim(),
              currency: currency.text.trim().isEmpty
                  ? 'USD'
                  : currency.text.trim(),
              startingBalance: normalizePoint(starting.text) ?? '0',
            );
        if (mounted) context.go('/lock');
      } finally {
        if (mounted) setState(() => busy = false);
      }
      return;
    }
    setState(() {
      error = null;
      step = 1;
      pin = '';
    });
  }

  Future<void> _onPin(String value) async {
    setState(() {
      pin = value;
      error = null;
    });
    if (value.length == PinHasher.length) {
      setState(() {
        step = 2;
        confirm = '';
      });
    }
  }

  Future<void> _onConfirm(String value) async {
    setState(() {
      confirm = value;
      error = null;
    });
    if (value.length != PinHasher.length) return;
    if (value != pin) {
      setState(() {
        error = 'PINs do not match. Try again.';
        confirm = '';
        step = 1;
        pin = '';
      });
      return;
    }
    if (ref.read(lockProvider).biometric.isAvailable) {
      setState(() => step = 3);
      return;
    }
    await _finish(enableBiometrics: false);
  }

  Future<void> _finish({required bool enableBiometrics}) async {
    setState(() => busy = true);
    try {
      await ref.read(lockProvider.notifier).setPin(pin);
      if (enableBiometrics) {
        try {
          await ref.read(lockProvider.notifier).enableBiometrics();
        } on AppException catch (e) {
          if (mounted) setState(() => error = e.message);
        }
      }
      await ref
          .read(journalProvider.notifier)
          .completeSetup(
            displayName: name.text.trim(),
            timezone: timezone.text.trim().isEmpty
                ? 'UTC'
                : timezone.text.trim(),
            currency: currency.text.trim().isEmpty
                ? 'USD'
                : currency.text.trim(),
            startingBalance: normalizePoint(starting.text) ?? '0',
          );
      if (mounted) context.go('/home');
    } on AppException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _prime();
    final lock = ref.watch(lockProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (step) {
            0 => _profile(),
            1 => _pinStep(
              title: 'Create a 6-digit PIN',
              subtitle:
                  'This PIN is required to open the journal. Face ID or fingerprint can be added after.',
              value: pin,
              onChanged: _onPin,
            ),
            2 => _pinStep(
              title: 'Confirm your PIN',
              subtitle: 'Re-enter the same 6 digits.',
              value: confirm,
              onChanged: _onConfirm,
            ),
            _ => _biometricStep(lock),
          },
        ),
      ),
    );
  }

  Widget _profile() {
    return ListView(
      children: [
        const Text(
          'Set up your journal',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your name and a PIN are required. Everything stays on this device.',
          style: TextStyle(color: AppColors.secondary, fontSize: 16),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Your name'),
          onChanged: (_) {
            if (error != null) setState(() => error = null);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: timezone,
          decoration: const InputDecoration(labelText: 'Timezone'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: currency,
          decoration: const InputDecoration(labelText: 'Currency'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: starting,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: const InputDecoration(labelText: 'Starting balance'),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: AppColors.negative)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : _nextFromProfile,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _pinStep({
    required String title,
    required String subtitle,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    error = null;
                    if (step == 2) {
                      step = 1;
                      pin = '';
                      confirm = '';
                    } else {
                      step = 0;
                      pin = '';
                    }
                  }),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.secondary),
        ),
        const Spacer(),
        PinPad(
          value: value,
          onChanged: onChanged,
          enabled: !busy,
          error: error,
        ),
        const Spacer(),
      ],
    );
  }

  Widget _biometricStep(AppLockState lock) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Faster unlock',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          lock.biometric.isAvailable
              ? 'PIN is still required as the primary lock. ${lock.biometric.label} is optional.'
              : 'This device has no Face ID or fingerprint sensor. Continue with PIN only.',
          style: const TextStyle(color: AppColors.secondary),
        ),
        const Spacer(),
        if (error != null)
          Text(error!, style: const TextStyle(color: AppColors.negative)),
        if (lock.biometric.isAvailable)
          FilledButton(
            onPressed: busy ? null : () => _finish(enableBiometrics: true),
            child: Text(busy ? 'Saving...' : 'Turn on ${lock.biometric.label}'),
          ),
        if (lock.biometric.isAvailable) const SizedBox(height: 12),
        OutlinedButton(
          onPressed: busy ? null : () => _finish(enableBiometrics: false),
          child: Text(busy ? 'Saving...' : 'Continue with PIN only'),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () => setState(() {
                  step = 1;
                  pin = '';
                  confirm = '';
                  error = null;
                }),
          child: const Text('Choose a different PIN'),
        ),
      ],
    );
  }
}
