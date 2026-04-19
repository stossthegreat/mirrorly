import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../models/face_geometry.dart';
import '../../services/archetype_service.dart';
import '../../services/chat_service.dart';
import '../../services/scoring_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class ChatScreen extends StatefulWidget {
  final FaceGeometry geometry;
  const ChatScreen({super.key, required this.geometry});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <ChatMessage>[];
  final _input = TextEditingController();
  final _scrollCtl = ScrollController();
  bool _sending = false;
  late final AestheticScore _score;
  late final ArchetypeMatch _match;

  static const _suggestions = [
    'What haircut should I get?',
    'Skin routine for my face?',
    'Should I grow a beard?',
    'Genioplasty — worth it?',
    'How do I lose midface fat?',
  ];

  @override
  void initState() {
    super.initState();
    _score = ScoringService.compute(widget.geometry);
    _match = ArchetypeService.bestMatch(widget.geometry);
    _messages.add(ChatMessage(ChatRole.assistant, _openingLine()));
  }

  String _openingLine() {
    return 'I\'ve read your measurements. Score ${_score.value} '
        '(${_score.tierLabel}). Closest archetype: ${_match.archetype.name} '
        '(${(_match.match * 100).round()}% match). Strongest: '
        '${_score.strongestAxis.$1}. Pulldown: ${_score.weakestAxis.$1}. '
        'Ask me anything — haircut, beard, skin, gym, surgery. I\'ll answer '
        'against *your* bones, not a generic face.';
  }

  Future<void> _send([String? prefilled]) async {
    final text = (prefilled ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _messages.add(ChatMessage(ChatRole.user, text));
      _sending = true;
      _input.clear();
    });
    _scrollToEnd();
    HapticFeedback.lightImpact();

    final reply = await ChatService.send(
      history:  _messages,
      geometry: widget.geometry,
    );

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(ChatRole.assistant, reply));
      _sending = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtl.hasClients) return;
      _scrollCtl.animateTo(
        _scrollCtl.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtl,
                padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.md),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (c, i) {
                  if (i == _messages.length) return const _TypingIndicator();
                  final m = _messages[i];
                  return _MessageBubble(message: m,
                    isFirst: i == 0 && m.role == ChatRole.assistant);
                },
              ),
            ),
            if (_messages.length <= 2) _suggestionStrip(),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.md),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.pop(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3), width: 0.8),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 14, color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Consultation',
                      style: AppTypography.h1.copyWith(
                        fontSize: 22,
                        letterSpacing: -0.6,
                        height: 1)),
                    const SizedBox(width: 8),
                    Container(
                      width: 4, height: 4, margin: const EdgeInsets.only(top: 6),
                      decoration: const BoxDecoration(
                        color: AppColors.gold, shape: BoxShape.circle),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text('AI AESTHETIC ADVISOR · SEES YOUR BONES',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textMuted, fontSize: 8, letterSpacing: 2.8)),
              ],
            ),
          ),
          _scoreBadge(),
        ],
      ),
    );
  }

  Widget _scoreBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          Text('${_score.value}',
            style: AppTypography.measurement.copyWith(
              color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Text('/ 100',
            style: AppTypography.label.copyWith(
              color: AppColors.textTertiary, fontSize: 8, letterSpacing: 1.4)),
        ],
      ),
    );
  }

  Widget _suggestionStrip() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = _suggestions[i];
          return Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _send(s),
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.28), width: 0.8),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(s,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary, fontSize: 12)),
                ),
              ),
            ),
          );
        },
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _inputBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Sp.md, Sp.sm, Sp.md,
        MediaQuery.of(context).viewInsets.bottom > 0
          ? Sp.sm : Sp.md,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(Sp.md, 4, 4, 4),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.24), width: 0.8),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask about your face…',
                  hintStyle: AppTypography.body.copyWith(
                    color: AppColors.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _sending ? null : () => _send(),
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _sending
                      ? AppColors.surface3
                      : AppColors.gold,
                    shape: BoxShape.circle,
                    boxShadow: _sending ? null : [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        blurRadius: 12),
                    ],
                  ),
                  child: Icon(
                    _sending ? Icons.more_horiz : Icons.arrow_upward_rounded,
                    size: 18,
                    color: _sending ? AppColors.textTertiary : AppColors.base,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isFirst;
  const _MessageBubble({required this.message, this.isFirst = false});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _avatarDot(),
          if (!isUser) const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.accent.withValues(alpha: 0.14) : AppColors.surface1,
                borderRadius: BorderRadius.only(
                  topLeft:  Radius.circular(isUser ? 18 : 6),
                  topRight: Radius.circular(isUser ? 6 : 18),
                  bottomLeft: const Radius.circular(18),
                  bottomRight: const Radius.circular(18),
                ),
                border: Border.all(
                  color: (isUser ? AppColors.accent : AppColors.gold)
                      .withValues(alpha: isFirst ? 0.35 : 0.18),
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isFirst)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('YOUR ANALYSIS',
                        style: AppTypography.label.copyWith(
                          color: AppColors.gold, letterSpacing: 2.4, fontSize: 8)),
                    ),
                  Text(message.content,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 14.5,
                      height: 1.55)),
                ],
              ),
            ).animate().fadeIn(duration: 260.ms).slideY(
              begin: 0.08, end: 0, duration: 260.ms, curve: Curves.easeOut),
          ),
        ],
      ),
    );
  }

  Widget _avatarDot() {
    return Container(
      width: 28, height: 28, margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55), width: 0.8),
      ),
      child: const Center(
        child: Icon(Icons.auto_awesome, size: 13, color: AppColors.gold)),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat();
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 38),
      child: AnimatedBuilder(
        animation: _ac,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              Opacity(
                opacity: _dotOpacity(i, _ac.value),
                child: Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.gold, shape: BoxShape.circle),
                ),
              ),
              if (i < 2) const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }

  double _dotOpacity(int i, double t) {
    final phase = (t - i * 0.15) % 1.0;
    if (phase < 0.5) return 0.3 + phase * 1.4;
    return 1.0 - (phase - 0.5) * 1.4;
  }
}
