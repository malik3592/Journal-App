import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/app/router.dart';
import 'package:journal/app/theme/app_theme.dart';
import 'package:journal/features/auth/lock_controller.dart';

class journalApp extends ConsumerStatefulWidget {
  const journalApp({super.key});

  @override
  ConsumerState<journalApp> createState() => _journalAppState();
}

class _journalAppState extends ConsumerState<journalApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only lock when the app is backgrounded. `hidden` also fires for the
    // keyboard, share sheet, Files picker, and Google sign-in.
    if (state == AppLifecycleState.paused) {
      ref.read(lockProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Trading Journal',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
