import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/fitness_models.dart';
import '../services/local_bridge_service.dart';
import '../util/app_log.dart';

/// A locally-composed message the athlete just sent, awaiting server
/// confirmation. Rendered as an optimistic bubble until the broker echoes it
/// back (then it is dropped in favour of the confirmed [ChatMessage]).
class ChatOutgoing {
  const ChatOutgoing(this.localId, this.text, {this.failed = false});

  final int localId;
  final String text;
  final bool failed;
}

/// A day's worth of chat messages, used to render date-divider headers across
/// one continuous conversation. Pure data so it stays unit-testable.
class ChatDayGroup {
  const ChatDayGroup(this.day, this.messages);

  /// Local calendar date at midnight.
  final DateTime day;
  final List<ChatMessage> messages;
}

/// Groups [messages] (assumed ascending by seq == chronological) into per-day
/// buckets keyed by their **local** calendar date. Empty in → empty out.
List<ChatDayGroup> groupChatMessagesByDay(List<ChatMessage> messages) {
  final groups = <ChatDayGroup>[];
  DateTime? currentDay;
  var bucket = <ChatMessage>[];
  for (final message in messages) {
    final local = message.createdAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (currentDay != null && day != currentDay) {
      groups.add(ChatDayGroup(currentDay, bucket));
      bucket = <ChatMessage>[];
    }
    currentDay = day;
    bucket.add(message);
  }
  if (currentDay != null && bucket.isNotEmpty) {
    groups.add(ChatDayGroup(currentDay, bucket));
  }
  return groups;
}

/// The newest assistant turn in [messages] whose seq is greater than
/// [lastSpokenSeq], or null if the latest reply has already been voiced (or
/// there is none). Lets the UI speak only freshly-arrived replies and never
/// re-read the backlog on open. Pure, so it stays unit-testable.
ChatMessage? newestUnspokenAssistantMessage(
  List<ChatMessage> messages,
  int lastSpokenSeq,
) {
  ChatMessage? newest;
  for (final message in messages) {
    if (message.isAssistant && message.seq > lastSpokenSeq) {
      if (newest == null || message.seq > newest.seq) newest = message;
    }
  }
  return newest;
}

/// Combines text already in the composer with a live dictation [recognized]
/// transcript: appends after a separating space when there is existing text,
/// otherwise returns the transcript alone. Pure, so it stays unit-testable.
String mergeDictation(String base, String recognized) {
  final trimmedBase = base.trimRight();
  if (trimmedBase.isEmpty) return recognized;
  if (recognized.isEmpty) return trimmedBase;
  return '$trimmedBase $recognized';
}

/// Drives the in-app coach chat: holds the conversation, polls the broker for
/// new turns, and sends the athlete's messages with optimistic echo. One
/// continuous channel (the broker's `default` conversation); the UI layers
/// day dividers on top via [groupChatMessagesByDay].
///
/// Lifecycle is scoped to the open chat surface — [start] on open, [dispose]
/// on close — so polling only runs while the athlete is actually chatting.
class ChatController extends ChangeNotifier {
  ChatController({
    required LocalBridgeConfig Function() configProvider,
    LocalBridgeService? service,
    Duration pollInterval = const Duration(seconds: 2),
  }) : _configProvider = configProvider,
       _service = service ?? LocalBridgeService(),
       _pollInterval = pollInterval;

  final LocalBridgeConfig Function() _configProvider;
  final LocalBridgeService _service;
  final Duration _pollInterval;

  final Map<int, ChatMessage> _bySeq = <int, ChatMessage>{};
  final List<ChatOutgoing> _outbox = <ChatOutgoing>[];
  int _cursor = 0;
  int _localIdSeed = 0;
  bool _initialLoadDone = false;
  bool _polling = false;
  bool _disposed = false;
  Timer? _poller;

  bool get isConfigured => _configProvider().isConfigured;
  bool get initialLoadDone => _initialLoadDone;

  /// Confirmed messages, ascending by seq (chronological).
  List<ChatMessage> get messages {
    final list = _bySeq.values.toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    return list;
  }

