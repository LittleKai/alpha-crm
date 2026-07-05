import 'dart:convert';

import 'package:alpha_crm/features/workflows/data/workflow_automation_api.dart';
import 'package:alpha_crm/features/workflows/data/workflow_models.dart';
import 'package:alpha_crm/features/workflows/providers/workflow_automation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('EmailSettingsState round-trips inbox channel settings', () {
    final settings = EmailSettingsState.fromJson({
      'enabled': true,
      'mode': 'inbox',
      'fromName': 'Alpha Care',
      'fromAddress': 'care@example.com',
      'smtpHost': 'smtp.example.com',
      'smtpPort': '2525',
      'smtpSecure': true,
      'smtpUsername': 'care@example.com',
      'smtpPassword': 'smtp-secret',
      'inboundEnabled': true,
      'imapHost': 'imap.example.com',
      'imapPort': 993,
      'imapSecure': false,
      'imapUsername': 'care@example.com',
      'imapPassword': 'imap-secret',
    });

    expect(settings.enabled, isTrue);
    expect(settings.mode, 'inbox');
    expect(settings.smtpPort, 2525);
    expect(settings.imapSecure, isFalse);
    expect(settings.toJson(), {
      'enabled': true,
      'mode': 'inbox',
      'fromName': 'Alpha Care',
      'fromAddress': 'care@example.com',
      'smtpHost': 'smtp.example.com',
      'smtpPort': 2525,
      'smtpSecure': true,
      'smtpUsername': 'care@example.com',
      'smtpPassword': 'smtp-secret',
      'inboundEnabled': true,
      'imapHost': 'imap.example.com',
      'imapPort': 993,
      'imapSecure': false,
      'imapUsername': 'care@example.com',
      'imapPassword': 'imap-secret',
    });
  });

  test('FacebookSettingsState marks enabled pages as configured', () {
    const settings = FacebookSettingsState(
      enabled: true,
      status: 'cloud_required',
      pageName: 'Alpha Page',
      pageId: 'page-1',
      appId: 'app-1',
      webhookCallbackUrl: 'https://alpha.example/webhook/facebook',
      verifyToken: 'verify-secret',
      appSecret: 'app-secret',
      pageAccessToken: 'page-secret',
      enforce24hWindow: false,
    );

    expect(settings.toJson(), {
      'enabled': true,
      'status': 'configured',
      'pageName': 'Alpha Page',
      'pageId': 'page-1',
      'appId': 'app-1',
      'webhookCallbackUrl': 'https://alpha.example/webhook/facebook',
      'verifyToken': 'verify-secret',
      'appSecret': 'app-secret',
      'pageAccessToken': 'page-secret',
      'enforce24hWindow': false,
    });
  });

  test(
    'WorkflowAutomationApi wraps Email settings and per-account Facebook payloads',
    () async {
      final requests = <Map<String, dynamic>>[];
      final api = WorkflowAutomationApi(
        baseUrl: '127.0.0.1:28080/',
        client: MockClient((request) async {
          requests.add({
            'method': request.method,
            'url': request.url.toString(),
            'body': jsonDecode(request.body),
          });
          return http.Response('{"success":true}', 200);
        }),
      );

      final emailResult = await api.saveEmailSettings(
        email: const EmailSettingsState(
          enabled: true,
          mode: 'transactional',
          smtpHost: 'smtp.example.com',
        ).toJson(),
      );
      final facebookResult = await api.saveFacebookAccount(
        const FacebookSettingsState(
          enabled: true,
          pageId: 'page-1',
          pageAccessToken: 'page-secret',
        ).toJson(),
      );

      expect(emailResult['success'], isTrue);
      expect(facebookResult['success'], isTrue);
      expect(requests, hasLength(2));
      expect(requests.first['method'], 'POST');
      expect(
        requests.first['url'],
        'http://127.0.0.1:28080/api/integrations/n8n/settings',
      );
      expect(requests.first['body']['email']['smtpHost'], 'smtp.example.com');
      expect(
        requests.last['url'],
        'http://127.0.0.1:28080/api/integrations/facebook/accounts',
      );
      expect(requests.last['body']['pageId'], 'page-1');
      expect(requests.last['body']['status'], 'configured');
    },
  );

  test(
    'WorkflowAutomationNotifier adds sanitized automation rules locally',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(workflowAutomationProvider.notifier);
      final initialCount = notifier.state.automationRules.length;

      notifier.addAutomationRule(
        name: '  Tag hot lead  ',
        event: '  Message received  ',
        conditionField: '  Content  ',
        conditionOperator: ' contains ',
        conditionValue: '  price  ',
        actions: const [' Add label: hot ', '', ' Create follow-up task '],
      );

      expect(notifier.state.automationRules, hasLength(initialCount + 1));
      final rule = notifier.state.automationRules.first;
      expect(rule.name, 'Tag hot lead');
      expect(rule.event, 'Message received');
      expect(rule.conditionField, 'Content');
      expect(rule.conditionOperator, 'contains');
      expect(rule.conditionValue, 'price');
      expect(rule.actions, ['Add label: hot', 'Create follow-up task']);
      expect(rule.enabled, isTrue);

      notifier.toggleAutomationRule(rule.id, false);
      expect(notifier.state.automationRules.first.enabled, isFalse);

      notifier.deleteAutomationRule(rule.id);
      expect(notifier.state.automationRules, hasLength(initialCount));
    },
  );

  test('WorkflowAutomationState filters templates by omnichannel targets', () {
    final state = const WorkflowAutomationState().copyWith(
      selectedChannel: CrmChannel.facebookPage,
    );

    expect(
      state.filteredTemplates.every(
        (template) => template.supportsChannel(CrmChannel.facebookPage),
      ),
      isTrue,
    );
    expect(
      state.filteredTemplates.any(
        (template) => template.id == 'facebook-new-message-to-crm',
      ),
      isTrue,
    );
  });
}
