import 'package:alpha_crm/features/workflows/data/workflow_models.dart';
import 'package:alpha_crm/features/workflows/data/channel_capabilities.dart';
import 'package:alpha_crm/features/workflows/data/workflow_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workflow catalog exposes n8n-ready Zalo and Facebook templates', () {
    expect(workflowTemplateCatalog.length, greaterThanOrEqualTo(6));
    expect(
      workflowTemplateCatalog.any(
        (template) =>
            template.supportedChannels.contains(CrmChannel.zaloPersonal),
      ),
      isTrue,
    );
    expect(
      workflowTemplateCatalog.any(
        (template) =>
            template.supportedChannels.contains(CrmChannel.facebookPage),
      ),
      isTrue,
    );
    expect(
      workflowTemplateCatalog.every(
        (template) => template.n8nWorkflow.isNotEmpty,
      ),
      isTrue,
    );
  });

  test(
    'install request serializes draft workflow with channel and variables',
    () {
      final request = WorkflowTemplateInstallRequest(
        templateId: 'zalo-ai-reply-suggestion',
        channel: CrmChannel.zaloPersonal,
        accountId: 'zalo_1',
        variables: const {'webhookPath': 'alpha-crm/zalo-ai'},
        createInactive: true,
      );

      expect(request.toJson(), {
        'templateId': 'zalo-ai-reply-suggestion',
        'channel': 'zalo_personal',
        'accountId': 'zalo_1',
        'pageId': null,
        'variables': {'webhookPath': 'alpha-crm/zalo-ai'},
        'createInactive': true,
      });
    },
  );

  test('template filtering matches category, channel, and search text', () {
    final filtered = filterWorkflowTemplates(
      workflowTemplateCatalog,
      category: WorkflowTemplateCategory.ai,
      channel: CrmChannel.zaloPersonal,
      searchQuery: 'phan loai',
    );

    expect(filtered, hasLength(1));
    expect(filtered.single.id, 'ai-classify-intent');
  });

  test(
    'channel capabilities block personal-only actions for Facebook Page',
    () {
      final facebook = channelCapabilities[CrmChannel.facebookPage]!;
      final zalo = channelCapabilities[CrmChannel.zaloPersonal]!;

      expect(facebook.supportsOfficialWebhook, isTrue);
      expect(facebook.supportsFriendAutomation, isFalse);
      expect(facebook.supportsGroupAutomation, isFalse);
      expect(zalo.supportsFriendAutomation, isTrue);
      expect(zalo.supportsGroupAutomation, isTrue);
    },
  );
}
