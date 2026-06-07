import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/fitness_models.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../state/chat_controller.dart';
import '../state/fitness_controller.dart';

/// The in-app coach chat surface. One continuous conversation rendered with
/// day-divider headers, polled live from the broker while open. Reached from
/// the shared app-bar chat icon (every tab, incl. mid-workout) and the Coach
/// tab entry card.
///
/// Coach replies are read aloud on-device (TTS) when the voice toggle is on:
/// only freshly-arrived replies speak — never the backlog on open.
class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.controller, super.key});

  final FitnessController controller;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController _chat;
  final TtsService _tts = TtsService();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  late bool _voiceEnabled;
  int _lastSpokenSeq = 0;
  bool _voicePrimed = false;
  String _langTag = 'en-US';

  final SttService _stt = SttService();
  bool _listening = false;
  String _dictationBase = '';
  String _sttLocale = 'en_US';

  @override
  void initState() {
    super.initState();
    _voiceEnabled = widget.controller.chatVoiceEnabled;
    _chat = ChatController(configProvider: () => widget.controller.bridgeConfig)
      ..addListener(_onChatChanged)
      ..start();
    _stt.onListeningChanged = (listening) {
      if (mounted) setState(() => _listening = listening);
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final code = Localizations.localeOf(context).languageCode;
    _langTag = code == 'de' ? 'de-DE' : 'en-US';
    _sttLocale = code == 'de' ? 'de_DE' : 'en_US';
  }

  void _onChatChanged() {
    // A reversed list keeps the newest turn pinned to the bottom, so there's
    // no manual scrolling to do here — just voice newly-arrived replies.
    _maybeSpeakNewReply(_chat.messages);
  }

  /// Speaks the latest reply only if it arrived *after* the chat opened. On the
  /// first settled load we seed the cursor from the backlog (no speech), so
  /// reopening a conversation never reads history aloud.
  void _maybeSpeakNewReply(List<ChatMessage> messages) {
    if (!_chat.initialLoadDone) return;
    if (!_voicePrimed) {
      _lastSpokenSeq = _maxAssistantSeq(messages);
      _voicePrimed = true;
      return;
    }
    if (!_voiceEnabled) return;
    final next = newestUnspokenAssistantMessage(messages, _lastSpokenSeq);
    if (next != null) {
      _lastSpokenSeq = next.seq;
      unawaited(_tts.speak(next.content, languageTag: _langTag));
    }
  }

  int _maxAssistantSeq(List<ChatMessage> messages) {
    var max = 0;
    for (final message in messages) {
      if (message.isAssistant && message.seq > max) max = message.seq;
    }
    return max;
  }

  void _handleSend() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    unawaited(_stt.stop());
    unawaited(_tts.stop());
    unawaited(_chat.send(text));
  }

  void _toggleDictation() {
    if (_listening) {
      unawaited(_stt.stop());
      return;
    }
    _dictationBase = _input.text;
    // Capture context-derived values before the async gap (lint-safe).
    final messenger = ScaffoldMessenger.of(context);
    final unavailable = AppLocalizations.of(context)!.sttUnavailable;
    unawaited(() async {
      final started = await _stt.start(
        localeId: _sttLocale,
        onResult: _onSpeechResult,
      );
      if (!started) {
        messenger.showSnackBar(SnackBar(content: Text(unavailable)));
      }
    }());
  }

  void _onSpeechResult(String text, bool isFinal) {
    final combined = mergeDictation(_dictationBase, text);
    _input.value = TextEditingValue(
      text: combined,
      selection: TextSelection.collapsed(offset: combined.length),
    );
  }

  void _toggleVoice() {
    final enabled = !_voiceEnabled;
    setState(() => _voiceEnabled = enabled);
    unawaited(widget.controller.setChatVoiceEnabled(enabled));
    if (enabled) {
      // Don't blurt the last existing reply — only future ones speak.
      _lastSpokenSeq = _maxAssistantSeq(_chat.messages);
    } else {
      unawaited(_tts.stop());
    }
  }

  void _speakMessage(ChatMessage message) {
    unawaited(_tts.speak(message.content, languageTag: _langTag));
  }

  @override
  void dispose() {
    _chat.removeListener(_onChatChanged);
    _chat.dispose();
    unawaited(_stt.stop());
    unawaited(_tts.dispose());
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          l.chatTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: l.chatVoiceTooltip,
            onPressed: _toggleVoice,
            icon: Icon(
              _voiceEnabled
                  ? CupertinoIcons.speaker_2_fill
                  : CupertinoIcons.speaker_slash_fill,
              color: _voiceEnabled ? AppColors.sage : null,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: _chat,
                builder: (context, _) {
                  if (!_chat.isConfigured) {
                    return _ChatNotice(
                      icon: CupertinoIcons.wifi_slash,
                      title: l.chatNotConnectedTitle,
                      body: l.chatNotConnectedBody,
                    );
                  }
                  return _buildConversation(context, l);
                },
              ),
            ),
            ListenableBuilder(
              listenable: _chat,
              builder: (context, _) => _chat.isConfigured
                  ? _ChatComposer(
                      controller: _input,
                      onSend: _handleSend,
                      onMic: _toggleDictation,
                      listening: _listening,
                      micTooltip: l.chatMicTooltip,
                      hint: _listening ? l.chatListening : l.chatInputHint,
                      sendTooltip: l.chatSend,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation(BuildContext context, AppLocalizations l) {
    final messages = _chat.messages;
    final outbox = _chat.outbox;
    if (messages.isEmpty && outbox.isEmpty) {
      if (!_chat.initialLoadDone) {
        return const Center(child: CircularProgressIndicator());
      }
      return _ChatNotice(
        icon: CupertinoIcons.chat_bubble_2,
        title: l.chatEmptyTitle,
        body: l.chatEmptyBody,
      );
    }
    final items = <Widget>[];
    for (final group in groupChatMessagesByDay(messages)) {
      items.add(_DayDivider(label: _dayLabel(context, l, group.day)));
      for (final message in group.messages) {
        items.add(
          _MessageBubble(
            message: message,
            speakTooltip: l.chatSpeak,
            onSpeak: message.isAssistant ? () => _speakMessage(message) : null,
          ),
        );
      }
    }
    for (final out in outbox) {
      items.add(
        _OutgoingBubble(
          outgoing: out,
          retryLabel: l.chatFailedRetry,
          onRetry: () => unawaited(_chat.retry(out.localId)),
        ),
      );
    }
    if (_chat.awaitingReply) {
      items.add(const _TypingBubble());
    }
    // Reversed list: index 0 sits at the bottom, so the chat opens pinned to
    // the newest turn and new arrivals appear at the bottom — no extent
    // estimation, no post-layout jump to race. Feed items reversed so the
    // on-screen order stays oldest-top → newest-bottom (dividers included).
    return ListView(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      children: items.reversed.toList(),
    );
  }

  String _dayLabel(BuildContext context, AppLocalizations l, DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return l.chatToday;
    if (diff == 1) return l.chatYesterday;
    return MaterialLocalizations.of(context).formatMediumDate(day);
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.speakTooltip,
    this.onSpeak,
  });

  final ChatMessage message;
  final String speakTooltip;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      decoration: BoxDecoration(
        color: isUser
            ? AppColors.sage.withValues(alpha: 0.22)
            : AppColors.surface2,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
        border: Border.all(color: AppColors.paper.withValues(alpha: 0.06)),
      ),
      child: Text(
        message.content,
        style: TextStyle(
          fontSize: AppType.callout,
          height: 1.3,
          color: AppColors.paper.withValues(alpha: 0.92),
        ),
      ),
    );

    if (onSpeak == null) {
      return Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: bubble,
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bubble,
          Tooltip(
            message: speakTooltip,
            child: GestureDetector(
              onTap: onSpeak,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 6, top: 2, bottom: 2),
                child: Icon(
                  CupertinoIcons.speaker_2,
                  size: 13,
                  color: AppColors.paper.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutgoingBubble extends StatelessWidget {
  const _OutgoingBubble({
    required this.outgoing,
    required this.retryLabel,
    required this.onRetry,
  });

  final ChatOutgoing outgoing;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            decoration: BoxDecoration(
              color: AppColors.sage.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
              border: Border.all(
                color: AppColors.paper.withValues(alpha: 0.05),
              ),
            ),
            child: Text(
              outgoing.text,
              style: TextStyle(
                fontSize: AppType.callout,
                height: 1.3,
                color: AppColors.paper.withValues(alpha: 0.6),
              ),
            ),
          ),
          if (outgoing.failed)
            GestureDetector(
              onTap: onRetry,
              child: Padding(
                padding: const EdgeInsets.only(top: 3, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.exclamationmark_circle,
                      size: 12,
                      color: AppColors.coral,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      retryLabel,
                      style: const TextStyle(
                        fontSize: AppType.caption,
                        color: AppColors.coral,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 4),
              child: Text(
                '· · ·',
                style: TextStyle(
                  fontSize: AppType.caption,
                  color: AppColors.paper.withValues(alpha: 0.3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Animated three-dot "coach is typing" indicator on the assistant side.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: AppColors.paper.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final phase = (_pulse.value + i * 0.2) % 1.0;
                  final opacity =
                      0.3 + 0.5 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.sage,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: AppColors.paper.withValues(alpha: 0.08)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.paper.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Divider(color: AppColors.paper.withValues(alpha: 0.08)),
          ),
        ],
      ),
    );
  }
}

class _ChatNotice extends StatelessWidget {
  const _ChatNotice({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.sage.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppType.title,
                fontWeight: FontWeight.w800,
                color: AppColors.paper,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppType.body,
                height: 1.4,
                color: AppColors.paper.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.onSend,
    required this.onMic,
    required this.listening,
    required this.micTooltip,
    required this.hint,
    required this.sendTooltip,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onMic;
  final bool listening;
  final String micTooltip;
  final String hint;
  final String sendTooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.paper.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: micTooltip,
            onPressed: onMic,
            icon: Icon(
              listening ? CupertinoIcons.mic_fill : CupertinoIcons.mic,
              color: listening
                  ? AppColors.coral
                  : AppColors.paper.withValues(alpha: 0.7),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(
                fontSize: AppType.callout,
                color: AppColors.paper,
              ),
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                filled: true,
                fillColor: AppColors.surface2,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: sendTooltip,
            onPressed: onSend,
            icon: const Icon(CupertinoIcons.arrow_up, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.sage,
              foregroundColor: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
