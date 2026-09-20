import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:journal/app/theme/app_colors.dart';

void popOrGo(BuildContext context, [String fallback = '/trades']) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

Future<void> showAfterSaveOptions({
  required BuildContext context,
  required String title,
  required String message,
  required String primaryLabel,
  required VoidCallback onPrimary,
  required String secondaryLabel,
  required VoidCallback onSecondary,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: AppColors.secondary)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.pop(sheetContext);
                onPrimary();
              },
              child: Text(primaryLabel),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(sheetContext);
                onSecondary();
              },
              child: Text(secondaryLabel),
            ),
          ],
        ),
      ),
    ),
  );
}
