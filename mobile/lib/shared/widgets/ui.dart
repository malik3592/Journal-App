import 'package:flutter/material.dart';
import 'package:journal/app/theme/app_colors.dart';
import 'package:journal/core/formatters.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.positive});
  final String label;
  final bool? positive;

  @override
  Widget build(BuildContext context) {
    final color = positive == true
        ? AppColors.positive
        : positive == false
        ? AppColors.negative
        : switch (label) {
            'WIN' => AppColors.positive,
            'LOSS' => AppColors.negative,
            'OPEN' => AppColors.secondary,
            _ => AppColors.gold,
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class PnlText extends StatelessWidget {
  const PnlText(this.value, {super.key, this.size = 16});
  final num value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = value > 0
        ? AppColors.positive
        : value < 0
        ? AppColors.negative
        : AppColors.secondary;
    return Text(
      signedMoney(value),
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: size,
      ),
    );
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.positive,
  });
  final String label;
  final String value;
  final bool? positive;

  @override
  Widget build(BuildContext context) {
    final color = positive == null
        ? AppColors.text
        : positive!
        ? AppColors.positive
        : AppColors.negative;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.secondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.secondary),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: 'Could not load',
      message: message,
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
    );
  }
}

class PointsField extends StatelessWidget {
  const PointsField({
    super.key,
    required this.controller,
    required this.label,
    this.signed = false,
    this.enabled = true,
    this.helper = 'Accepts decimals / points',
  });

  final TextEditingController controller;
  final String label;
  final bool signed;
  final bool enabled;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: signed,
      ),
      inputFormatters: [PointInputFormatter(signed: signed)],
      decoration: InputDecoration(labelText: label, helperText: helper),
    );
  }
}

class DateTimeField extends StatelessWidget {
  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onPick,
    this.enabled = true,
    this.onClear,
    this.emptyLabel = 'Not set',
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  final bool enabled;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: value != null && onClear != null && enabled
            ? IconButton(
                tooltip: 'Clear',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              )
            : const Icon(Icons.schedule),
      ),
      child: InkWell(
        onTap: enabled
            ? () {
                FocusManager.instance.primaryFocus?.unfocus();
                onPick();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            value == null ? emptyLabel : formatDateTime(value!),
            style: TextStyle(
              color: enabled ? AppColors.text : AppColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
