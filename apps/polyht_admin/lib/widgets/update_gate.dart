import 'dart:async';

import 'package:flutter/material.dart';

import '../services/update_service.dart';

class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  final _service = UpdateService();
  AppUpdate? _mandatoryUpdate;
  String? _checkError;
  bool _installing = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _check();
    _retryTimer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_installing || _mandatoryUpdate != null) return;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final update = await _service.checkForUpdate();
        if (mounted) {
          setState(() {
            _mandatoryUpdate = update?.mandatory == true ? update : null;
            _checkError = null;
          });
        }
        return;
      } catch (err) {
        if (mounted) {
          setState(() => _checkError =
              'Update check failed. Retrying when network is available.');
        }
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(seconds: 5));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = _mandatoryUpdate;
    if (update == null) {
      return Stack(
        children: [
          widget.child,
          if (_checkError != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Material(
                color: Colors.transparent,
                child: SafeArea(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _checkError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.system_update_alt_rounded, size: 64),
                const SizedBox(height: 16),
                Text('Update Required',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  update.releaseNotes.isEmpty
                      ? 'A newer secure build is required to continue.'
                      : update.releaseNotes,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _installing ? null : () => _install(update),
                  icon: _installing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(update.usesPlayStore
                          ? Icons.shop_rounded
                          : Icons.download_rounded),
                  label: Text(_installing
                      ? 'Downloading...'
                      : update.usesPlayStore
                          ? 'Update on Play Store'
                          : 'Download ${update.latestVersion}'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _install(AppUpdate update) async {
    setState(() => _installing = true);
    try {
      await _service.openUpdate(update);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err.toString())));
      }
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }
}
