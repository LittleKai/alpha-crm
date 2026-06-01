import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

/// Thông tin một bản release từ GitHub.
class AppReleaseInfo {
  final String tagName;
  final String version;
  final String name;
  final String body;
  final String htmlUrl;
  final DateTime publishedAt;
  final List<ReleaseAsset> assets;

  const AppReleaseInfo({
    required this.tagName,
    required this.version,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.assets,
  });

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String? ?? '';
    final assetsList = (json['assets'] as List<dynamic>?)
            ?.map((a) => ReleaseAsset.fromJson(a as Map<String, dynamic>))
            .toList() ??
        [];

    return AppReleaseInfo(
      tagName: tag,
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      name: json['name'] as String? ?? tag,
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ??
          DateTime.now(),
      assets: assetsList,
    );
  }

  /// Tìm asset phù hợp cho nền tảng hiện tại.
  ReleaseAsset? getAssetForCurrentPlatform() {
    if (Platform.isWindows) {
      // Ưu tiên .exe, sau đó .msix, cuối cùng .zip
      return _findAsset(['.exe', '.msix', '.zip']);
    } else if (Platform.isAndroid) {
      return _findAsset(['.apk']);
    }
    return null;
  }

  ReleaseAsset? _findAsset(List<String> extensions) {
    for (final ext in extensions) {
      final match = assets.where(
        (a) => a.name.toLowerCase().endsWith(ext),
      );
      if (match.isNotEmpty) return match.first;
    }
    return null;
  }
}

class ReleaseAsset {
  final String name;
  final String browserDownloadUrl;
  final int size;

  const ReleaseAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.size,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name'] as String? ?? '',
      browserDownloadUrl: json['browser_download_url'] as String? ?? '',
      size: json['size'] as int? ?? 0,
    );
  }

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Service kiểm tra và tải bản cập nhật từ GitHub Releases.
class AppUpdateService {
  static const String _owner = 'LittleKai';
  static const String _repo = 'alpha-crm-app';
  static const String _apiBase = 'https://api.github.com';

  /// Lấy thông tin bản release mới nhất từ GitHub.
  static Future<AppReleaseInfo?> getLatestRelease() async {
    try {
      final url = Uri.parse('$_apiBase/repos/$_owner/$_repo/releases/latest');
      final response = await http.get(url, headers: {
        'Accept': 'application/vnd.github.v3+json',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return AppReleaseInfo.fromJson(json);
      }

      // Nếu chưa có release nào (404), thử lấy từ danh sách releases
      if (response.statusCode == 404) {
        return await _getLatestFromList();
      }

      print('[AppUpdateService] GitHub API returned ${response.statusCode}');
      return null;
    } catch (e) {
      print('[AppUpdateService] Error checking for updates: $e');
      return null;
    }
  }

  /// Fallback: lấy release đầu tiên từ danh sách.
  static Future<AppReleaseInfo?> _getLatestFromList() async {
    try {
      final url = Uri.parse(
        '$_apiBase/repos/$_owner/$_repo/releases?per_page=1',
      );
      final response = await http.get(url, headers: {
        'Accept': 'application/vnd.github.v3+json',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        if (list.isNotEmpty) {
          return AppReleaseInfo.fromJson(list.first as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      print('[AppUpdateService] Error fetching release list: $e');
      return null;
    }
  }

  /// Lấy phiên bản hiện tại của ứng dụng.
  static Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      print('[AppUpdateService] Error getting current version: $e');
      return '0.0.0';
    }
  }

  /// So sánh 2 chuỗi version theo semver (major.minor.patch).
  /// Trả về true nếu [remote] > [current].
  static bool isNewerVersion(String remote, String current) {
    final remoteParts = _parseVersion(remote);
    final currentParts = _parseVersion(current);

    for (int i = 0; i < 3; i++) {
      if (remoteParts[i] > currentParts[i]) return true;
      if (remoteParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  static List<int> _parseVersion(String version) {
    final cleaned = version.startsWith('v') ? version.substring(1) : version;
    final parts = cleaned.split('.');
    return [
      int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0,
      int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      int.tryParse(parts.length > 2 ? parts[2] : '0') ?? 0,
    ];
  }

  /// Tải file cập nhật về thư mục tạm.
  /// [onProgress] callback trả về tiến trình 0.0 - 1.0.
  static Future<String?> downloadAsset(
    ReleaseAsset asset, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}${Platform.pathSeparator}${asset.name}';
      final file = File(filePath);

      // Nếu file đã tồn tại và cùng kích thước, bỏ qua tải lại
      if (await file.exists() && await file.length() == asset.size) {
        onProgress?.call(1.0);
        return filePath;
      }

      final request = http.Request('GET', Uri.parse(asset.browserDownloadUrl));
      final streamedResponse = await request.send().timeout(
            const Duration(minutes: 10),
          );

      if (streamedResponse.statusCode != 200) {
        print(
          '[AppUpdateService] Download failed: ${streamedResponse.statusCode}',
        );
        return null;
      }

      final totalBytes = streamedResponse.contentLength ?? asset.size;
      int receivedBytes = 0;
      final sink = file.openWrite();

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress?.call(receivedBytes / totalBytes);
        }
      }

      await sink.close();
      return filePath;
    } catch (e) {
      print('[AppUpdateService] Download error: $e');
      return null;
    }
  }

  /// Cài đặt bản cập nhật đã tải.
  /// - Windows: mở file .exe / .msix bằng shell
  /// - Android: mở file .apk bằng intent
  static Future<bool> installUpdate(String filePath) async {
    try {
      if (Platform.isWindows) {
        // Mở file .exe hoặc .msix trực tiếp
        await Process.start(filePath, [], mode: ProcessStartMode.detached);
        return true;
      } else if (Platform.isAndroid) {
        final result = await OpenFilex.open(filePath);
        return result.type == ResultType.done;
      }
      return false;
    } catch (e) {
      print('[AppUpdateService] Install error: $e');
      return false;
    }
  }

  /// Mở trang releases trên trình duyệt.
  static Future<void> openReleasePage() async {
    final url = Uri.parse('https://github.com/$_owner/$_repo/releases');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Mở URL của một release cụ thể trên trình duyệt.
  static Future<void> openReleaseUrl(String htmlUrl) async {
    final url = Uri.parse(htmlUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
