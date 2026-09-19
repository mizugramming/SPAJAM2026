import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_routes.dart';
import '../constants/design_tokens.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.message = 'ここに、あなたの星が生まれます。',
    this.showAction = true,
  });
  final String message;
  final bool showAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            size: 32,
            color: DesignTokens.gold,
          ),
          const SizedBox(height: 18),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            '言葉になるときも、ならないときも。',
            style: TextStyle(color: DesignTokens.muted, fontSize: 12),
          ),
          if (showAction) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => context.push(AppRoutes.space),
              child: const Text('SPACEをはじめる'),
            ),
          ],
        ],
      ),
    ),
  );
}
