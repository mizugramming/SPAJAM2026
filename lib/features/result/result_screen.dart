import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/participant.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/room_provider.dart';
import '../room/room_screen.dart';
import 'widgets/participant_profile_card.dart';
import 'widgets/result_page_indicator.dart';

class ResultScreen extends StatefulWidget {
  static const routeName = '/result';

  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _returnToTitle() {
    context.read<ConversationProvider>().reset();
    context.read<ProfileProvider>().reset();
    context.read<RoomProvider>().reset();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(RoomScreen.routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>().room;
    final conversation = context.watch<ConversationProvider>();

    if (room == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final results = _buildParticipantResults(
      participants: room.participants,
      conversation: conversation,
    );

    if (results.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Expanded(child: Center(child: Text('参加者情報がありません'))),
                _ReturnToTitleButton(onPressed: _returnToTitle),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: results.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final result = results[index];
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      var page = _currentPage.toDouble();
                      if (_pageController.hasClients &&
                          _pageController.position.hasContentDimensions) {
                        page = _pageController.page ?? page;
                      }
                      final distance = (page - index).abs().clamp(0.0, 1.0);
                      final scale = 1 - (distance * 0.05);
                      final verticalOffset = distance * 12;

                      return Transform.translate(
                        offset: Offset(0, verticalOffset),
                        child: Transform.scale(scale: scale, child: child),
                      );
                    },
                    child: ParticipantProfileCard(
                      participant: result.participant,
                      selectedTopics: result.selectedTopics,
                    ),
                  );
                },
              ),
            ),
            ResultPageIndicator(
              currentIndex: _currentPage,
              pageCount: results.length,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _ReturnToTitleButton(onPressed: _returnToTitle),
            ),
          ],
        ),
      ),
    );
  }

  List<_ParticipantResult> _buildParticipantResults({
    required List<Participant> participants,
    required ConversationProvider conversation,
  }) {
    final topicTextById = {
      for (final topic in conversation.topics) topic.id: topic.text,
    };

    return [
      for (final participant in participants)
        _ParticipantResult(
          participant: participant,
          selectedTopics: conversation.history
              .where((record) => record.selectorId == participant.id)
              .map((record) => topicTextById[record.topicId])
              .whereType<String>()
              .toList(),
        ),
    ];
  }
}

class _ParticipantResult {
  const _ParticipantResult({
    required this.participant,
    required this.selectedTopics,
  });

  final Participant participant;
  final List<String> selectedTopics;
}

class _ReturnToTitleButton extends StatelessWidget {
  const _ReturnToTitleButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.home_outlined),
        label: const Text('タイトルへ戻る'),
      ),
    );
  }
}
