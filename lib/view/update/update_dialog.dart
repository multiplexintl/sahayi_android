import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../service/update_service.dart';
import '../../service/app_logger.dart';
import '../../ui/ui.dart';

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
        icon: Icon(Icons.system_update_rounded, size: 36, color: context.c.primary),
        title: const Text('Update required'),
        content: _buildContent(),
        actions: _buildActions(),
      ),
    );
  }

  Widget _buildContent() {
    final c = context.c;
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Version ${widget.updateInfo.versionName} is available.',
          style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (widget.updateInfo.notes.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            widget.updateInfo.notes,
            style: t.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        if (_phase == _Phase.downloading) ...[
          Text(
            'Downloading... ${(_progress * 100).toStringAsFixed(0)}%',
            style: t.bodySmall,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              backgroundColor: c.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(c.primary),
            ),
          ),
        ],
        if (_phase == _Phase.installing) ...[
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text('Opening installer...', style: t.bodySmall),
            ],
          ),
        ],
        if (_phase == _Phase.error) ...[
          Row(
            children: [
              Icon(Icons.error_outline, color: c.dangerText, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _errorMessage ?? 'Download failed. Please try again.',
                  style: t.bodySmall?.copyWith(color: c.dangerText),
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
      AppButton(
        label: _phase == _Phase.error ? 'Retry' : 'Update now',
        icon: _phase == _Phase.error ? Icons.refresh_rounded : Icons.download_rounded,
        expand: true,
        onPressed: _startDownload,
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
    } catch (e, st) {
      AppLogger.error('UpdateDownload', 'Download/install failed', error: e, stack: st);
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
    AppLogger.info('UpdateInstall', 'Installer opened: ${result.type.name} ${result.message}');

    // After install prompt is shown, go back to idle so user can retry if needed
    if (mounted) {
      setState(() => _phase = _Phase.idle);
    }
  }
}

enum _Phase { idle, downloading, installing, error }
