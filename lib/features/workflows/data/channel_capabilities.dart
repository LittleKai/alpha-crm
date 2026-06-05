import 'workflow_models.dart';

class ChannelCapability {
  final CrmChannel channel;
  final bool supportsTextMessage;
  final bool supportsMediaMessage;
  final bool supportsOfficialWebhook;
  final bool supportsFriendAutomation;
  final bool supportsGroupAutomation;
  final bool supportsTypingIndicator;
  final bool supportsSeenControl;

  const ChannelCapability({
    required this.channel,
    required this.supportsTextMessage,
    required this.supportsMediaMessage,
    required this.supportsOfficialWebhook,
    required this.supportsFriendAutomation,
    required this.supportsGroupAutomation,
    required this.supportsTypingIndicator,
    required this.supportsSeenControl,
  });
}

const Map<CrmChannel, ChannelCapability> channelCapabilities = {
  CrmChannel.zaloPersonal: ChannelCapability(
    channel: CrmChannel.zaloPersonal,
    supportsTextMessage: true,
    supportsMediaMessage: true,
    supportsOfficialWebhook: false,
    supportsFriendAutomation: true,
    supportsGroupAutomation: true,
    supportsTypingIndicator: true,
    supportsSeenControl: true,
  ),
  CrmChannel.zaloOa: ChannelCapability(
    channel: CrmChannel.zaloOa,
    supportsTextMessage: true,
    supportsMediaMessage: false,
    supportsOfficialWebhook: true,
    supportsFriendAutomation: false,
    supportsGroupAutomation: false,
    supportsTypingIndicator: false,
    supportsSeenControl: false,
  ),
  CrmChannel.facebookPage: ChannelCapability(
    channel: CrmChannel.facebookPage,
    supportsTextMessage: true,
    supportsMediaMessage: true,
    supportsOfficialWebhook: true,
    supportsFriendAutomation: false,
    supportsGroupAutomation: false,
    supportsTypingIndicator: true,
    supportsSeenControl: true,
  ),
};
