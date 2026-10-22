// 腾讯云开发（CloudBase）初始化与通用工具
//
// 职责：
// 1. 初始化 CloudBase 环境（envId 见 core/app_config.dart），并匿名登录；
// 2. 封装数据库「查询 / 新增 / 更新 / 删除」，失败时抛出 CloudBaseException；
// 3. 封装云存储「上传 / 获取访问链接 / 删除」；
// 4. 把云开发错误翻译成中文提示。
import 'dart:io';

import 'package:cloudbase_flutter/cloudbase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../core/app_config.dart';

/// 云开发操作异常（带中文提示）
class CloudBaseException implements Exception {
  CloudBaseException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

class TcbService {
  TcbService._();

  static CloudBase? _app;
  static CloudBaseDatabase? _db;
  static CloudBaseStorageFileApi? _storage;

  /// 是否已完成初始化
  static bool get initialized => _app != null;

  /// 匿名登录是否成功（false 时所有数据库/存储请求都会被网关拒绝）
  static bool _signedIn = false;

  /// 最近一次初始化/登录的错误信息（用于界面提示）
  static String? _initError;

  static String? get initError => _initError;

  /// 配置是否填写完整
  static bool get isConfigured =>
      AppConfig.envId.isNotEmpty && !AppConfig.envId.startsWith('请替换');

  static CloudBase get app {
    final a = _app;
    if (a == null) throw CloudBaseException('云开发尚未初始化');
    return a;
  }

  static CloudBaseDatabase get db {
    final d = _db;
    if (d == null) throw CloudBaseException('云开发尚未初始化');
    return d;
  }

  static CloudBaseStorageFileApi get storage {
    final s = _storage;
    if (s == null) throw CloudBaseException('云开发尚未初始化');
    return s;
  }

  /// 初始化（重复调用安全）
  ///
  /// 关键点：云开发网关要求每个请求都带 `Authorization`，
  /// 它来自「匿名登录拿到的 accessToken」或「accessKey」。
  /// 两者都没有时，请求会返回 MISSING_CREDENTIALS，因此这里必须显式报错，
  /// 不能静默吞掉。
  static Future<void> init() async {
    if (_app != null && _signedIn) return;
    if (!isConfigured) {
      _initError = '尚未配置云开发环境 ID，请编辑 lib/core/app_config.dart';
      throw CloudBaseException(_initError!);
    }
    final app = await CloudBase.init(
      env: AppConfig.envId,
      region: AppConfig.region,
      // accessKey 可选：作为匿名登录的兜底凭证
      accessKey: AppConfig.accessKey.isEmpty ? null : AppConfig.accessKey,
    );
    _app = app;
    _db = app.database();
    _storage = app.storage.from();

    // 1. 已有本地会话（之前登录过）直接复用
    try {
      final sessionRes = await app.auth.getSession();
      final token = sessionRes.data?.session?.accessToken;
      if (token != null && token.isNotEmpty) {
        _signedIn = true;
        _initError = null;
        return;
      }
    } catch (e) {
      debugPrint('读取本地会话失败，尝试匿名登录：$e');
    }

    // 2. 没有会话则匿名登录；失败时记录原因，让界面能提示用户
    try {
      final res = await app.auth.signInAnonymously();
      if (res.error != null) {
        throw CloudBaseException(
          _authErrorMessage(res.error!.message ?? ''),
          code: res.error!.code,
        );
      }
      _signedIn = true;
      _initError = null;
    } catch (e) {
      // 如果配置了 accessKey，即使匿名登录失败，请求仍可携带 accessKey
      if (AppConfig.accessKey.isNotEmpty) {
        _signedIn = true;
        _initError = null;
        debugPrint('匿名登录失败，改用 accessKey 访问：$e');
        return;
      }
      _signedIn = false;
      _initError =
          _authErrorMessage(e is CloudBaseException ? e.message : e.toString());
      debugPrint('匿名登录失败：$e');
    }
  }

