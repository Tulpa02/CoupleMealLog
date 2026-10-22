// 图片服务（云开发云存储）
//
// 流程：拍照 / 相册选图 → 上传到云存储 → 得到 fileID 与临时访问链接
// → 把 fileID 与链接写入 mealRecord（删除记录时用 fileID 清理云端文件）。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_config.dart';
import 'tcb_service.dart';

class ImageService {
  ImageService._();

  static final ImageService instance = ImageService._();

  final ImagePicker _picker = ImagePicker();

  /// 压缩参数：降低图片体积，节省流量
  static const int _maxWidth = 1600;
  static const int _quality = 80;

  /// 调用相机拍照（用户取消返回 null）
  Future<File?> takePhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxWidth.toDouble(),
      imageQuality: _quality,
      preferredCameraDevice: CameraDevice.rear,
    );
    return picked == null ? null : File(picked.path);
  }

  /// 从相册选择图片（用户取消返回 null）
  Future<File?> pickFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _maxWidth.toDouble(),
      imageQuality: _quality,
    );
    return picked == null ? null : File(picked.path);
  }

  /// 上传图片，返回 (fileID, 临时访问链接)
  ///
  /// 失败自动重试最多 3 次（手机网络抖动较常见）。
  Future<(String, String)> uploadMealImage({
    required File file,
    required String roomId,
    required String deviceId,
  }) async {
    final ext = _extension(file.path);
    // 文件名带房间与设备信息，便于在控制台排查
    final name = '${AppConfig.storageDir}/$roomId/$deviceId/'
        '${DateTime.now().millisecondsSinceEpoch}.$ext';
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await TcbService.uploadFile(name, file);
      } catch (e) {
        lastError = e;
        debugPrint('图片上传失败（第 ${attempt + 1} 次）：$e');
        await Future<void>.delayed(Duration(seconds: 1 + attempt));
      }
    }
    throw Exception('图片上传失败：$lastError');
  }

  /// 删除云存储文件（失败不抛出，避免阻塞记录删除）
  Future<void> deleteImage(String? fileId) => TcbService.deleteFile(fileId);

  /// 从文件路径取扩展名
  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return 'jpg';
    final ext = path.substring(dot + 1).toLowerCase();
    return (ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'webp')
        ? ext
        : 'jpg';
  }
}
