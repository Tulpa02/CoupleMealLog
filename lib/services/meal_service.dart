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
import 'image_thumb_service.dart';
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

    // 缩略图单独存 mealImage 集合（数据库权限两人都可读，
    // 绕开云存储「所有用户可读」的付费限制）
    final thumb = draft.imageThumb;
    if (thumb != null && thumb.isNotEmpty) {
      await ImageThumbService.instance.save(
        mealId: id,
        roomId: roomId,
        date: draft.date,
        deviceId: deviceId,
        thumb: thumb,
      );
    }

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
      imageThumb: thumb,
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

    // 图片有变化时同步缩略图
    final thumb = updated.imageThumb;
    if (updated.imageFileId == null) {
      // 图片被移除
      await ImageThumbService.instance.deleteByMealId(updated.objectId);
    } else if (thumb != null && thumb.isNotEmpty) {
      await ImageThumbService.instance.save(
        mealId: updated.objectId,
        roomId: updated.roomId,
        date: updated.date,
        deviceId: deviceId,
        thumb: thumb,
      );
    }

    await _refreshDayCache(updated.roomId, updated.date);
  }

  /// 删除记录（仅本设备创建的记录）
  Future<void> deleteMeal({
    required MealEntry entry,
    required String deviceId,
  }) async {
    if (entry.deviceId != deviceId) throw Exception('只能删除本设备创建的记录');
    await TcbService.remove(tableMeal, entry.objectId);
    await ImageThumbService.instance.deleteByMealId(entry.objectId);
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
    await _fillThumbs(list, roomId, from: date, to: date);
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
    await _fillThumbs(list, roomId, from: from, to: to);
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
    await _fillThumbs(list, roomId, from: '', to: '9999-12-31');
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
  ///
  /// 先按 50 个一批换取（省请求），批里若有取不到的（例如伴侣的图片
  /// 受云存储权限限制），再逐个重试一次，避免一条失败拖累整批。
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

    void apply(int idx, String? url) {
      if (url == null || !url.startsWith('http')) return;
      list[idx] = list[idx].copyWith(imageUrl: url);
    }

    const batchSize = 50;
    for (var start = 0; start < fileIds.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, fileIds.length);
      final chunk = fileIds.sublist(start, end);

      // 1) 批量换取
      var got = <String, String>{};
      try {
        got = await TcbService.getTempFileURLs(chunk);
      } catch (e) {
        debugPrint('批量获取图片链接失败，改为逐个获取：$e');
      }
      for (var k = 0; k < chunk.length; k++) {
        apply(indexes[start + k], got[chunk[k]]);
      }

      // 2) 批量里没拿到的，逐个再试一次
      for (var k = 0; k < chunk.length; k++) {
        final idx = indexes[start + k];
        if (list[idx].imageUrl != null) continue;
        try {
          final url = await TcbService.getTempFileURL(chunk[k]);
          apply(idx, url);
        } catch (e) {
          debugPrint('获取图片链接失败（${chunk[k]}）：${TcbService.friendlyError(e)}');
        }
      }
    }
  }

  /// 补上缩略图（Base64，来自 mealImage 集合）
  ///
  /// 只有「原图链接拿不到」的记录才需要缩略图，最常见的就是伴侣的记录：
  /// 云存储默认「仅创建者可读写」，对方取不到签名链接。
  Future<void> _fillThumbs(
    List<MealEntry> list,
    String roomId, {
    required String from,
    required String to,
  }) async {
    final need = list.where((e) => e.imageFileId != null).toList();
    if (need.isEmpty) return;
    final thumbs = await ImageThumbService.instance.fetchByRoom(
      roomId,
      from: from,
      to: to,
    );
    if (thumbs.isEmpty) return;
    for (var i = 0; i < list.length; i++) {
      final thumb = thumbs[list[i].objectId];
      if (thumb == null || thumb.isEmpty) continue;
      list[i] = list[i].copyWith(imageThumb: thumb);
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