  /// 把匿名登录失败翻译成可操作的中文提示
  static String _authErrorMessage(String raw) {
    final text = raw.toString();
    if (text.contains('MISSING_CREDENTIALS')) {
      return '云开发凭证缺失：请在控制台开启「匿名登录」，或在 app_config.dart 中填写 accessKey';
    }
    if (text.contains('ANONYMOUS') || text.contains('anonymous')) {
      return '该环境未开启「匿名登录」，请在 云开发控制台 → 身份认证 → 登录方式 中开启';
    }
    if (text.contains('403') || text.contains('Forbidden')) {
      return '匿名登录被拒绝：请确认环境已开启匿名登录，且环境 ID 填写正确';
    }
    if (text.contains('env') &&
        (text.contains('not found') || text.contains('NOT_FOUND'))) {
      return '环境不存在：请检查 app_config.dart 中的 envId 是否与控制台一致';
    }
    return text;
  }

  /// 请求前确保已登录；未登录时抛出可读错误（避免出现英文 MISSING_CREDENTIALS）
  static void _ensureSignedIn() {
    if (!_signedIn && AppConfig.accessKey.isEmpty) {
      throw CloudBaseException(
        _initError ?? '尚未登录云开发：请在控制台开启「匿名登录」后重试',
      );
    }
  }

  // ==================== 数据库 ====================

  /// 执行查询并返回文档列表（出错抛异常）
  static Future<List<Map<String, dynamic>>> find(Query query) async {
    _ensureSignedIn();
    final result = await query.get();
    _check(result.code, result.message);
    return result.data;
  }

  /// 按条件查询
  static Future<List<Map<String, dynamic>>> queryWhere(
    String collection,
    Map<String, dynamic> condition, {
    String? orderField,
    bool desc = false,
    int? limit,
    Map<String, dynamic>? projection,
  }) {
    Query q = db.collection(collection).where(condition);
    if (orderField != null) {
      q = q.orderBy(
          orderField, desc ? OrderDirection.desc : OrderDirection.asc);
    }
    if (limit != null) q = q.limit(limit);
    if (projection != null) q = q.field(projection);
    return find(q);
  }

  /// 按 ID 查询单个文档（不存在返回 null）
  static Future<Map<String, dynamic>?> getById(
    String collection,
    String docId,
  ) async {
    if (docId.isEmpty) return null;
    final list = await queryWhere(collection, {'_id': docId}, limit: 1);
    return list.isEmpty ? null : list.first;
  }

  /// 新增文档，返回新文档 ID
  static Future<String> add(
      String collection, Map<String, dynamic> data) async {
    _ensureSignedIn();
    final result = await db.collection(collection).add(data);
    _check(result.code, result.message);
    final id = result.id;
    if (id == null) throw CloudBaseException('新增失败：未返回文档 ID');
    return id;
  }

  /// 更新单个文档（合并更新），返回实际更新的记录数
  static Future<int> update(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    _ensureSignedIn();
    final result = await db.collection(collection).doc(docId).update(data);
    _check(result.code, result.message);
    return result.updated;
  }

  /// 删除单个文档
  static Future<void> remove(String collection, String docId) async {
    _ensureSignedIn();
    final result = await db.collection(collection).doc(docId).remove();
    _check(result.code, result.message);
  }

  /// 按条件删除（多文档）
  static Future<void> removeWhere(
    String collection,
    Map<String, dynamic> condition,
  ) async {
    _ensureSignedIn();
    final result = await db.collection(collection).where(condition).remove();
    _check(result.code, result.message);
  }

  static void _check(String? code, String? message) {
    if (code != null) {
      throw CloudBaseException(message ?? '云开发请求失败', code: code);
    }
  }

  // ==================== 云存储 ====================

