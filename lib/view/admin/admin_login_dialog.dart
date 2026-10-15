import 'package:flutter/material.dart';
import 'package:sahayi_android/ui/ui.dart';
import 'package:get/get.dart';

import '../../routes.dart';
import '../../service/admin_service.dart';

/// Hidden admin login: user ID + password (checked by the server), or the
/// offline PIN (this device's logs only).
class AdminLoginDialog extends StatefulWidget {
  const AdminLoginDialog({super.key});

  static Future<void> show() =>
      Get.dialog(const AdminLoginDialog(), barrierDismissible: false);

  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();

  bool _usePin = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final error = _usePin
        ? await AdminService.unlockWithPin(_pinController.text)
        : await AdminService.login(_userController.text, _passwordController.text);

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }

    Get.back(); // close dialog
    Get.toNamed(RouteLinks.logsDashboard);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Whole dialog scrolls and uses small margins: fits small screens with
      // the keyboard open and large system fonts.
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      title: Text(_usePin ? 'Offline PIN' : 'Admin login'),
      content: Builder(
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_usePin)
              TextField(
                controller: _pinController,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  helperText: "Opens this device's logs only",
                ),
                onSubmitted: (_) => _busy ? null : _submit(),
              )
            else ...[
              TextField(
                controller: _userController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'User ID'),
              ),
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: context.c.dangerText)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _usePin = !_usePin;
                          _error = null;
                        }),
                child: Text(_usePin ? 'Use admin login instead' : 'No connection? Use offline PIN'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Get.back(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_usePin ? 'Unlock' : 'Login'),
        ),
      ],
    );
  }
}
