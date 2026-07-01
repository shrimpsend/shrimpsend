import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';
import '../logger.dart';

const sharedPreferencesFileName = 'shared_preferences.json';

/// Whether [error] indicates corrupted on-disk SharedPreferences JSON.
bool isSharedPreferencesCorruptionError(Object error) {
  if (error is FormatException) return true;
  final message = error.toString();
  return message.contains('FormatException') &&
      message.contains('Unexpected character');
}

/// Typical Windows Roaming path shown in boot-failure recovery hints.
String sharedPreferencesRecoveryHintPath() {
  final product = Env.overseasBuild ? 'Shrimpsend' : '虾传';
  return '%APPDATA%\\dev.ultrasend\\$product\\$sharedPreferencesFileName';
}

/// Optional user-facing recovery steps when startup fails on prefs corruption.
String? bootFailureRecoveryHint(Object error) {
  if (!isSharedPreferencesCorruptionError(error)) return null;
  return '''
检测到本地设置文件损坏（shared_preferences.json）。

可尝试手动恢复：
1. 完全退出应用（任务管理器确认无相关进程）
2. 打开目录：${sharedPreferencesRecoveryHintPath().replaceAll(r'\', '/').replaceFirst('%APPDATA%', 'C:\\Users\\<你的用户名>\\AppData\\Roaming')}
3. 将 shared_preferences.json 重命名为 shared_preferences.json.bak
4. 重新启动应用（需重新登录；聊天记录数据库通常不受影响）

Corrupted local settings file (shared_preferences.json).

Manual recovery:
1. Fully quit the app
2. Open: ${sharedPreferencesRecoveryHintPath()}
3. Rename shared_preferences.json to shared_preferences.json.bak
4. Restart the app (sign-in required; chat database is usually intact)
''';
}

/// Resolves the on-disk SharedPreferences JSON path for desktop platforms.
Future<String?> resolveSharedPreferencesFilePath() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return null;
  }
  try {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, sharedPreferencesFileName);
  } catch (e, st) {
    logBoot.warning('resolve shared_preferences path failed: $e', e, st);
    return null;
  }
}

/// Renames a corrupted prefs file so [SharedPreferences] can recreate it.
///
/// Returns the backup path when successful.
@visibleForTesting
Future<String?> backupCorruptedPrefsFileAt(String prefsPath) async {
  final file = File(prefsPath);
  if (!await file.exists()) return null;

  final timestamp =
      DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
  final backupPath = p.join(
    p.dirname(prefsPath),
    'shared_preferences.corrupt.$timestamp.json',
  );

  try {
    await file.rename(backupPath);
    logBoot.warning('backed up corrupted shared_preferences to $backupPath');
    return backupPath;
  } catch (e, st) {
    logBoot.warning('rename corrupted shared_preferences failed: $e', e, st);
  }

  try {
    await file.copy(backupPath);
    await file.delete();
    logBoot.warning('copied corrupted shared_preferences to $backupPath');
    return backupPath;
  } catch (e, st) {
    logBoot.warning('copy corrupted shared_preferences failed: $e', e, st);
  }

  try {
    await file.delete();
    logBoot.warning('deleted corrupted shared_preferences at $prefsPath');
  } catch (e, st) {
    logBoot.warning('delete corrupted shared_preferences failed: $e', e, st);
  }
  return null;
}

/// Loads [SharedPreferences], recovering automatically when the on-disk JSON
/// is corrupted (common after forced kill during desktop hot-update).
Future<SharedPreferences> ensureSharedPreferencesReady() async {
  try {
    return await SharedPreferences.getInstance();
  } catch (e, st) {
    if (!isSharedPreferencesCorruptionError(e)) rethrow;

    logBoot.warning(
      'shared_preferences corrupted, attempting recovery: $e',
      e,
      st,
    );

    final prefsPath = await resolveSharedPreferencesFilePath();
    if (prefsPath != null) {
      await backupCorruptedPrefsFileAt(prefsPath);
    }

    SharedPreferences.resetStatic();
    try {
      final prefs = await SharedPreferences.getInstance();
      logBoot.warning(
        'shared_preferences recovered from corruption; user may need to sign in again',
      );
      return prefs;
    } catch (e2, st2) {
      logBoot.severe('shared_preferences recovery failed: $e2', e2, st2);
      rethrow;
    }
  }
}
