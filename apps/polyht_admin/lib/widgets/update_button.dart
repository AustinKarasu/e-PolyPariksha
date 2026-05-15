import 'package:flutter/material.dart';

import '../services/update_service.dart';

class UpdateButton extends StatefulWidget {
  const UpdateButton({super.key});

  @override
  State<UpdateButton> createState() => _UpdateButtonState();
}

class _UpdateButtonState extends State<UpdateButton> {
  final _service = UpdateService();
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Check for update',
      onPressed: _checking ? null : _check,
      icon: _checking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.system_update_alt),
    );
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final update = await _service.checkForUpdate();
      if (!mounted) return;
      if (update == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('App is up to date.')));
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: !update.mandatory,
        builder: (context) => AlertDialog(
          title: Text('Update ${update.latestVersion} available'),
          content: Text(update.releaseNotes.isEmpty
              ? update.fallbackMessage
              : update.releaseNotes),
          actions: [
            if (!update.mandatory)
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Later')),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _service.openUpdate(update);
              },
              child: Text(update.actionLabel),
            ),
          ],
        ),
      );
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err.toString())));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }
}
