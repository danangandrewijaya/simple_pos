import 'package:flutter/material.dart';

// Helper to show consistent SnackBars: clears existing, supports action
void showAppSnackBar(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction, Duration? duration}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  final snack = SnackBar(
    content: Text(message),
    duration: duration ?? const Duration(seconds: 2),
    action: (actionLabel != null && onAction != null)
        ? SnackBarAction(label: actionLabel, onPressed: onAction)
        : null,
  );
  messenger.showSnackBar(snack);
}
