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

  // Detect extension if missing
  var finalFileName = fileName;
  final hasExtension = RegExp(r'\.[a-zA-Z0-9]+$').hasMatch(fileName);
  if (!hasExtension) {
    String? ext;
    // 1. Content-Disposition filename extension
    final contentDisposition = response.headers['content-disposition'] ?? response.headers['Content-Disposition'];
    if (contentDisposition != null) {
      final match = RegExp(r'filename="?([^"]+)"?').firstMatch(contentDisposition);
      if (match != null) {
        final dispName = match.group(1);
        if (dispName != null) {
          final dotIdx = dispName.lastIndexOf('.');
          if (dotIdx != -1) {
            ext = dispName.substring(dotIdx);
          }
        }
      }
    }
    // 2. Content-Type map
    if (ext == null) {
      final contentType = (response.headers['content-type'] ?? response.headers['Content-Type'] ?? '').split(';').first.trim().toLowerCase();
      const contentTypeToExt = {
        'image/jpeg': '.jpg',
        'image/jpg': '.jpg',
        'image/png': '.png',
        'image/gif': '.gif',
        'image/webp': '.webp',
        'video/mp4': '.mp4',
        'video/quicktime': '.mov',
        'audio/mpeg': '.mp3',
        'audio/mp3': '.mp3',
        'audio/wav': '.wav',
        'audio/ogg': '.ogg',
        'audio/m4a': '.m4a',
        'application/pdf': '.pdf',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document': '.docx',
        'application/msword': '.doc',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': '.xlsx',
        'application/vnd.ms-excel': '.xls',
        'application/zip': '.zip',
        'application/x-zip-compressed': '.zip',
      };
      ext = contentTypeToExt[contentType];
    }
    // 3. URL path segment
    if (ext == null) {
      try {
        final pathSegment = Uri.parse(url).pathSegments.lastOrNull;
        if (pathSegment != null) {
          final dotIdx = pathSegment.lastIndexOf('.');
          if (dotIdx != -1) {
            ext = pathSegment.substring(dotIdx);
          }
        }
      } catch (_) {}
    }
    if (ext != null && ext.isNotEmpty) {
      finalFileName = '$fileName$ext';
    }
  }

  await targetDirectory.create(recursive: true);

  final safeName = finalFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final file = File(
    '${targetDirectory.path}${Platform.pathSeparator}$safeName',
  );
  await file.writeAsBytes(response.bodyBytes, flush: true);
  return file.path;
}
