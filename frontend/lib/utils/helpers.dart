// Generic utility and helper functions
// This file is for generic helper functions that can be used across the app.
// For example, a function to format dates, show a dialog, etc.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Helpers {
  static String formatDateTime(DateTime dt) {
    return DateFormat.yMMMd().add_jm().format(dt);
  }

  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}