import 'package:flutter/material.dart';

import 'workshop_theme.dart';

class GameSettingsPage extends StatelessWidget {
  const GameSettingsPage({super.key, required this.onOpenDiagnostics});

  final VoidCallback onOpenDiagnostics;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: shopInk,
    appBar: AppBar(
      backgroundColor: shopIndigo,
      foregroundColor: shopPaper,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(4),
        child: BackButton(
          style: shopPlaqueStyle(
            secondary: true,
          ).copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.zero)),
        ),
      ),
      title: const Text('設定'),
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('open-device-lab'),
                style: shopPlaqueStyle(secondary: true),
                onPressed: onOpenDiagnostics,
                icon: const Icon(Icons.chevron_right),
                iconAlignment: IconAlignment.end,
                label: const Text('端末の計測'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
