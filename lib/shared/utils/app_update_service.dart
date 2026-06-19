import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import 'zalo_backend_manager.dart';

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
    final assetsList =
        (json['assets'] as List<dynamic>?)
            ?.map((a) => ReleaseAsset.fromJson(a as Map<String, dynamic>))
            .toList() ??
        [];

    return AppReleaseInfo(
      tagName: tag,
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      name: json['name'] as String? ?? tag,
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      publishedAt:
          DateTime.tryParse(json['published_at'] as String? ?? '') ??
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
      final match = assets.where((a) => a.name.toLowerCase().endsWith(ext));
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

/// Kết quả kiểm tra sau khi khởi động lại từ một lần cập nhật.
enum PostUpdateOutcome { none, success, failed }

class PostUpdateResult {
  final PostUpdateOutcome outcome;
  final String targetVersion;
  final String currentVersion;

  const PostUpdateResult(
    this.outcome, {
    this.targetVersion = '',
    this.currentVersion = '',
  });
}

/// Service kiểm tra và tải bản cập nhật từ Backblaze B2.
class AppUpdateService {
  static const String _b2VersionUrl =
      'https://cdn.giaiphapsangtao.com/file/alpha-studio/crm-app/version.json';

  /// Lấy thông tin bản release mới nhất từ Backblaze B2.
  static Future<AppReleaseInfo?> getLatestRelease() async {
    try {
      final url = Uri.parse(_b2VersionUrl);
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return AppReleaseInfo.fromJson(json);
      }

      debugPrint('[AppUpdateService] B2 API returned ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking for updates from B2: $e');
      return null;
    }
  }

  /// Lấy phiên bản hiện tại của ứng dụng.
  static Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      debugPrint('[AppUpdateService] Error getting current version: $e');
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
        debugPrint(
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
      debugPrint('[AppUpdateService] Download error: $e');
      return null;
    }
  }

  /// Cài đặt bản cập nhật đã tải.
  /// - Windows: mở file .exe / .msix bằng shell
  /// - Android: mở file .apk bằng intent
  ///
  /// [targetVersion] (Windows zip): phiên bản đích — được ghi vào file mốc trước
  /// khi thoát để lần khởi động sau app tự kiểm tra update đã áp dụng chưa.
  static Future<bool> installUpdate(String filePath, {String? targetVersion}) async {
    try {
      if (Platform.isWindows) {
        if (filePath.toLowerCase().endsWith('.zip')) {
          // ZIP releases are portable bundles, so apply them with a helper
          // script after this running process exits.
          return _installWindowsZipUpdate(filePath, targetVersion);
        } else {
          // Mở file .exe hoặc .msix trực tiếp
          await Process.start(filePath, [], mode: ProcessStartMode.detached);
          return true;
        }
      } else if (Platform.isAndroid) {
        final result = await OpenFilex.open(filePath);
        return result.type == ResultType.done;
      }
      return false;
    } catch (e) {
      debugPrint('[AppUpdateService] Install error: $e');
      return false;
    }
  }

  static Future<bool> _installWindowsZipUpdate(String zipPath, [String? targetVersion]) async {
    final executableFile = File(Platform.resolvedExecutable);
    final appDir = executableFile.parent.path;
    final executableName = executableFile.uri.pathSegments.last;

    // Ghi mốc "đang chờ cập nhật" cạnh exe TRƯỚC khi thoát. Lần khởi động sau,
    // app đọc mốc này để biết update đã áp dụng thành công chưa (xem
    // [checkPostUpdateResult]). Đặt cạnh exe để không phụ thuộc tên exe/ProductName.
    if (targetVersion != null && targetVersion.trim().isNotEmpty) {
      try {
        await File('$appDir${Platform.pathSeparator}.update_pending')
            .writeAsString(targetVersion.trim(), flush: true);
      } catch (e) {
        debugPrint('[AppUpdateService] Could not write update marker: $e');
      }
    }

    final tempDir = await getTemporaryDirectory();
    final updateRoot = Directory(
      '${tempDir.path}${Platform.pathSeparator}alpha_crm_update_${DateTime.now().millisecondsSinceEpoch}',
    );
    await updateRoot.create(recursive: true);

    final stagingDir = '${updateRoot.path}${Platform.pathSeparator}extracted';
    final scriptPath =
        '${updateRoot.path}${Platform.pathSeparator}apply_update.cmd';
    final logPath = '${updateRoot.path}${Platform.pathSeparator}update.log';

    final script = buildWindowsZipUpdaterScript(
      zipPath: zipPath,
      appDir: appDir,
      executableName: executableName,
      stagingDir: stagingDir,
      logPath: logPath,
    );
    await File(scriptPath).writeAsString(script, flush: true);

    ZaloBackendManager.stopBackend();
    // Mở cửa sổ updater có tiêu đề (hiện tiến trình giải nén/copy) — cửa sổ tự
    // đóng khi script kết thúc (cả nhánh thành công lẫn lỗi).
    await Process.start('cmd.exe', [
      '/c',
      'start',
      'Alpha CRM',
      scriptPath,
    ], mode: ProcessStartMode.detached);

    await Future<void>.delayed(const Duration(milliseconds: 500));
    exit(0);
  }

  static String buildWindowsZipUpdaterScript({
    required String zipPath,
    required String appDir,
    required String executableName,
    required String stagingDir,
    required String logPath,
  }) {
    return '''
@echo off
rem Bat UTF-8 de echo tieng Viet co dau hien dung (file .cmd duoc ghi bang UTF-8).
chcp 65001 >nul
setlocal
title Alpha CRM - Đang cập nhật
set "ZIP=$zipPath"
set "APP_DIR=$appDir"
set "EXE=$executableName"
set "STAGE=$stagingDir"
set "LOG=$logPath"

echo ===============================================
echo   Alpha CRM - Đang cập nhật phiên bản mới
echo ===============================================
echo.
echo [%date% %time%] Alpha CRM update started > "%LOG%"
echo Chờ ứng dụng đóng... & timeout /t 3 /nobreak >nul

if exist "%STAGE%" rmdir /s /q "%STAGE%" >> "%LOG%" 2>&1
mkdir "%STAGE%" >> "%LOG%" 2>&1
if %ERRORLEVEL% GEQ 1 goto error

echo Đang giải nén bản cập nhật...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath \$env:ZIP -DestinationPath \$env:STAGE -Force" >> "%LOG%" 2>&1
if %ERRORLEVEL% GEQ 1 goto error

set "SRC="
if exist "%STAGE%\\%EXE%" set "SRC=%STAGE%"
if not defined SRC (
  for /d %%D in ("%STAGE%\\*") do (
    if exist "%%~fD\\%EXE%" set "SRC=%%~fD"
  )
)
if not defined SRC (
  for /r "%STAGE%" %%F in (%EXE%) do (
    if not defined SRC set "SRC=%%~dpF"
  )
)
if not defined SRC goto error

echo Đang cập nhật các file ứng dụng...
echo [%date% %time%] Copying from "%SRC%" to "%APP_DIR%" >> "%LOG%"
robocopy "%SRC%" "%APP_DIR%" /E /R:5 /W:1 /NFL /NDL /NJH /NJS /NP >> "%LOG%" 2>&1
if %ERRORLEVEL% GEQ 8 goto error

echo Hoàn tất! Đang khởi động lại ứng dụng...
echo [%date% %time%] Restarting "%APP_DIR%\\%EXE%" >> "%LOG%"
start "" "%APP_DIR%\\%EXE%"
exit /b 0

:error
echo Cập nhật KHÔNG hoàn tất. Đang mở lại ứng dụng để báo lỗi...
echo [%date% %time%] Update failed. ZIP="%ZIP%" APP_DIR="%APP_DIR%" STAGE="%STAGE%" >> "%LOG%"
rem Khoi dong lai app (ban cu van con) de no doc moc va bao user tai lai ban moi.
if exist "%APP_DIR%\\%EXE%" (
  start "" "%APP_DIR%\\%EXE%"
) else (
  start "" explorer.exe "%APP_DIR%"
)
exit /b 1
''';
  }

  /// Kiểm tra (lúc khởi động) xem lần cập nhật trước đã áp dụng thành công chưa.
  /// Đọc file mốc `.update_pending` cạnh exe (do [_installWindowsZipUpdate] ghi):
  /// - không có mốc → [PostUpdateOutcome.none]
  /// - phiên bản hiện tại ĐÃ >= phiên bản đích → [PostUpdateOutcome.success]
  /// - phiên bản hiện tại VẪN cũ hơn đích → [PostUpdateOutcome.failed]
  ///   (vd update không áp dụng được do đổi tên exe / robocopy lỗi).
  /// Mốc luôn được xóa sau khi đọc để không lặp lại.
  static Future<PostUpdateResult> checkPostUpdateResult() async {
    if (!Platform.isWindows) return const PostUpdateResult(PostUpdateOutcome.none);
    try {
      final appDir = File(Platform.resolvedExecutable).parent.path;
      final marker = File('$appDir${Platform.pathSeparator}.update_pending');
      if (!await marker.exists()) {
        return const PostUpdateResult(PostUpdateOutcome.none);
      }

      final target = (await marker.readAsString()).trim();
      final current = await getCurrentVersion();
      try {
        await marker.delete();
      } catch (_) {/* không sao nếu không xóa được */}

      if (target.isEmpty) return const PostUpdateResult(PostUpdateOutcome.none);

      // target còn mới hơn current → update CHƯA áp dụng → thất bại.
      final failed = isNewerVersion(target, current);
      return PostUpdateResult(
        failed ? PostUpdateOutcome.failed : PostUpdateOutcome.success,
        targetVersion: target,
        currentVersion: current,
      );
    } catch (e) {
      debugPrint('[AppUpdateService] checkPostUpdateResult error: $e');
      return const PostUpdateResult(PostUpdateOutcome.none);
    }
  }

  /// Mở trang releases trên trình duyệt.
  static Future<void> openReleasePage() async {
    final url = Uri.parse(
      'https://giaiphapsangtao.com/studio/crm/subscription',
    );
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
