import 'package:flutter/material.dart';

class GameSettingsPage extends StatelessWidget {
  const GameSettingsPage({super.key, required this.onOpenDiagnostics});

  final VoidCallback onOpenDiagnostics;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('設定')),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListTile(
            key: const ValueKey('open-device-lab'),
            title: const Text('端末の計測'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenDiagnostics,
          ),
        ),
      ),
    ),
  );
}
