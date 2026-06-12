import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('video playback uses media_kit with Windows support', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();
    final videoSource = File(
      'lib/features/messaging/live_chat/presentation/screens/'
      'live_chat_video_screen.dart',
    ).readAsStringSync();

    expect(pubspec, contains('media_kit:'));
    expect(pubspec, contains('media_kit_video:'));
    expect(pubspec, contains('media_kit_libs_video:'));
    expect(
      pubspec,
      isNot(contains(RegExp(r'^\s+video_player:', multiLine: true))),
    );
    expect(mainSource, contains('MediaKit.ensureInitialized()'));
    expect(videoSource, contains("package:media_kit/media_kit.dart"));
    expect(
      videoSource,
      contains("package:media_kit_video/media_kit_video.dart"),
    );
  });

  test('new Live Chat user-facing text keeps Vietnamese diacritics', () {
    final files = [
      'lib/features/messaging/live_chat/data/live_chat_download_service_io.dart',
      'lib/features/messaging/live_chat/presentation/screens/live_chat_screen.dart',
      'lib/features/messaging/live_chat/presentation/screens/'
          'live_chat_video_screen.dart',
    ];
    const forbidden = [
      'Da tai',
      'Tai video',
      'Tai tep',
      'that bai',
      'Thu hoi tin nhan',
      'Tha cam xuc',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      for (final text in forbidden) {
        expect(source, isNot(contains(text)), reason: '$path contains "$text"');
      }
    }
  });
}
