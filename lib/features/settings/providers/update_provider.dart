import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/utils/app_update_service.dart';

enum UpdateStatus {
  idle,
  checking,
  available,
  upToDate,
  downloading,
  readyToInstall,
  installing,
  error,
}

class UpdateState {
  final UpdateStatus status;
  final String currentVersion;
  final AppReleaseInfo? latestRelease;
  final ReleaseAsset? targetAsset;
  final double downloadProgress;
  final String? downloadedFilePath;
  final String? errorText;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.currentVersion = '',
    this.latestRelease,
    this.targetAsset,
    this.downloadProgress = 0.0,
    this.downloadedFilePath,
    this.errorText,
  });

  bool get hasUpdate =>
      status == UpdateStatus.available ||
      status == UpdateStatus.downloading ||
      status == UpdateStatus.readyToInstall;

  UpdateState copyWith({
    UpdateStatus? status,
    String? currentVersion,
    AppReleaseInfo? latestRelease,
    ReleaseAsset? targetAsset,
    double? downloadProgress,
    String? downloadedFilePath,
    String? errorText,
  }) {
    return UpdateState(
      status: status ?? this.status,
      currentVersion: currentVersion ?? this.currentVersion,
      latestRelease: latestRelease ?? this.latestRelease,
      targetAsset: targetAsset ?? this.targetAsset,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedFilePath: downloadedFilePath ?? this.downloadedFilePath,
      errorText: errorText,
    );
  }
}

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier() : super(const UpdateState());

  /// Kiểm tra cập nhật từ GitHub Releases.
  Future<void> checkForUpdates() async {
    if (state.status == UpdateStatus.checking ||
        state.status == UpdateStatus.downloading) {
      return;
    }

    state = state.copyWith(
      status: UpdateStatus.checking,
      errorText: null,
    );

    try {
      final currentVersion = await AppUpdateService.getCurrentVersion();
      final latestRelease = await AppUpdateService.getLatestRelease();

      if (latestRelease == null) {
        state = state.copyWith(
          status: UpdateStatus.upToDate,
          currentVersion: currentVersion,
          errorText: null,
        );
        return;
      }

      final isNewer = AppUpdateService.isNewerVersion(
        latestRelease.version,
        currentVersion,
      );

      if (isNewer) {
        final asset = latestRelease.getAssetForCurrentPlatform();
        state = state.copyWith(
          status: UpdateStatus.available,
          currentVersion: currentVersion,
          latestRelease: latestRelease,
          targetAsset: asset,
        );
      } else {
        state = state.copyWith(
          status: UpdateStatus.upToDate,
          currentVersion: currentVersion,
          latestRelease: latestRelease,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorText: 'Lỗi kiểm tra cập nhật: $e',
      );
    }
  }

  /// Tải bản cập nhật.
  Future<void> downloadUpdate() async {
    final asset = state.targetAsset;
    if (asset == null) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorText: _noAssetMessage(),
      );
      return;
    }

    state = state.copyWith(
      status: UpdateStatus.downloading,
      downloadProgress: 0.0,
      errorText: null,
    );

    final filePath = await AppUpdateService.downloadAsset(
      asset,
      onProgress: (progress) {
        state = state.copyWith(downloadProgress: progress);
      },
    );

    if (filePath != null) {
      state = state.copyWith(
        status: UpdateStatus.readyToInstall,
        downloadedFilePath: filePath,
        downloadProgress: 1.0,
      );
    } else {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorText: 'Tải bản cập nhật thất bại. Vui lòng thử lại.',
      );
    }
  }

  /// Cài đặt bản cập nhật đã tải.
  Future<void> installUpdate() async {
    final filePath = state.downloadedFilePath;
    if (filePath == null) return;

    state = state.copyWith(status: UpdateStatus.installing);

    final success = await AppUpdateService.installUpdate(filePath);
    if (!success) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorText: 'Không thể mở file cài đặt. Vui lòng cài thủ công.',
      );
    }
  }

  /// Mở trang releases trên trình duyệt.
  Future<void> openReleasePage() async {
    if (state.latestRelease?.htmlUrl != null &&
        state.latestRelease!.htmlUrl.isNotEmpty) {
      await AppUpdateService.openReleaseUrl(state.latestRelease!.htmlUrl);
    } else {
      await AppUpdateService.openReleasePage();
    }
  }

  String _noAssetMessage() {
    final platform = Platform.isWindows
        ? 'Windows (.exe)'
        : Platform.isAndroid
            ? 'Android (.apk)'
            : Platform.operatingSystem;
    return 'Không tìm thấy file cài đặt cho $platform. '
        'Vui lòng tải thủ công từ trang Releases.';
  }
}

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>(
  (ref) => UpdateNotifier(),
);
