import 'package:alpha_crm/shared/utils/app_update_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('partial manifest uses the current platform version and assets', () {
    const windowsAsset = {
      'name': 'alpha-crm-windows-v1.1.0.zip',
      'browser_download_url': 'https://example.test/windows.zip',
    };
    const androidAsset = {
      'name': 'alpha-crm-v1.0.0.apk',
      'browser_download_url': 'https://example.test/android.apk',
    };
    final manifest = <String, dynamic>{
      'tag_name': 'v1.0.0',
      'assets': [androidAsset],
      'platform_releases': {
        'windows': {
          'tag_name': 'v1.1.0',
          'assets': [windowsAsset],
        },
        'android': {
          'tag_name': 'v1.0.0',
          'assets': [androidAsset],
        },
      },
    };
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(AppReleaseInfo.fromJson(manifest).version, '1.1.0');
    expect(
      AppReleaseInfo.fromJson(manifest).assets.single.name,
      windowsAsset['name'],
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AppReleaseInfo.fromJson(manifest).version, '1.0.0');
    expect(
      AppReleaseInfo.fromJson(manifest).assets.single.name,
      androidAsset['name'],
    );
  });

  test(
    'legacy manifests remain supported and absent platforms have no update',
    () {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AppReleaseInfo.fromJson({'tag_name': 'v1.0.0'}).version, '1.0.0');
      final release = AppReleaseInfo.fromJson({
        'tag_name': 'v1.1.0',
        'platform_releases': {
          'windows': {'tag_name': 'v1.1.0'},
        },
      });
      expect(release.version, isEmpty);
      expect(release.assets, isEmpty);
    },
  );

  test('windows zip updater script extracts, copies, and restarts app', () {
    final script = AppUpdateService.buildWindowsZipUpdaterScript(
      zipPath: r'C:\Temp\alpha-crm-windows.zip',
      appDir: r'C:\Apps\alpha-crm',
      executableName: 'alpha_crm.exe',
      stagingDir: r'C:\Temp\alpha-crm-stage',
      logPath: r'C:\Temp\alpha-crm-update.log',
    );

    expect(script, contains('Expand-Archive'));
    expect(script, contains(r'-LiteralPath $env:ZIP'));
    expect(script, contains('robocopy "%SRC%" "%APP_DIR%" /E'));
    expect(script, contains('if %ERRORLEVEL% GEQ 8 goto error'));
    expect(script, contains('start "" "%APP_DIR%\\%EXE%"'));
    expect(script, contains('for /d %%D in ("%STAGE%\\*")'));
  });

  test('script chờ đúng pid backend thoát trước khi copy đè', () {
    final script = AppUpdateService.buildWindowsZipUpdaterScript(
      zipPath: r'C:\Temp\alpha-crm-windows.zip',
      appDir: r'C:\Apps\alpha-crm',
      executableName: 'alpha_crm.exe',
      stagingDir: r'C:\Temp\alpha-crm-stage',
      logPath: r'C:\Temp\alpha-crm-update.log',
      backendPid: 4242,
    );

    expect(script, contains('set "BPID=4242"'));
    expect(script, contains(r'tasklist /FI "PID eq %BPID%"'));
    // Vòng chờ phải nằm TRƯỚC lệnh copy, nếu không file vẫn còn bị khoá.
    expect(
      script.indexOf(':backend_gone'),
      lessThan(script.indexOf('robocopy "%SRC%"')),
    );
    // Tuyệt đối không giết theo TÊN tiến trình — sẽ giết cả node.exe khác của
    // người dùng.
    expect(script, isNot(contains('/IM node.exe')));
  });

  test('không có pid thì bỏ qua vòng chờ, không treo updater', () {
    final script = AppUpdateService.buildWindowsZipUpdaterScript(
      zipPath: r'C:\Temp\a.zip',
      appDir: r'C:\Apps\alpha-crm',
      executableName: 'alpha_crm.exe',
      stagingDir: r'C:\Temp\stage',
      logPath: r'C:\Temp\update.log',
    );

    expect(script, contains('set "BPID=0"'));
    expect(script, contains('if not "%BPID%"=="0"'));
  });
}
