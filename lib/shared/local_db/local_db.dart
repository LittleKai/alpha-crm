import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'local_db_schema.dart';

class LocalDb {
  static Database? _db;
  static Future<Database>? _openingFuture;
  static bool _ffiInitialized = false;

  /// Retrieves the shared instance, initializing if necessary.
  static Future<Database> get instance async {
    if (_db != null && _db!.isOpen) return _db!;
    _openingFuture ??= _initDb().then((db) {
      _db = db;
      _openingFuture = null;
      return db;
    }).catchError((Object e) {
      _openingFuture = null;
      throw e;
    });
    return _openingFuture!;
  }

  /// Closes the current database instance and resets the singleton reference.
  static Future<void> closeAndReset() async {
    final current = _db;
    _db = null;
    _openingFuture = null;
    if (current != null && current.isOpen) {
      await current.close();
    }
  }

  /// Initialize FFI for desktop if needed.
  static void _ensureFfiInitialized() {
    if (_ffiInitialized) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _ffiInitialized = true;
  }

  static Future<Database> _initDb({bool inMemory = false}) async {
    _ensureFfiInitialized();

    String path;
    if (inMemory) {
      path = inMemoryDatabasePath;
    } else {
      final appSupportDir = await getApplicationSupportDirectory();
      path = join(appSupportDir.path, 'alpha_crm_local_v1.db');
    }

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: LocalDbSchema.version,
        onCreate: (db, version) async {
          for (final script in LocalDbSchema.initialScripts) {
            await db.execute(script);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          debugPrint('DEBUG: LocalDb onUpgrade from $oldVersion to $newVersion');
          if (oldVersion < 2) {
            for (final script in LocalDbSchema.version2Scripts) {
              await db.execute(script);
            }
          }
          if (oldVersion < 3) {
            for (final script in LocalDbSchema.version3Scripts) {
              await db.execute(script);
            }
          }
          if (oldVersion < 4) {
            for (final script in LocalDbSchema.version4Scripts) {
              await db.execute(script);
            }
          }
        },
      ),
    );
  }

  /// For testing: force close and recreate a clean in-memory database
  @visibleForTesting
  static Future<Database> getInMemoryInstance() async {
    if (_db != null) {
      await _db!.close();
    }
    _db = await _initDb(inMemory: true);
    return _db!;
  }

  /// Store a value in the generic key/value cache (offline-first fallback).
  static Future<void> putCache(
    String key,
    String value, {
    Duration ttl = const Duration(days: 30),
  }) async {
    final db = await instance;
    await db.insert(
      'cache_entries',
      {
        'key': key,
        'value': value,
        'expiresAt': DateTime.now().add(ttl).millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Read a cached value, or null if missing/expired (expired rows are purged).
  static Future<String?> getCache(String key) async {
    final db = await instance;
    final rows = await db.query(
      'cache_entries',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final expiresAt = rows.first['expiresAt'] as int;
    if (expiresAt < DateTime.now().millisecondsSinceEpoch) {
      await db.delete('cache_entries', where: 'key = ?', whereArgs: [key]);
      return null;
    }
    return rows.first['value'] as String?;
  }

  /// Convenience method to clear expired cache entries periodically.
  static Future<void> cleanupExpiredCache() async {
    final db = await instance;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.delete('cache_entries', where: 'expiresAt < ?', whereArgs: [now]);
    await db.delete('media_cache', where: 'expiresAt < ?', whereArgs: [now]);
  }
}
