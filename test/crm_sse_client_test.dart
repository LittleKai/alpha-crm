import 'package:alpha_crm/shared/api/crm_sse_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes a single-line data frame terminated by a blank line', () {
    final decoder = CrmSseDecoder();
    expect(decoder.addLine('event: hello'), isNull);
    expect(decoder.addLine('id: 1'), isNull);
    expect(decoder.addLine('data: {"serverTime":"2026-07-02T00:00:00.000Z"}'), isNull);
    final event = decoder.addLine('');

    expect(event, isNotNull);
    expect(event!.name, 'hello');
    expect(event.id, '1');
    expect(event.data['serverTime'], '2026-07-02T00:00:00.000Z');
  });

  test('joins multi-line data payloads with a newline before decoding', () {
    // The joining newline must land where JSON allows whitespace (never
    // inside a string literal, which would make raw JSON invalid) — this
    // matches how a real multi-line `data:` payload is legally split.
    final decoder = CrmSseDecoder();
    decoder.addLine('event: message.new');
    decoder.addLine('data: {"message":');
    decoder.addLine('data: {"content":"hello"}}');
    final event = decoder.addLine('');

    expect(event, isNotNull);
    expect(event!.data['message']['content'], 'hello');
  });

  test('ignores keep-alive comment lines without terminating the frame', () {
    final decoder = CrmSseDecoder();
    decoder.addLine('event: device.status');
    decoder.addLine('data: {"deviceId":"dev-1"}');
    expect(decoder.addLine(': ping'), isNull);
    final event = decoder.addLine('');

    expect(event, isNotNull);
    expect(event!.data['deviceId'], 'dev-1');
  });

  test('a bare comment line with no pending frame produces no event', () {
    final decoder = CrmSseDecoder();
    expect(decoder.addLine(': ping'), isNull);
    expect(decoder.addLine(''), isNull);
  });

  test('defaults the event name to "message" when omitted', () {
    final decoder = CrmSseDecoder();
    decoder.addLine('data: {"a":1}');
    final event = decoder.addLine('');

    expect(event!.name, 'message');
  });

  test('drops a frame with malformed JSON instead of throwing', () {
    final decoder = CrmSseDecoder();
    decoder.addLine('event: message.status');
    decoder.addLine('data: {not valid json');
    final event = decoder.addLine('');

    expect(event, isNull);
  });

  test('resets state between frames so a later valid frame still decodes', () {
    final decoder = CrmSseDecoder();
    decoder.addLine('data: {not valid json');
    decoder.addLine('');
    decoder.addLine('event: conversation.updated');
    decoder.addLine('data: {"accountId":"acc-1"}');
    final event = decoder.addLine('');

    expect(event, isNotNull);
    expect(event!.name, 'conversation.updated');
    expect(event.data['accountId'], 'acc-1');
  });
}
