import 'package:alpha_crm/shared/utils/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
