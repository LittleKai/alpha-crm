/// Local-first Live Chat bridge path builders and response helpers.
///
/// These constants and helpers define the contract between the Flutter client
/// and the local Zalo bridge for local-first message storage. They are used
/// only when `SystemSettings.localFirstLiveChat` is true.
library;

// ---------------------------------------------------------------------------
// Local bridge API path builders
// ---------------------------------------------------------------------------

/// Builds the path for fetching messages from a local conversation.
///
/// Supports optional `before`, `after`, and `limit` query parameters for
/// cursor-based pagination.
String localMessagesPath(
  String conversationId, {
  String? before,
  String? after,
  int? limit,
}) {
  final query = <String, String>{};
  if (before != null && before.isNotEmpty) query['before'] = before;
  if (after != null && after.isNotEmpty) query['after'] = after;
  if (limit != null) query['limit'] = limit.toString();
  return Uri(
    path: '/local/conversations/$conversationId/messages',
    queryParameters: query.isNotEmpty ? query : null,
  ).toString();
}

/// Builds the path for sending a text message through the local bridge.
const String localSendMessagePath = '/local/messages/send';

/// Builds the path for sending an attachment through the local bridge.
const String localSendAttachmentPath = '/local/messages/attachments/send';

/// Builds the path for recalling a message through the local bridge.
String localRecallMessagePath(String messageId) =>
    '/local/messages/$messageId/recall';

/// Health-check endpoint for the local bridge.
const String localHealthPath = '/local/health';

// ---------------------------------------------------------------------------
// Response status indicators
// ---------------------------------------------------------------------------

/// Standard success field key in local bridge JSON responses.
const String kResponseSuccessKey = 'success';

/// Standard data field key in local bridge JSON responses.
const String kResponseDataKey = 'data';

/// Checks whether a local bridge response indicates success.
bool isLocalResponseSuccess(Map<String, dynamic> json) {
  return json[kResponseSuccessKey] == true;
}

/// Extracts the data list from a successful local bridge response.
///
/// Returns an empty list if the response has no `data` field or if `data`
/// is not a list.
List<Map<String, dynamic>> extractLocalDataList(Map<String, dynamic> json) {
  final raw = json[kResponseDataKey];
  if (raw is List) {
    return raw.cast<Map<String, dynamic>>();
  }
  return const [];
}

// ---------------------------------------------------------------------------
// Failure indicators
// ---------------------------------------------------------------------------

/// Possible failure reason when the local bridge process is not reachable.
const String kBridgeOffline = 'bridgeOffline';

/// Possible failure reason when local-only mode is not available (e.g. the
/// bridge has no SQLite store yet).
const String kLocalOnlyUnavailable = 'localOnlyUnavailable';

/// Returns `true` if the response JSON contains a known local-bridge failure
/// indicator.
bool isLocalBridgeFailure(Map<String, dynamic> json) {
  final reason = json['reason'];
  return reason == kBridgeOffline || reason == kLocalOnlyUnavailable;
}
