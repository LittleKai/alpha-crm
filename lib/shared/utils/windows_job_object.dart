import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Win32 Job Object helper: trói tiến trình backend vào một Job Object có cờ
/// KILL_ON_JOB_CLOSE. Khi app thoát (kể cả bị kill cứng qua Task Manager), OS
/// đóng mọi handle của tiến trình app → Job đóng → tiến trình con bị diệt tự
/// động. Nhờ vậy node.exe không bao giờ mồ côi giữ cổng 8787.
///
/// Tách riêng khỏi Flutter để các symbol Win32/FFI không xung đột tên với
/// `package:flutter/foundation.dart`.
class WindowsJobObject {
  static const int _jobObjectExtendedLimitInformation = 9;
  static const int _jobObjectLimitKillOnJobClose = 0x00002000;
  static const int _processTerminate = 0x0001;
  static const int _processSetQuota = 0x0100;

  /// Handle của Job Object dùng chung cho cả vòng đời app. Giữ mở cố ý — khi
  /// app chết, OS tự đóng và diệt tiến trình con. 0 = chưa tạo / không khả dụng.
  static int _jobHandle = 0;
  static bool _initFailed = false;

  /// Tạo Job Object (idempotent). Trả về true nếu Job sẵn sàng dùng.
  static bool _ensureJob() {
    if (!Platform.isWindows || _initFailed) return false;
    if (_jobHandle != 0) return true;

    try {
      final job = CreateJobObject(nullptr, nullptr);
      if (job == 0) {
        _initFailed = true;
        return false;
      }

      final info = calloc<_JobObjectExtendedLimitInformation>();
      try {
        info.ref.limitFlags = _jobObjectLimitKillOnJobClose;
        final ok = SetInformationJobObject(
          job,
          _jobObjectExtendedLimitInformation,
          info.cast(),
          sizeOf<_JobObjectExtendedLimitInformation>(),
        );
        if (ok == 0) {
          CloseHandle(job);
          _initFailed = true;
          return false;
        }
      } finally {
        calloc.free(info);
      }

      _jobHandle = job;
      return true;
    } catch (_) {
      _initFailed = true;
      return false;
    }
  }

  /// Gán tiến trình [pid] vào Job Object dùng chung. An toàn để gọi nhiều lần;
  /// thất bại sẽ im lặng (fallback về taskkill khi tắt app). Trả về true nếu gán
  /// thành công.
  static bool assignProcess(int pid) {
    if (!Platform.isWindows) return false;
    if (!_ensureJob()) return false;

    try {
      final hProc = OpenProcess(_processSetQuota | _processTerminate, 0, pid);
      if (hProc == 0) return false;
      try {
        return AssignProcessToJobObject(_jobHandle, hProc) != 0;
      } finally {
        CloseHandle(hProc);
      }
    } catch (_) {
      return false;
    }
  }
}

/// Layout của JOBOBJECT_EXTENDED_LIMIT_INFORMATION (không có sẵn trong win32
/// package). Dart FFI tự chèn padding theo ABI nên không khai báo padding thủ
/// công. Chỉ `limitFlags` được dùng; calloc bảo đảm các trường còn lại = 0.
final class _JobObjectExtendedLimitInformation extends Struct {
  // JOBOBJECT_BASIC_LIMIT_INFORMATION
  @Int64()
  external int perProcessUserTimeLimit;
  @Int64()
  external int perJobUserTimeLimit;
  @Uint32()
  external int limitFlags;
  @IntPtr()
  external int minimumWorkingSetSize;
  @IntPtr()
  external int maximumWorkingSetSize;
  @Uint32()
  external int activeProcessLimit;
  @IntPtr()
  external int affinity;
  @Uint32()
  external int priorityClass;
  @Uint32()
  external int schedulingClass;
  // IO_COUNTERS
  @Uint64()
  external int readOperationCount;
  @Uint64()
  external int writeOperationCount;
  @Uint64()
  external int otherOperationCount;
  @Uint64()
  external int readTransferCount;
  @Uint64()
  external int writeTransferCount;
  @Uint64()
  external int otherTransferCount;
  // Extended limits
  @IntPtr()
  external int processMemoryLimit;
  @IntPtr()
  external int jobMemoryLimit;
  @IntPtr()
  external int peakProcessMemoryUsed;
  @IntPtr()
  external int peakJobMemoryUsed;
}