  /// 上传本地图片，返回 (fileID, 可访问的临时链接)
  static Future<(String, String)> uploadFile(
      String cloudPath, File file) async {
    _ensureSignedIn();
    final bytes = await file.readAsBytes();
    final result = await storage.upload(
      cloudPath,
      bytes,
      options: StorageUploadOptions(
        contentType: _mimeType(file.path),
        cacheControl: 'max-age=86400',
      ),
    );
    if (result.error != null) {
      throw CloudBaseException(
        result.error!.message ?? '文件上传失败',
        code: result.error!.code,
      );
    }
    final fileId = result.data?.id;
    if (fileId == null) throw CloudBaseException('文件上传失败：未返回 fileID');
    // 上传后立刻换取一次可访问链接；读取时还会再换（链接会过期）
    String url = '';
    try {
      url = await getTempFileURL(fileId);
    } catch (e) {
      debugPrint('上传后获取链接失败（不影响保存）：$e');
    }
    return (fileId, url);
  }

  /// 获取文件访问链接（临时链接，默认 2 小时）
  static Future<String> getTempFileURL(String fileId) async {
    _ensureSignedIn();
    final result = await storage.getDownloadUrls([fileId], expiresIn: 7200);
    if (result.error != null) {
      throw CloudBaseException(result.error!.message ?? '获取图片链接失败');
    }
    final infos = result.data;
    if (infos == null || infos.isEmpty || infos.first.downloadUrl == null) {
      throw CloudBaseException(
        infos == null || infos.isEmpty
            ? '获取图片链接失败'
            : (infos.first.message ?? '获取图片链接失败'),
      );
    }
    return infos.first.downloadUrl!;
  }

  /// 批量获取文件访问链接，返回 fileID → URL 的映射（失败的条目不会出现在结果里）
  ///
  /// 注意：网关回传的 fileID 可能与请求时不完全一致（例如补全了前缀），
  /// 所以按「下标 + 回传 id」双写，保证调用方用请求时的 fileID 也能查到。
  static Future<Map<String, String>> getTempFileURLs(
      List<String> fileIds) async {
    _ensureSignedIn();
    if (fileIds.isEmpty) return const {};
    final result = await storage.getDownloadUrls(fileIds, expiresIn: 7200);
    if (result.error != null) {
      throw CloudBaseException(result.error!.message ?? '获取图片链接失败');
    }
    final infos = result.data ?? const <StorageDownloadInfo>[];
    final map = <String, String>{};
    for (var i = 0; i < infos.length; i++) {
      final info = infos[i];
      final url = info.downloadUrl;
      if (url == null || url.isEmpty) {
        if (info.message != null) {
          debugPrint('获取图片链接失败：${info.message}');
        }
        continue;
      }
      // 1) 用请求时的 fileID 作为 key（最可靠）
      if (i < fileIds.length) map[fileIds[i]] = url;
      // 2) 同时记录网关回传的 id
      final id = info.fileId;
      if (id != null && id.isNotEmpty) map[id] = url;
    }
    return map;
  }

  /// 删除云存储文件（失败不抛出）
  static Future<void> deleteFile(String? fileId) async {
    if (fileId == null || fileId.isEmpty) return;
    try {
      await storage.remove([fileId]);
    } catch (e) {
      debugPrint('删除云存储文件失败：$e');
    }
  }

  static String _mimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  /// 错误翻译为中文提示
  static String friendlyError(Object error) {
    if (error is CloudBaseException) return error.message;
    final text = error.toString();
    if (text.contains('MISSING_CREDENTIALS')) {
      return '云开发凭证缺失：请在控制台开启「匿名登录」，或在 app_config.dart 中填写 accessKey';
    }
    if (text.contains('SocketException') ||
        text.contains('DioException') ||
        text.contains('HandshakeException') ||
        text.contains('host lookup') ||
        text.contains('Connection')) {
      return '网络连接失败，请检查网络';
    }
    if (text.contains('尚未配置') || text.contains('尚未初始化')) {
      return text.replaceAll('Exception: ', '');
    }
    if (text.contains('permission') ||
        text.contains('Permission') ||
        text.contains('无权限') ||
        text.contains('AUTH') ||
        text.contains('403')) {
      return '没有权限：请在云开发控制台「数据库 → 权限设置」中调整（详见 README）';
    }
    if (text.contains('not exist') || text.contains('collection')) {
      return '集合不存在：请先在控制台创建 room / roomMember / mealRecord / foodLibrary 四个集合';
    }
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }
    return text;
  }
}
