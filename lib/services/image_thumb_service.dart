// 图片缩略图服务（存数据库，绕开云存储的付费权限）
//
// 背景：
// 云存储「所有用户可读」需要付费套餐，而默认的「仅创建者可读写」会导致
// 伴侣那台手机取不到下载链接，表现为「自己能看到图，对方看不到」。
//
// 方案：
// 拍完照后，在本机把图片压成一张小缩略图（最长边 480px、JPEG），
// 转成 Base64 字符串存进 mealImage 集合。数据库权限用的是
// 「读取全部数据，修改本人数据」，两人都能读 → 伴侣立刻能看到缩略图。
//
// 云存储仍然照常上传原图：自己的设备看大图走原图，
// 对方取不到原图时自动退回这张缩略图。
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../core/app_config.dart';
import '../models/models.dart';
import 'tcb_service.dart';

class ImageThumbService {
  ImageThumbService._();

  static final ImageThumbService instance = ImageThumbService._();

  static const String tableThumb = AppConfig.collectionImage;

  /// 缩略图最长边（像素）
  static const int _maxSide = 480;

  /// 单张缩略图 Base64 的目标上限（约 45KB，远低于云开发单文档 512KB 限制）
  static const int _maxBase64Length = 60000;

  /// 把本地图片压成 Base64 缩略图（在独立 Isolate 中执行，避免卡界面）
  ///
  /// 失败返回 null（存图失败不应影响记录保存）。
  Future<String?> buildThumbBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return await Isolate.run(() => _encode(bytes));
    } catch (e) {
      debugPrint('生成缩略图失败：$e');
      return null;
    }
  }

  /// 同步压缩逻辑（在 Isolate 内运行，不能访问 UI）
  static String? _encode(Uint8List bytes) {
    var image = img.decodeImage(bytes);
    if (image == null) return null;

    // 缩放到最长边 480
    if (image.width > _maxSide || image.height > _maxSide) {
      image = image.width >= image.height
          ? img.copyResize(image,
              width: _maxSide, interpolation: img.Interpolation.average)
          : img.copyResize(image,
              height: _maxSide, interpolation: img.Interpolation.average);
    }

    // 先按质量 60 编码，过大则逐级降低
    var encoded = img.encodeJpg(image, quality: 60);
    for (final quality in const [50, 40, 30]) {
      if (encoded.length * 4 ~/ 3 <= _maxBase64Length) break;
      encoded = img.encodeJpg(image, quality: quality);
    }
    final base64Text = base64Encode(encoded);
    if (base64Text.length > _maxBase64Length) {
      debugPrint('缩略图仍然偏大（${base64Text.length}），已强行写入');
    }
    return base64Text;
  }

  /// 保存/更新某条记录的缩略图
  Future<void> save({
    required String mealId,
    required String roomId,
    required String date,
    required String deviceId,
    required String thumb,
  }) async {
    if (mealId.isEmpty || thumb.isEmpty) return;
    try {
      final existing = await TcbService.queryWhere(
        tableThumb,
        {'mealId': mealId},
        limit: 1,
      );
      final data = <String, dynamic>{
        'mealId': mealId,
        'roomId': roomId,
        'date': date,
        'deviceId': deviceId,
        'thumb': thumb,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (existing.isEmpty) {
        await TcbService.add(tableThumb, data);
      } else {
        await TcbService.update(tableThumb, docId(existing.first), data);
      }
    } catch (e) {
      // 缩略图失败不影响主流程
      debugPrint('保存缩略图失败：${TcbService.friendlyError(e)}');
    }
  }

  /// 删除某条记录的缩略图
  Future<void> deleteByMealId(String mealId) async {
    if (mealId.isEmpty) return;
    try {
      await TcbService.removeWhere(tableThumb, {'mealId': mealId});
    } catch (e) {
      debugPrint('删除缩略图失败：$e');
    }
  }

  /// 读取某个房间在指定日期范围内的缩略图
  ///
  /// 返回 mealId → Base64 的映射。
  Future<Map<String, String>> fetchByRoom(
    String roomId, {
    required String from,
    required String to,
  }) async {
    try {
      final docs = await TcbService.queryWhere(
        tableThumb,
        {'roomId': roomId},
        limit: 300,
      );
      final map = <String, String>{};
      for (final d in docs) {
        final date = toStringValue(d['date']);
        if (date.compareTo(from) < 0 || date.compareTo(to) > 0) continue;
        final id = toStringValue(d['mealId']);
        final thumb = toStringValue(d['thumb']);
        if (id.isEmpty || thumb.isEmpty) continue;
        map[id] = thumb;
      }
      return map;
    } catch (e) {
      debugPrint('读取缩略图失败：${TcbService.friendlyError(e)}');
      return const {};
    }
  }
}
