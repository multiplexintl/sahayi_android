import 'package:flutter/material.dart';

import '../view/admin/admin_login_dialog.dart';

/// Wraps a widget (the version text). Tapping it 7 times within 3 seconds
/// opens the hidden admin login. Normal taps do nothing.
class AdminTapDetector extends StatefulWidget {
  final Widget child;
  const AdminTapDetector({super.key, required this.child});

  @override
  State<AdminTapDetector> createState() => _AdminTapDetectorState();
}

class _AdminTapDetectorState extends State<AdminTapDetector> {
  static const int _tapsNeeded = 7;
  static const Duration _window = Duration(seconds: 3);

  int _taps = 0;
  DateTime? _firstTap;

  void _onTap() {
    final now = DateTime.now();
    if (_firstTap == null || now.difference(_firstTap!) > _window) {
      _firstTap = now;
      _taps = 0;
    }
    _taps++;
    if (_taps >= _tapsNeeded) {
      _taps = 0;
      _firstTap = null;
      AdminLoginDialog.show();
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Padding(
          // A slightly bigger target than the small version text.
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: widget.child,
        ),
      );
}