  /// Optimistic, not-yet-confirmed outgoing messages, in send order.
  List<ChatOutgoing> get outbox => List<ChatOutgoing>.unmodifiable(_outbox);

  /// True while we're waiting on the coach: an in-flight optimistic message, or
  /// the newest confirmed turn is the athlete's (no reply has landed yet).
  ///
  /// Deliberately keyed on the newest turn's *role*, NOT on a user turn's
  /// stored `pending` status. That status goes stale: once the poll cursor
  /// passes a turn, the `since`-cursor never re-fetches it, so the app never
  /// sees the broker flip it to `answered` — which left the "typing…" dots
  /// lingering forever after a reply.
  bool get awaitingReply {
    if (_outbox.any((o) => !o.failed)) return true;
    ChatMessage? newest;
    for (final message in _bySeq.values) {
      if (newest == null || message.seq > newest.seq) newest = message;
    }
    return newest != null && newest.isUser;
  }

  /// Begin the initial load and the poll loop. Safe to call once per open.
  void start() {
    if (_disposed) return;
    unawaited(_loadInitial());
    _poller?.cancel();
    _poller = Timer.periodic(_pollInterval, (_) => unawaited(_poll()));
  }

  void stop() {
    _poller?.cancel();
    _poller = null;
  }

  Future<void> refresh() => _poll();

  Future<void> _loadInitial() async {
    await _poll();
    _initialLoadDone = true;
    _safeNotify();
  }

  Future<void> _poll() async {
    if (_polling || _disposed) return;
    final config = _configProvider();
    if (!config.isConfigured) return;
    _polling = true;
    try {
      final payload = await _service.fetchChatMessages(config, _cursor);
      var changed = false;
      var maxSeq = _cursor;
      final raw = payload['messages'];
      if (raw is List) {
        for (final item in raw.whereType<Map<dynamic, dynamic>>()) {
          final message = ChatMessage.fromJson(item.cast<String, dynamic>());
          _bySeq[message.seq] = message;
          if (message.seq > maxSeq) maxSeq = message.seq;
          if (message.isUser) _confirmOutbox(message.content);
          changed = true;
        }
      }
      final latest = payload['latestSeq'];
      if (latest is int && latest > maxSeq) maxSeq = latest;
      _cursor = maxSeq;
      if (changed) _safeNotify();
    } on Object catch (error, stackTrace) {
      // Transient transport hiccup: keep the conversation intact and retry on
      // the next tick rather than surfacing noise mid-chat.
      AppLog.warn('Chat poll failed', error: error, stackTrace: stackTrace);
    } finally {
      _polling = false;
    }
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final config = _configProvider();
    if (!config.isConfigured) return;
    final localId = _localIdSeed++;
    _outbox.add(ChatOutgoing(localId, trimmed));
    _safeNotify();
    try {
      final payload = await _service.postChatMessage(config, trimmed);
      final message = ChatMessage.fromJson(payload);
      _bySeq[message.seq] = message;
      _removeOutbox(localId);
      // Deliberately do NOT advance _cursor here: the next poll (since=_cursor)
      // re-surfaces this turn (idempotent upsert) AND the assistant reply.
      _safeNotify();
    } on Object catch (error, stackTrace) {
      AppLog.warn('Chat send failed', error: error, stackTrace: stackTrace);
      _markOutboxFailed(localId);
      _safeNotify();
    }
  }

  Future<void> retry(int localId) async {
    final index = _outbox.indexWhere((o) => o.localId == localId);
    if (index < 0) return;
    final text = _outbox[index].text;
    _outbox.removeAt(index);
    _safeNotify();
    await send(text);
  }

  void _confirmOutbox(String content) {
    final index = _outbox.indexWhere((o) => !o.failed && o.text == content);
    if (index >= 0) _outbox.removeAt(index);
  }

  void _removeOutbox(int localId) {
    _outbox.removeWhere((o) => o.localId == localId);
  }

  void _markOutboxFailed(int localId) {
    final index = _outbox.indexWhere((o) => o.localId == localId);
    if (index >= 0) {
      _outbox[index] = ChatOutgoing(localId, _outbox[index].text, failed: true);
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poller?.cancel();
    _poller = null;
    super.dispose();
  }
}
