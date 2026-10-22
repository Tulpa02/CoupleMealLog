// 餐食数据服务（云开发集合：mealRecord）
//
// 字段：_id、roomId、deviceId、nickname、date、time、mealType、
//       foodName、portion、calorie、protein、carb、fat、imageUrl、imageFileId
//
// 权限：同房间所有设备的记录互相可见；只能编辑 / 删除本设备创建的记录
//      （页面按 deviceId 判断，服务层再按 deviceId 兜底校验）。
import 'package:flutter/foundation.dart';

import '../core/app_config.dart';
import '../models/models.dart';
import 'cache_service.dart';
import 'tcb_service.dart';

class MealService {
  MealService._();

  static final MealService instance = MealService._();

  static const String tableMeal = AppConfig.collectionMeal;

  /// 单次查询上限（云开发默认 100，这里提高到 500 并配合分页）
  static const int _pageSize = 500;

  /// 新增记录
  Future<MealEntry> addMeal({
    required String roomId,
    required String deviceId,
    required String nickname,
    required MealEntry draft,
  }) async {
    final now = DateTime.now();
    final data = <String, dynamic>{
      ...draft.toFields(),
      'roomId': roomId,
      'deviceId': deviceId,
      'nickname': nickname,
      'createdAt': now.toIso8601String(),
      'updateTime': now.toIso8601String(),
    };
    final id = await TcbService.add(tableMeal, data);
    return MealEntry(
      objectId: id,
      roomId: roomId,
      deviceId: deviceId,
      nickname: nickname,
      date: draft.date,
      time: draft.time,
      type: draft.type,
      foodName: draft.foodName,
      portion: draft.portion,
      calories: draft.calories,
      protein: draft.protein,
      carbs: draft.carbs,
      fat: draft.fat,
      imageUrl: draft.imageUrl,
      imageFileId: draft.imageFileId,
      imageUpdatedAt: draft.imageUpdatedAt,
      createdAt: now,
    );
  }

  /// 编辑记录（仅本设备创建的记录）
  Future<void> updateMeal({
    required MealEntry updated,
    required String deviceId,
  }) async {
    final exist = await _getDoc(updated.objectId);
    if (exist == null) throw Exception('记录不存在或已被删除');
    if (toStringValue(exist['deviceId']) != deviceId) {
      throw Exception('只能编辑本设备创建的记录');
    }
    final data = updated.toFields()
      ..['updateTime'] = DateTime.now().toIso8601String();
    await TcbService.update(tableMeal, updated.objectId, data);
    await _refreshDayCache(updated.roomId, updated.date);
  }

  /// 删除记录（仅本设备创建的记录）
  Future<void> deleteMeal({
    required MealEntry entry,
    required String deviceId,
  }) async {
    if (entry.deviceId != deviceId) throw Exception('只能删除本设备创建的记录');
    await TcbService.remove(tableMeal, entry.objectId);
    await _refreshDayCache(entry.roomId, entry.date);
  }

  // ==================== 查询 ====================

  /// 查询某天房间内全部记录，按餐次 + 时间排序，并写入本地缓存
  Future<List<MealEntry>> fetchByDate(String roomId, String date) async {
    final docs = await TcbService.queryWhere(
      tableMeal,
      {'roomId': roomId, 'date': date},
      limit: _pageSize,
    );
    final list = docs.map(MealEntry.fromDoc).toList();
    await _fillImageUrls(list);
    _sort(list);
    await CacheService.instance.saveDay(roomId, date, list);
    return list;
  }

