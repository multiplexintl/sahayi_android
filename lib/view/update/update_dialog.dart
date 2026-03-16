import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../service/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  /// Shows the non-dismissible update dialog.
  static Future<void> show(BuildContext context, UpdateInfo info) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(updateInfo: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final UpdateService _updateService = UpdateService();

  _Phase _phase = _Phase.idle;
  double _progress = 0.0;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back-button dismiss
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('Update Required'),
          ],
        ),
        content: _buildContent(),
        actions: _buildActions(),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Version ${widget.updateInfo.versionName} is available.',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        if (widget.updateInfo.notes.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            widget.updateInfo.notes,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
        const SizedBox(height: 16),
        if (_phase == _Phase.downloading) ...[
          Text(
            'Downloading... ${(_progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              backgroundColor: Colors.blue.shade100,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
            ),
          ),
        ],
        if (_phase == _Phase.installing) ...[
          const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Opening installer...', style: TextStyle(fontSize: 13)),
            ],
          ),
        ],
        if (_phase == _Phase.error) ...[
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _errorMessage ?? 'Download failed. Please try again.',
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget>? _buildActions() {
    if (_phase == _Phase.downloading || _phase == _Phase.installing) {
      return null; // No buttons while busy
    }
    return [
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _startDownload,
        child: Text(_phase == _Phase.error ? 'Retry' : 'Update Now'),
      ),
    ];
  }

  Future<void> _startDownload() async {
    setState(() {
      _phase = _Phase.downloading;
      _progress = 0.0;
      _errorMessage = null;
    });

    try {
      final File apkFile = await _updateService.downloadApk(
        updateInfo: widget.updateInfo,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      setState(() => _phase = _Phase.installing);
      await _openInstaller(apkFile);
    } catch (e) {
      log('Download/install error: $e');
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _errorMessage = 'Download failed. Please try again.';
        });
      }
    }
  }

  Future<void> _openInstaller(File apkFile) async {
    final result = await OpenFilex.open(
      apkFile.path,
      type: 'application/vnd.android.package-archive',
    );
    log('OpenFile result: ${result.type} — ${result.message}');

    // After install prompt is shown, go back to idle so user can retry if needed
    if (mounted) {
      setState(() => _phase = _Phase.idle);
    }
  }
}

enum _Phase { idle, downloading, installing, error }
