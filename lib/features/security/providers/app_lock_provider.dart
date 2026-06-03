import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/app_lock_crypto.dart';

class AppLockState {
  final bool isLoading;
  final bool isLocked;
  final bool hasPassword;
  final bool setupRequired;
  final bool lockOnStartup;
  final String? salt;
  final String? passwordHash;
  final String? errorText;

  const AppLockState({
    this.isLoading = false,
    this.isLocked = false,
    this.hasPassword = false,
    this.setupRequired = false,
    this.lockOnStartup = false,
    this.salt,
    this.passwordHash,
    this.errorText,
  });

  AppLockState copyWith({
    bool? isLoading,
    bool? isLocked,
    bool? hasPassword,
    bool? setupRequired,
    bool? lockOnStartup,
    String? salt,
    String? passwordHash,
    String? errorText,
  }) {
    return AppLockState(
      isLoading: isLoading ?? this.isLoading,
      isLocked: isLocked ?? this.isLocked,
      hasPassword: hasPassword ?? this.hasPassword,
      setupRequired: setupRequired ?? this.setupRequired,
      lockOnStartup: lockOnStartup ?? this.lockOnStartup,
      salt: salt ?? this.salt,
      passwordHash: passwordHash ?? this.passwordHash,
      errorText: errorText,
    );
  }
}

class AppLockNotifier extends StateNotifier<AppLockState> {
  AppLockNotifier() : super(const AppLockState());

  Future<void> load() async {
    if (kIsWeb) return;
    state = state.copyWith(isLoading: true, errorText: null);
    try {
      final file = await _settingsFile();
      if (!await file.exists()) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final salt = data['salt']?.toString() ?? '';
      final passwordHash = data['passwordHash']?.toString() ?? '';
      final hasPassword = salt.isNotEmpty && passwordHash.isNotEmpty;
      final lockOnStartup = data['lockOnStartup'] == true;
      state = state.copyWith(
        isLoading: false,
        hasPassword: hasPassword,
        salt: salt,
        passwordHash: passwordHash,
        lockOnStartup: lockOnStartup,
        isLocked: hasPassword && lockOnStartup,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorText: e.toString());
    }
  }

  Future<void> lock() async {
    if (!state.hasPassword) {
      state = state.copyWith(
        isLocked: true,
        setupRequired: true,
        errorText: null,
      );
      return;
    }
    state = state.copyWith(
      isLocked: true,
      setupRequired: false,
      errorText: null,
    );
  }

  Future<void> setPassword(String password, {bool lockOnStartup = true}) async {
    if (password.trim().length < 4) {
      state = state.copyWith(errorText: 'Mật khẩu khóa cần ít nhất 4 ký tự.');
      return;
    }
    final salt = AppLockCrypto.createSalt();
    final passwordHash = AppLockCrypto.hashPassword(password, salt);
    state = state.copyWith(
      hasPassword: true,
      salt: salt,
      passwordHash: passwordHash,
      lockOnStartup: lockOnStartup,
      isLocked: false,
      setupRequired: false,
      errorText: null,
    );
    await _save();
  }

  Future<void> unlock(String password) async {
    final salt = state.salt;
    final passwordHash = state.passwordHash;
    if (salt == null || passwordHash == null) {
      state = state.copyWith(errorText: 'Chưa thiết lập mật khẩu khóa.');
      return;
    }
    if (!AppLockCrypto.verifyPassword(password, salt, passwordHash)) {
      state = state.copyWith(errorText: 'Sai mật khẩu.');
      return;
    }
    state = state.copyWith(
      isLocked: false,
      setupRequired: false,
      errorText: null,
    );
  }

  Future<void> setLockOnStartup(bool value) async {
    state = state.copyWith(lockOnStartup: value, errorText: null);
    await _save();
  }

  Future<void> clearPassword() async {
    state = const AppLockState();
    if (kIsWeb) return;
    final file = await _settingsFile();
    if (await file.exists()) await file.delete();
  }

  Future<File> _settingsFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}app_lock.json');
  }

  Future<void> _save() async {
    if (kIsWeb || !state.hasPassword) return;
    final file = await _settingsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'salt': state.salt,
        'passwordHash': state.passwordHash,
        'lockOnStartup': state.lockOnStartup,
      }),
    );
  }
}

final appLockProvider = StateNotifierProvider<AppLockNotifier, AppLockState>((
  ref,
) {
  return AppLockNotifier();
});