  /// 按日期范围拉取（时间线 / 日历 / CSV 导出），按日期倒序
  ///
  /// 云开发单次最多返回 1000 条；这里按 roomId 拉取后在客户端按日期过滤，
  /// 避免依赖云开发命令组合语法（不同版本支持不一致）。
  Future<List<MealEntry>> fetchRange({
    required String roomId,
    required String from,
    required String to,
  }) async {
    final docs = await TcbService.queryWhere(
      tableMeal,
      {'roomId': roomId},
      orderField: 'date',
      desc: true,
      limit: 1000,
    );
    final list = docs
        .where((d) {
          final date = toStringValue(d['date']);
          return date.compareTo(from) >= 0 && date.compareTo(to) <= 0;
        })
        .map(MealEntry.fromDoc)
        .toList();
    await _fillImageUrls(list);
    list.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    // 按天写入缓存
    final byDate = <String, List<MealEntry>>{};
    for (final e in list) {
      byDate.putIfAbsent(e.date, () => []).add(e);
    }
    for (final item in byDate.entries) {
      _sort(item.value);
      await CacheService.instance.saveDay(roomId, item.key, item.value);
    }
    return list;
  }

  /// 最新 N 条记录（时间线预览）
  Future<List<MealEntry>> fetchLatest(String roomId, {int limit = 200}) async {
    final docs = await TcbService.queryWhere(
      tableMeal,
      {'roomId': roomId},
      orderField: 'date',
      desc: true,
      limit: limit,
    );
    final list = docs.map(MealEntry.fromDoc).toList();
    await _fillImageUrls(list);
    list.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return list;
  }

  /// 某段时间内有记录的日期集合（日历打点）
  ///
  /// 同样避免使用命令组合语法：按房间拉取日期字段后在客户端过滤。
  Future<Set<String>> fetchDatesWithMeals(
    String roomId, {
    required String from,
    required String to,
  }) async {
    final docs = await TcbService.queryWhere(
      tableMeal,
      {'roomId': roomId},
      projection: {'date': true},
      limit: 1000,
    );
    return docs
        .map((d) => toStringValue(d['date']))
        .where((date) => date.compareTo(from) >= 0 && date.compareTo(to) <= 0)
        .toSet();
  }

  /// 读取某天的本地缓存（离线时使用）
  Future<List<MealEntry>?> readCachedDay(String roomId, String date) =>
      CacheService.instance.readDay(roomId, date);

  // ==================== 内部方法 ====================

  /// 按 ID 读取单个文档
  Future<Map<String, dynamic>?> _getDoc(String docId) async {
    if (docId.isEmpty) return null;
    final list =
        await TcbService.queryWhere(tableMeal, {'_id': docId}, limit: 1);
    return list.isEmpty ? null : list.first;
  }

  /// 补齐图片访问链接
  ///
  /// 云存储图片只能用「fileID → 临时下载链接」的方式访问，链接会过期，
  /// 因此**每次读取都要重新换取**，不能复用数据库里存的旧链接。
  /// 这里按 50 个一批调用 getDownloadUrls，减少请求次数。
  Future<void> _fillImageUrls(List<MealEntry> list) async {
    final indexes = <int>[];
    final fileIds = <String>[];
    for (var i = 0; i < list.length; i++) {
      final id = list[i].imageFileId;
      if (id != null && id.isNotEmpty) {
        indexes.add(i);
        fileIds.add(id);
      }
    }
    if (fileIds.isEmpty) return;

    const batchSize = 50;
    for (var start = 0; start < fileIds.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, fileIds.length);
      final chunk = fileIds.sublist(start, end);
      try {
        final urls = await TcbService.getTempFileURLs(chunk);
        for (var k = 0; k < chunk.length; k++) {
          final url = urls[chunk[k]];
          if (url == null || !url.startsWith('http')) continue;
          final idx = indexes[start + k];
          list[idx] = list[idx].copyWith(imageUrl: url);
        }
      } catch (e) {
        debugPrint('批量获取图片链接失败：$e');
      }
    }
  }

  /// 重新拉取并刷新某天的缓存
  Future<void> _refreshDayCache(String roomId, String date) async {
    try {
      await fetchByDate(roomId, date);
    } catch (e) {
      debugPrint('刷新缓存失败：$e');
    }
  }

  /// 统一排序：日期 → 餐类型顺序 → 时间
  static void _sort(List<MealEntry> list) {
    list.sort((a, b) {
      final c = a.sortKey.compareTo(b.sortKey);
      if (c != 0) return c;
      return a.type.index.compareTo(b.type.index);
    });
  }
}
