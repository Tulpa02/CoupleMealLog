// 本地缓存服务
//
// 作用：
// 1. 保存「已加载的记录」快照，离线时仍可查看（数据在线获取，离线时依赖这里的缓存，
//    这里额外保存一份 JSON 快照，用于离线冷启动时首页立刻展示最近数据）；
// 2. 按日期分片缓存：rooms/{roomId} → { 日期: [记录...] }；
// 3. 提供缓存大小统计与一键清除。
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class CacheService {
  CacheService._();

  static final CacheService instance = CacheService._();

  static const String _keyPrefix = 'meal_cache_';

  /// 内存中的缓存表：roomId → (date → json 列表)
  final Map<String, Map<String, List<dynamic>>> _memory = {};

  /// 缓存变化的通知（页面可监听以便在清理缓存后刷新）
  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _notify() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  /// 加载房间缓存到内存（应用内首次访问时调用）
  Future<void> _ensureLoaded(String roomId) async {
    if (_memory.containsKey(roomId)) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$roomId');
    if (raw == null) {
      _memory[roomId] = {};
      return;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final map = <String, List<dynamic>>{};
      decoded.forEach((date, list) {
        map[date] = List<dynamic>.from(list as List);
      });
      _memory[roomId] = map;
    } catch (_) {
      _memory[roomId] = {};
    }
  }

  Future<void> _flush(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = _memory[roomId] ?? {};
    // 只保留最近 60 天，避免 SharedPreferences 体积过大
    final dates = data.keys.toList()..sort((a, b) => b.compareTo(a));
    final keep = dates.take(60).toList();
    final trimmed = <String, dynamic>{
      for (final d in keep) d: data[d],
    };
    await prefs.setString('$_keyPrefix$roomId', jsonEncode(trimmed));
  }

  /// 写入某天的记录快照
  Future<void> saveDay(
      String roomId, String date, List<MealEntry> meals) async {
    await _ensureLoaded(roomId);
    _memory[roomId]![date] = meals.map(_toJson).toList();
    await _flush(roomId);
  }

  /// 读取某天的本地缓存（无缓存返回 null）
  Future<List<MealEntry>?> readDay(String roomId, String date) async {
    await _ensureLoaded(roomId);
    final list = _memory[roomId]![date];
    if (list == null) return null;
    final result = <MealEntry>[];
    for (final item in list) {
      try {
        final map = Map<String, dynamic>.from(item as Map);
        final entry = MealEntry.fromDoc(map);
        result.add(entry);
      } catch (_) {
        // 兼容旧缓存格式，忽略坏数据
      }
    }
    return result.isEmpty ? null : result;
  }

  /// 读取缓存中的全部记录（按日期倒序）
  Future<List<MealEntry>> readAll(String roomId) async {
    await _ensureLoaded(roomId);
    final map = _memory[roomId] ?? {};
    final dates = map.keys.toList()..sort((a, b) => b.compareTo(a));
    final result = <MealEntry>[];
    for (final d in dates) {
      final cached = await readDay(roomId, d);
      if (cached != null) result.addAll(cached);
    }
    return result;
  }

  /// 缓存所占字节数（以 SharedPreferences 中字符串长度估算）
  Future<int> cacheSizeBytes() async {
    final prefs = await SharedPreferences.getInstance();
    var total = 0;
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_keyPrefix)) {
        total += utf8.encode(prefs.getString(key) ?? '').length;
      }
    }
    // 额外统计应用缓存目录（图片缓存等）的大小
    try {
      final dir = await getTemporaryDirectory();
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
    } catch (_) {
      // 目录不可读时忽略
    }
    return total;
  }

  /// 清除全部本地缓存
  Future<void> clearAll() async {
    _memory.clear();
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_keyPrefix)) {
        await prefs.remove(key);
      }
    }
    try {
      final dir = await getTemporaryDirectory();
      if (await dir.exists()) {
        // 注意：getTemporaryDirectory() 是 App 专属缓存目录，只清理其中的子项
        await for (final entity in dir.list()) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {
            // 单个文件被占用时忽略
          }
        }
      }
    } catch (_) {
      // 忽略删除失败
    }
    _notify();
  }

  /// 字节数转可读文本
  static String readableSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> _toJson(MealEntry e) => {
        ...e.toFields(),
        '_id': e.objectId,
        // 缓存里额外保留图片链接，离线时也能显示已加载过的图片
        'imageUrl': e.imageUrl,
        'createdAt': e.createdAt?.toIso8601String(),
      };
}
