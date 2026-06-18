import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

Future<String> downloadLiveChatMedia({
  required String url,
  required String fileName,
  String? directory,
}) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Tải tệp thất bại: HTTP ${response.statusCode}');
  }
  Directory targetDirectory;
  if (directory?.trim().isNotEmpty == true) {
    targetDirectory = Directory(directory!.trim());
  } else {
    final downloadsDir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    targetDirectory = Directory(
      '${downloadsDir.path}${Platform.pathSeparator}AlphaCRM',
    );
  }
  await targetDirectory.create(recursive: true);
  final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final file = File(
    '${targetDirectory.path}${Platform.pathSeparator}$safeName',
  );
  await file.writeAsBytes(response.bodyBytes, flush: true);
  return file.path;
}
