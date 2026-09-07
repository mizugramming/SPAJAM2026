import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/participant.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/room_provider.dart';

class ResultScreen extends StatelessWidget {
  static const routeName = '/result';

  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>().room;
    final conversation = context.watch<ConversationProvider>();

    if (room == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('会輪おつかれさまでした')),
      body: SafeArea(
        child: PageView(
          controller: PageController(viewportFraction: 0.86),
          children: [
            for (final participant in room.participants)
              _ProfileCard(
                participant: participant,
                usedTopics: conversation.history
                    .where((record) => record.selectorId == participant.id)
                    .map((record) => conversation.topics.firstWhere((t) => t.id == record.topicId).text)
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.participant, required this.usedTopics});

  final Participant participant;
  final List<String> usedTopics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(38), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: ListView(
          children: [
            Text(
              participant.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(participant.category.label, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (participant.hobbies.isNotEmpty) ...[
              const Text('趣味', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final hobby in participant.hobbies) Chip(label: Text(hobby))],
              ),
              const SizedBox(height: 20),
            ],
            const Text('持ち込んだネタ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(participant.submittedTopic.isEmpty ? 'なし' : participant.submittedTopic),
            const SizedBox(height: 20),
            const Text('今日出てきたネタ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (usedTopics.isEmpty)
              const Text('なし')
            else
              for (final topic in usedTopics) Text('・$topic'),
          ],
        ),
      ),
    );
  }
}
