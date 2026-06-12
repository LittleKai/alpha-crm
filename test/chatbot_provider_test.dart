import 'package:alpha_crm/features/messaging/chatbot/data/chatbot_repository.dart';
import 'package:alpha_crm/features/messaging/chatbot/providers/chatbot_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeChatbotRepository extends ChatbotRepository {
  int createRuleCalls = 0;
  Map<String, dynamic>? savedSettings;

  @override
  Future<Map<String, dynamic>> getSettings() async => {
    'success': true,
    'data': <String, dynamic>{'debounceSeconds': 8},
  };

  @override
  Future<Map<String, dynamic>> getRules() async => {
    'success': true,
    'data': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> getLogs() async => {
    'success': true,
    'data': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> createRule({
    required String name,
    String? description,
    required String keyword,
    required String response,
  }) async {
    createRuleCalls += 1;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return {
      'success': true,
      'data': {
        '_id': 'rule-1',
        'keywords': [keyword],
        'response': response,
        'isActive': true,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> saveSettings(
    Map<String, dynamic> payload,
  ) async {
    savedSettings = payload;
    return {'success': true, 'data': payload};
  }
}

void main() {
  test('normalizeChatbotAiModel accepts supported chatbot models', () {
    expect(
      normalizeChatbotAiModel('gemini-3-flash-preview'),
      'gemini-3-flash-preview',
    );
    expect(normalizeChatbotAiModel('gemini-2.5-pro'), 'gemini-2.5-pro');
    expect(
      normalizeChatbotAiModel('gemini-3.1-pro-preview'),
      'gemini-3.1-pro-preview',
    );
    expect(normalizeChatbotAiModel('gcli-default'), chatbotDefaultAiModel);
  });

  test(
    'addRule ignores duplicate create requests while one is pending',
    () async {
      final repository = _FakeChatbotRepository();
      final notifier = ChatbotNotifier(repository);
      await Future<void>.delayed(Duration.zero);

      await Future.wait([
        notifier.addRule('bao hanh', 'Bao hanh 30 ngay.'),
        notifier.addRule('bao hanh', 'Bao hanh 30 ngay.'),
      ]);

      expect(repository.createRuleCalls, 1);
    },
  );

  test('loads and saves chatbot debounce duration', () async {
    final repository = _FakeChatbotRepository();
    final notifier = ChatbotNotifier(repository);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.debounceSeconds, 8);

    await notifier.updateAiConfig(
      model: chatbotDefaultAiModel,
      prompt: chatbotDefaultSystemPrompt,
      soulPrompt: chatbotDefaultSoul,
      responseRules: chatbotDefaultResponseRules,
      temperature: 0.7,
      debounceSeconds: 6,
    );

    expect(notifier.state.debounceSeconds, 6);
    expect(repository.savedSettings?['debounceSeconds'], 6);
  });
}
