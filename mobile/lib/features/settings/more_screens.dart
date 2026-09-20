import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:journal/app/theme/app_colors.dart';
import 'package:journal/core/backup/local_backup.dart';
import 'package:journal/core/constants.dart';
import 'package:journal/core/errors.dart';
import 'package:journal/core/formatters.dart';
import 'package:journal/features/auth/lock_controller.dart';
import 'package:journal/features/auth/pin_pad.dart';
import 'package:journal/features/providers.dart';
import 'package:journal/shared/models/models.dart';
import 'package:journal/shared/widgets/cash_sheet.dart';
import 'package:journal/shared/widgets/ui.dart';
import 'package:share_plus/share_plus.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  bool localBusy = false;
  bool driveBusy = false;
  String? localMessage;
  String? driveMessage;
  bool localError = false;
  bool driveError = false;
  Timer? _statusTimer;

  bool get _busy => localBusy || driveBusy;

  void _clearStatus() {
    _statusTimer?.cancel();
    if (!mounted) return;
    if (localMessage == null && driveMessage == null) return;
    setState(() {
      localMessage = null;
      driveMessage = null;
      localError = false;
      driveError = false;
    });
  }

  void _beginAction() {
    _statusTimer?.cancel();
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    if (localMessage != null || driveMessage != null) {
      setState(() {
        localMessage = null;
        driveMessage = null;
        localError = false;
        driveError = false;
      });
    }
  }

  void _armStatusClear() {
    _statusTimer?.cancel();
    _statusTimer = Timer(const Duration(seconds: 4), _clearStatus);
  }

  void _setLocalStatus(String? text, {bool error = false}) {
    setState(() {
      localMessage = text;
      localError = error;
    });
    _armStatusClear();
  }

  void _setDriveStatus(String? text, {bool error = false}) {
    setState(() {
      driveMessage = text;
      driveError = error;
    });
    _armStatusClear();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _toast(String text) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _status(String? text, {required bool error}) {
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        style: TextStyle(color: error ? AppColors.negative : AppColors.gold),
      ),
    );
  }

  Future<bool> _confirmRestore(String source) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Restore from $source?'),
            content: const Text(
              'This replaces all trades, journal notes, and profile data on this phone with the backup. Your PIN stays on this device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Restore'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _applyRestore(
    String json,
    String successMessage, {
    required bool drive,
  }) async {
    await ref.read(journalProvider.notifier).restoreFromBackup(json);
    ref.invalidate(localBackupsProvider);
    if (!mounted) return;
    if (drive) {
      _setDriveStatus(successMessage);
    } else {
      _setLocalStatus(successMessage);
    }
  }

  Future<T> _keepUnlocked<T>(Future<T> Function() action) {
    return ref.read(lockProvider.notifier).runWhileUnlocked(action);
  }

  Future<void> _backupLocal() async {
    _beginAction();
    setState(() {
      localBusy = true;
    });
    try {
      final json = ref.read(journalProvider.notifier).exportJson();
      final file = await ref.read(localBackupProvider).save(json);
      ref.invalidate(localBackupsProvider);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final copied = await _keepUnlocked(
        () => ref
            .read(localBackupProvider)
            .exportVisible(
              file,
              sharePositionOrigin: box == null || !box.hasSize
                  ? null
                  : box.localToGlobal(Offset.zero) & box.size,
            ),
      );
      if (!mounted) return;
      if (copied) {
        _setLocalStatus(
          'Backup saved in the app and copied to the folder you chose.',
        );
      } else {
        _setLocalStatus(
          'Backup saved in the app. No extra copy was saved in Files.',
        );
      }
    } on AppException catch (e) {
      _setLocalStatus(e.message, error: true);
    } catch (e) {
      _setLocalStatus(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => localBusy = false);
    }
  }

  Future<void> _exportLocal() async {
    _beginAction();
    setState(() {
      localBusy = true;
    });
    try {
      final json = ref.read(journalProvider.notifier).exportJson();
      final file = await ref.read(localBackupProvider).save(json);
      ref.invalidate(localBackupsProvider);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final result = await _keepUnlocked(
        () => ref
            .read(localBackupProvider)
            .share(
              file,
              sharePositionOrigin: box == null
                  ? null
                  : box.localToGlobal(Offset.zero) & box.size,
            ),
      );
      if (!mounted) return;
      if (result.status == ShareResultStatus.dismissed) {
        _setLocalStatus('Share closed. No extra file was exported.');
        return;
      }
      _setLocalStatus('Backup shared.');
    } on AppException catch (e) {
      _setLocalStatus(e.message, error: true);
    } catch (e) {
      _setLocalStatus(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => localBusy = false);
    }
  }

  Future<void> _restoreLocalFile() async {
    _beginAction();
    try {
      final json = await _keepUnlocked(
        () => ref.read(localBackupProvider).pick(),
      );
      if (json == null || !mounted) {
        if (mounted)
          _setLocalStatus('Restore cancelled. No file was imported.');
        return;
      }
      if (!await _confirmRestore('this file')) {
        if (mounted) _setLocalStatus('Restore cancelled.');
        return;
      }
      setState(() {
        localBusy = true;
      });
      await _applyRestore(
        json,
        'Journal restored from a local file.',
        drive: false,
      );
    } on AppException catch (e) {
      _setLocalStatus(e.message, error: true);
    } catch (e) {
      _setLocalStatus(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => localBusy = false);
    }
  }

  Future<void> _restoreLatestLocal() async {
    _beginAction();
    final latest = await ref.read(localBackupProvider).latest();
    if (latest == null) {
      _setLocalStatus('No local backup file was found.', error: true);
      return;
    }
    if (!await _confirmRestore('the latest file on this phone')) {
      if (mounted) _setLocalStatus('Restore cancelled.');
      return;
    }
    setState(() {
      localBusy = true;
    });
    try {
      final json = await ref.read(localBackupProvider).read(latest.file);
      await _applyRestore(
        json,
        'Journal restored from the latest local backup.',
        drive: false,
      );
    } on AppException catch (e) {
      _setLocalStatus(e.message, error: true);
    } catch (e) {
      _setLocalStatus(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => localBusy = false);
    }
  }

  Future<void> _backupDrive() async {
    _beginAction();
    setState(() {
      driveBusy = true;
    });
    try {
      final json = ref.read(journalProvider.notifier).exportJson();
      await _keepUnlocked(() => ref.read(driveBackupProvider).backup(json));
      ref.invalidate(googleAccountProvider);
      if (mounted) {
        _setDriveStatus(
          'Backup uploaded to Google Drive as ${AppConfig.driveBackupFileName}.',
        );
      }
    } on AppException catch (e) {
      _setDriveStatus(e.message, error: true);
    } catch (e) {
      _setDriveStatus(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => driveBusy = false);
    }
  }

  Future<void> _restoreDrive() async {
    _beginAction();
    if (!await _confirmRestore('Google Drive')) {
      if (mounted) _setDriveStatus('Restore cancelled.');
      return;
    }
    setState(() {
      driveBusy = true;
    });
    try {
      final json = await _keepUnlocked(
        () => ref.read(driveBackupProvider).restore(),
      );
      await _applyRestore(
        json,
        'Journal restored from Google Drive.',
        drive: true,
      );
      ref.invalidate(googleAccountProvider);
    } on AppException catch (e) {
      _setDriveStatus(e.message, error: true);
    } catch (e) {
      _setDriveStatus(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => driveBusy = false);
    }
  }

  Future<void> _editProfile() async {
    _beginAction();
    final journal = ref.read(journalProvider);
    final name = TextEditingController(text: journal.profile.displayName);
    final timezone = TextEditingController(text: journal.profile.timezone);
    final currency = TextEditingController(text: journal.profile.currency);
    final starting = TextEditingController(text: journal.startingBalance);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Display name'),
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
                decoration: const InputDecoration(
                  labelText: 'Starting balance',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    if (saved == true) {
      await ref
          .read(journalProvider.notifier)
          .updateProfile(
            displayName: name.text.trim().isEmpty ? 'Trader' : name.text.trim(),
            timezone: timezone.text.trim().isEmpty
                ? 'UTC'
                : timezone.text.trim(),
            currency: currency.text.trim().isEmpty
                ? 'USD'
                : currency.text.trim(),
            startingBalance: normalizePoint(starting.text) ?? '0',
          );
    }
    name.dispose();
    timezone.dispose();
    currency.dispose();
    starting.dispose();
  }

  Future<String?> _askPin(String title) async {
    var value = '';
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    PinPad(
                      value: value,
                      onChanged: (next) {
                        setSheet(() => value = next);
                        if (next.length == 6) Navigator.pop(context, next);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _changePin() async {
    _beginAction();
    final current = await _askPin('Current PIN');
    if (current == null || !mounted) return;
    final next = await _askPin('New 6-digit PIN');
    if (next == null || !mounted) return;
    final confirm = await _askPin('Confirm new PIN');
    if (confirm == null || !mounted) return;
    if (next != confirm) {
      _toast('New PINs do not match.');
      return;
    }
    try {
      await ref
          .read(lockProvider.notifier)
          .changePin(current: current, next: next);
      _toast('PIN updated.');
    } on AppException catch (e) {
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final journal = ref.watch(journalProvider);
    final overview = ref.watch(overviewProvider).valueOrNull;
    final balance = overview?.balance ?? parseMoney(journal.startingBalance);
    final google = ref.watch(googleAccountProvider);
    final lock = ref.watch(lockProvider);
    final backups =
        ref.watch(localBackupsProvider).valueOrNull ??
        const <LocalBackupInfo>[];
    final latest = backups.isEmpty ? null : backups.first;
    final user = journal.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile / Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.elevated,
                  child: Icon(Icons.person, color: AppColors.gold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'Local journal',
                        style: TextStyle(color: AppColors.secondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _editProfile,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Security', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(lock.biometric.label),
                  value: lock.canUseBiometrics,
                  onChanged: !lock.biometric.isAvailable || _busy
                      ? null
                      : (value) async {
                          if (!lock.pinSet) {
                            await showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Set a PIN first'),
                                content: Text(
                                  'Set a PIN before turning on ${lock.biometric.label}.',
                                ),
                                actions: [
                                  FilledButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }
                          _beginAction();
                          try {
                            if (value) {
                              await ref
                                  .read(lockProvider.notifier)
                                  .enableBiometrics();
                            } else {
                              await ref
                                  .read(lockProvider.notifier)
                                  .disableBiometrics();
                            }
                          } on AppException catch (e) {
                            if (mounted) _toast(e.message);
                          }
                        },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.pin),
                  title: const Text('Change PIN'),
                  onTap: _busy ? null : _changePin,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Lock now'),
                  onTap: () {
                    _beginAction();
                    ref.read(lockProvider.notifier).lock();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Backup & restore',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'On this phone',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  latest == null
                      ? 'Saves a copy in the app, then asks where to put a copy in Files.'
                      : 'Latest local backup  ${formatDateTime(latest.modifiedAt)}',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 13,
                  ),
                ),
                _status(localMessage, error: localError),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: localBusy ? null : _backupLocal,
                  child: Text(
                    localBusy ? 'Working...' : 'Backup on this phone',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: localBusy ? null : _exportLocal,
                  child: const Text('Share file'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: localBusy ? null : _restoreLocalFile,
                  child: const Text('Restore from a file'),
                ),
                if (latest != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: localBusy ? null : _restoreLatestLocal,
                    child: const Text('Restore latest local backup'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Google Drive',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  google.valueOrNull?.email ?? 'Not signed in',
                  style: const TextStyle(color: AppColors.secondary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Optional cloud copy. Restore replaces local journal data with that Drive file.',
                  style: TextStyle(color: AppColors.secondary, fontSize: 13),
                ),
                _status(driveMessage, error: driveError),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: driveBusy ? null : _backupDrive,
                  child: Text(
                    driveBusy ? 'Working...' : 'Backup to Google Drive',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: driveBusy ? null : _restoreDrive,
                  child: const Text('Restore from Google Drive'),
                ),
                if (google.valueOrNull != null)
                  TextButton(
                    onPressed: driveBusy
                        ? null
                        : () async {
                            _beginAction();
                            await ref.read(driveBackupProvider).signOut();
                            ref.invalidate(googleAccountProvider);
                          },
                    child: const Text('Disconnect Google'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('Timezone'),
                  trailing: Text(
                    user.timezone,
                    style: const TextStyle(color: AppColors.secondary),
                  ),
                  onTap: _editProfile,
                ),
                ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Currency'),
                  trailing: Text(
                    user.currency,
                    style: const TextStyle(color: AppColors.secondary),
                  ),
                  onTap: _editProfile,
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Starting balance'),
                  trailing: Text(
                    money(parseMoney(journal.startingBalance)),
                    style: const TextStyle(color: AppColors.secondary),
                  ),
                  onTap: _editProfile,
                ),
                ListTile(
                  leading: const Icon(Icons.savings_outlined),
                  title: const Text('Balance'),
                  trailing: Text(
                    money(balance),
                    style: const TextStyle(color: AppColors.secondary),
                  ),
                  onTap: () => showCashSheet(context),
                ),
                ListTile(
                  leading: const Icon(Icons.add_card_outlined),
                  title: const Text('Deposit'),
                  onTap: () => showAddCashSheet(context, type: 'deposit'),
                ),
                ListTile(
                  leading: const Icon(Icons.outbox_outlined),
                  title: const Text('Withdraw'),
                  onTap: () => showAddCashSheet(context, type: 'withdrawal'),
                ),
                if (journal.cashMovements.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: CashHistoryList(
                      movements: sortCashNewest(journal.cashMovements),
                      nested: true,
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Calendar'),
                  onTap: () => context.push('/calendar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
