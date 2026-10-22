// 设备身份服务
//
// 免注册模式：不再有账号密码，用「安卓设备唯一标识」作为用户身份凭证。
//
// 说明：
// - 优先使用 Android ID（Android 8.0+ 上同一应用签名、同一设备内保持稳定，
//   恢复出厂设置或卸载重装会变化）；
// - 再拼接设备型号、制造商生成最终 deviceId，避免不同设备 Android ID 碰撞；
// - 结果会缓存到本地，卸载重装后若 Android ID 不变则身份不变。
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  DeviceService._();

  static final DeviceService instance = DeviceService._();

  static const String _keyDeviceId = 'device_id';
  static const String _keyNickname = 'device_nickname';

  String? _deviceId;
  String? _nickname;

  /// 设备唯一标识（首次调用时计算并缓存）
  Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_keyDeviceId);
    if (cached != null && cached.isNotEmpty) {
      _deviceId = cached;
      return cached;
    }
    final id = await _generateDeviceId();
    await prefs.setString(_keyDeviceId, id);
    _deviceId = id;
    return id;
  }

  /// 已缓存的设备标识（同步读取，未初始化时为 null）
  String? get cachedDeviceId => _deviceId;

  Future<String> _generateDeviceId() async {
    try {
      final info = DeviceInfoPlugin();
      final android = await info.androidInfo;
      final raw = '${android.id}|${android.manufacturer}|${android.model}|'
          '${android.fingerprint}';
      // 简单哈希，避免把原始设备信息直接上传到服务端
      return 'dv_${_hash(raw)}';
    } catch (e) {
      // 非安卓环境（单元测试等）回退到随机 ID，并打印提示
      debugPrint('获取设备信息失败，使用随机设备 ID：$e');
      final ts = DateTime.now().microsecondsSinceEpoch.toString();
      return 'dv_${_hash('$ts|${DateTime.now().timeZoneOffset}')}';
    }
  }

  /// 昵称（每个设备保存一份，用于展示「谁记录了这顿饭」）
  Future<String> getNickname() async {
    if (_nickname != null) return _nickname!;
    final prefs = await SharedPreferences.getInstance();
    _nickname = prefs.getString(_keyNickname) ?? '';
    return _nickname!;
  }

  /// 保存昵称
  Future<void> saveNickname(String nickname) async {
    final name = nickname.trim();
    _nickname = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNickname, name);
  }

  /// 简单的 32 位 FNV-1a 哈希（转 16 进制字符串）
  static String _hash(String input) {
    var hash = 0x811c9dc5;
    for (final code in input.codeUnits) {
      hash ^= code & 0xff;
      hash = (hash * 0x01000193) & 0xffffffff;
      hash ^= (code >> 8) & 0xff;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final second = (hash ^ 0x5bd1e995) & 0xffffffff;
    final part2 = ((second * 0x01000193) & 0xffffffff).toRadixString(16);
    return hash.toRadixString(16).padLeft(8, '0') + part2.padLeft(8, '0');
  }
}
