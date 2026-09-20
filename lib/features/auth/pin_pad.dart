import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:journal/app/theme/app_colors.dart';
import 'package:journal/core/auth/pin_hasher.dart';

class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.error,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < PinHasher.length; i++)
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < value.length ? AppColors.gold : Colors.transparent,
                  border: Border.all(
                    color: error != null
                        ? AppColors.negative
                        : AppColors.border,
                  ),
                ),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: AppColors.negative)),
        ],
        const SizedBox(height: 28),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', 'del'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final key in row)
                  _Key(
                    label: key,
                    enabled: enabled,
                    onTap: () {
                      if (!enabled || key.isEmpty) return;
                      HapticFeedback.selectionClick();
                      if (key == 'del') {
                        if (value.isEmpty) return;
                        onChanged(value.substring(0, value.length - 1));
                        return;
                      }
                      if (value.length >= PinHasher.length) return;
                      onChanged('$value$key');
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap, required this.enabled});
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox(width: 72, height: 72);
    return InkWell(
      onTap: enabled ? onTap : null,
      customBorder: const CircleBorder(),
      child: Ink(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.elevated,
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: label == 'del'
              ? const Icon(Icons.backspace_outlined, color: AppColors.text)
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
