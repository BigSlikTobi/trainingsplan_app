import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trainingsplan_app/src/models/fitness_models.dart';
import 'package:trainingsplan_app/src/services/local_bridge_service.dart';
import 'package:trainingsplan_app/src/state/chat_controller.dart';

const _config = LocalBridgeConfig(baseUrl: 'http://127.0.0.1:8787', token: 'k');

ChatMessage _msg(int seq, String iso) => ChatMessage(
  seq: seq,
  role: 'user',
  content: 'c',
  status: 'answered',
  createdAt: DateTime.parse(iso),
  updatedAt: DateTime.parse(iso),
);

void main() {
  group('ChatMessage', () {
    test('parses the broker wire shape', () {
      final m = ChatMessage.fromJson(<String, dynamic>{
        'seq': 7,
        'conversationId': 'default',
        'role': 'assistant',
        'content': 'Nice run!',
        'status': 'complete',
        'createdAt': '2026-05-30T08:00:00Z',
        'updatedAt': '2026-05-30T08:00:01Z',
      });
      expect(m.seq, 7);
      expect(m.isAssistant, isTrue);
      expect(m.isUser, isFalse);
      expect(m.content, 'Nice run!');
    });

    test('applies defaults and the pending flag', () {
      final m = ChatMessage.fromJson(<String, dynamic>{
        'role': 'user',
        'status': 'pending',
      });
      expect(m.seq, 0);
      expect(m.conversationId, 'default');
      expect(m.isUser, isTrue);
      expect(m.isPending, isTrue);
    });
  });

  group('groupChatMessagesByDay', () {
    test('empty in, empty out', () {
      expect(groupChatMessagesByDay(const <ChatMessage>[]), isEmpty);
    });

    test('same local day collapses into one group', () {
      final groups = groupChatMessagesByDay([
        _msg(1, '2026-05-30T08:00:00'),
        _msg(2, '2026-05-30T20:00:00'),
      ]);
      expect(groups.length, 1);
      expect(groups.single.messages.length, 2);
    });

    test('crossing midnight splits into two ordered groups', () {
      final groups = groupChatMessagesByDay([
        _msg(1, '2026-05-29T23:30:00'),
        _msg(2, '2026-05-30T00:30:00'),
      ]);
      expect(groups.length, 2);
      expect(groups[0].messages.single.seq, 1);
      expect(groups[1].messages.single.seq, 2);
    });
  });

  group('mergeDictation', () {
    test('returns the transcript when the field is empty', () {
      expect(mergeDictation('', 'how was my run'), 'how was my run');
    });

    test('appends to existing text with a separating space', () {
      expect(mergeDictation('note:', 'add more sleep'), 'note: add more sleep');
    });

    test('trims trailing whitespace on the base before joining', () {
      expect(mergeDictation('hello   ', 'world'), 'hello world');
    });

    test('keeps the base when the transcript is empty', () {
      expect(mergeDictation('keep this', ''), 'keep this');
    });
  });

  group('newestUnspokenAssistantMessage', () {
    ChatMessage assistant(int seq) => ChatMessage(
      seq: seq,
      role: 'assistant',
      content: 'r$seq',
      status: 'complete',
      createdAt: DateTime(2026, 5, 30),
      updatedAt: DateTime(2026, 5, 30),
    );
    ChatMessage user(int seq) => ChatMessage(
      seq: seq,
      role: 'user',
      content: 'u$seq',
      status: 'answered',
      createdAt: DateTime(2026, 5, 30),
      updatedAt: DateTime(2026, 5, 30),
    );

    test('returns null when there are no assistant messages', () {
      expect(newestUnspokenAssistantMessage([user(1), user(2)], 0), isNull);
    });

    test('returns the newest assistant turn above the cursor', () {
      final next = newestUnspokenAssistantMessage(
        [user(1), assistant(2), user(3), assistant(4)],
        1,
      );
      expect(next?.seq, 4);
    });

    test('returns null when the latest assistant turn was already spoken', () {
      expect(
        newestUnspokenAssistantMessage([assistant(2), user(3)], 2),
        isNull,
      );
    });

    test('ignores newer user messages', () {
      expect(
        newestUnspokenAssistantMessage([assistant(2), user(5)], 2),
        isNull,
      );
    });
  });

  group('ChatController', () {
    test('send echoes optimistically then confirms from the POST', () async {
      var seq = 0;
      final service = LocalBridgeService(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            seq += 1;
            return http.Response(
              '{"seq":$seq,"conversationId":"default","role":"user",'
              '"content":"hi","status":"pending",'
              '"createdAt":"2026-05-30T08:00:00Z",'
              '"updatedAt":"2026-05-30T08:00:00Z"}',
              200,
            );
          }
          return http.Response('{"messages":[],"latestSeq":0}', 200);
        }),
      );
      final c = ChatController(
        configProvider: () => _config,
        service: service,
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(c.dispose);

      await c.send('hi');

      expect(c.messages.length, 1);
      expect(c.messages.single.content, 'hi');
      expect(c.outbox, isEmpty);
    });

    test('poll ingests the assistant reply and clears awaitingReply', () async {
      var polled = false;
      final service = LocalBridgeService(
        client: MockClient((request) async {
          if (request.method != 'GET') return http.Response('{}', 200);
          if (!polled) {
            polled = true;
            return http.Response(
              '{"messages":[{"seq":1,"role":"user","content":"hi",'
              '"status":"pending","createdAt":"2026-05-30T08:00:00Z",'
              '"updatedAt":"2026-05-30T08:00:00Z"}],"latestSeq":1}',
              200,
            );
          }
          return http.Response(
            '{"messages":[{"seq":1,"role":"user","content":"hi",'
            '"status":"answered","createdAt":"2026-05-30T08:00:00Z",'
            '"updatedAt":"2026-05-30T08:00:02Z"},'
            '{"seq":2,"role":"assistant","content":"Great!",'
            '"status":"complete","createdAt":"2026-05-30T08:00:02Z",'
            '"updatedAt":"2026-05-30T08:00:02Z"}],"latestSeq":2}',
            200,
          );
        }),
      );
      final c = ChatController(
        configProvider: () => _config,
        service: service,
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(c.dispose);

      await c.refresh();
      expect(c.awaitingReply, isTrue);

      await c.refresh();
      expect(c.messages.length, 2);
      expect(c.messages.last.isAssistant, isTrue);
      expect(c.awaitingReply, isFalse);
    });

    test('awaitingReply clears when a reply is newest even if the user turn '
        'stays locally pending (poll-cursor gap)', () async {
      var poll = 0;
      final service = LocalBridgeService(
        client: MockClient((request) async {
          if (request.method != 'GET') return http.Response('{}', 200);
          poll += 1;
          if (poll == 1) {
            return http.Response(
              '{"messages":[{"seq":1,"role":"user","content":"hi",'
              '"status":"pending","createdAt":"2026-05-30T08:00:00Z",'
              '"updatedAt":"2026-05-30T08:00:00Z"}],"latestSeq":1}',
              200,
            );
          }
          // since=1 → broker returns ONLY the new assistant turn; the user
          // turn's flip to 'answered' is never re-fetched.
          return http.Response(
            '{"messages":[{"seq":2,"role":"assistant","content":"yo",'
            '"status":"complete","createdAt":"2026-05-30T08:00:02Z",'
            '"updatedAt":"2026-05-30T08:00:02Z"}],"latestSeq":2}',
            200,
          );
        }),
      );
      final c = ChatController(
        configProvider: () => _config,
        service: service,
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(c.dispose);

      await c.refresh();
      expect(c.awaitingReply, isTrue);

      await c.refresh();
      // Local seq-1 is still 'pending', but the newest turn is the assistant.
      expect(c.messages.firstWhere((m) => m.seq == 1).isPending, isTrue);
      expect(c.awaitingReply, isFalse);
    });

    test('send failure marks the outbox entry failed for retry', () async {
      final service = LocalBridgeService(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response('{"error":"boom"}', 500);
          }
          return http.Response('{"messages":[],"latestSeq":0}', 200);
        }),
      );
      final c = ChatController(
        configProvider: () => _config,
        service: service,
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(c.dispose);

      await c.send('hi');

      expect(c.messages, isEmpty);
      expect(c.outbox.length, 1);
      expect(c.outbox.single.failed, isTrue);
    });

    test('does nothing when no server is configured', () async {
      final c = ChatController(
        configProvider: LocalBridgeConfig.new,
        service: LocalBridgeService(
          client: MockClient((r) async => http.Response('{}', 200)),
        ),
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(c.dispose);

      await c.send('hi');

      expect(c.outbox, isEmpty);
      expect(c.messages, isEmpty);
    });
  });
}
