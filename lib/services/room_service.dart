// 房间服务（云开发集合：room + roomMember）
//
// 为什么拆成两个集合：
// 云开发「基础权限」预设里最合适的是「读取全部数据，修改本人数据」，
// 它只允许创建者修改自己创建的文档。如果成员列表存在 room 文档里，
// 伴侣加入时就要去修改“对方创建的”文档 → 会被权限拒绝（表现为加入失败）。
// 所以改为：每个设备在 roomMember 里创建「自己的一条」成员文档，
// 这样加入/退出/改昵称都只操作自己的文档，天然符合权限模型。
//
//   room        { roomCode, creatorDeviceId, createdAt }
//   roomMember  { roomId, roomCode, deviceId, nickname, createdAt }
//
// 兼容：早期版本把成员存在 room.memberList / room.memberNames 里，
// 读取时会把两边合并，老房间仍然可用。
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';
import '../models/models.dart';
import 'tcb_service.dart';

/// 房间操作异常（带中文提示）
class RoomException implements Exception {
  RoomException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RoomService {
  RoomService._();

  static final RoomService instance = RoomService._();

  static const String tableRoom = AppConfig.collectionRoom;
  static const String tableMember = AppConfig.collectionMember;
  static const String _keyRoomId = 'current_room_id';
  static const String _keyRoomCode = 'current_room_code';

  /// 一个房间最多 2 人
  static const int maxMembers = 2;

  final Random _random = Random.secure();

  // ==================== 当前房间 ====================

  /// 读取本地保存的当前房间（未加入时为 null；离线时使用本地缓存兜底）
  Future<Room?> currentRoom() async {
    final prefs = await SharedPreferences.getInstance();
    final roomId = prefs.getString(_keyRoomId);
    if (roomId == null || roomId.isEmpty) return null;
    try {
      final room = await fetchRoom(roomId);
      if (room == null) {
        await _clearLocal();
        return null;
      }
      await _saveLocal(room);
      return room;
    } catch (e) {
      debugPrint('读取当前房间失败（离线？）：$e');
      final code = prefs.getString(_keyRoomCode) ?? '';
      if (code.isEmpty) return null;
      return Room(
        objectId: roomId,
        roomCode: code,
        memberList: const [],
        memberNames: const {},
        createdAt: null,
      );
    }
  }

  Future<void> _saveLocal(Room room) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRoomId, room.objectId);
    await prefs.setString(_keyRoomCode, room.roomCode);
  }

  Future<void> _clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRoomId);
    await prefs.remove(_keyRoomCode);
  }

  // ==================== 创建 / 加入 / 退出 ====================

  /// 生成未被占用的 6 位数字房间密钥（100000~999999）
  Future<String> _generateRoomCode() async {
    for (var i = 0; i < 20; i++) {
      final code = (100000 + _random.nextInt(900000)).toString();
      final list = await TcbService.queryWhere(
        tableRoom,
        {'roomCode': code},
        limit: 1,
      );
      if (list.isEmpty) return code;
    }
    throw RoomException('房间密钥生成失败，请稍后重试');
  }

  /// 创建房间（创建成功后即为当前房间）
  Future<Room> createRoom({
    required String nickname,
    required String deviceId,
  }) async {
    final existing = await currentRoom();
    if (existing != null) {
      throw RoomException('你已经在房间 ${existing.roomCode} 中，请先退出');
    }
    final code = await _generateRoomCode();
    final now = DateTime.now();

    // 1. 房间主体（只有创建者会写）
    final roomId = await TcbService.add(tableRoom, {
      'roomCode': code,
      'creatorDeviceId': deviceId,
      'createdAt': now.toIso8601String(),
    });

    // 2. 自己的成员文档（每个设备各写各的）
    await _addMemberDoc(
      roomId: roomId,
      roomCode: code,
      deviceId: deviceId,
      nickname: nickname,
    );

    final room = Room(
      objectId: roomId,
      roomCode: code,
      memberList: [deviceId],
      memberNames: {deviceId: nickname},
      createdAt: now,
    );
    await _saveLocal(room);
    return room;
  }

  /// 通过房间密钥加入房间
  Future<Room> joinRoom({
    required String nickname,
    required String deviceId,
    required String code,
  }) async {
    final roomCode = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(roomCode)) {
      throw RoomException('请输入 6 位数字房间密钥');
    }

    // 1. 找到房间
    final list = await TcbService.queryWhere(
      tableRoom,
      {'roomCode': roomCode},
      limit: 1,
    );
    if (list.isEmpty) throw RoomException('房间不存在，请检查房间密钥');
    final roomId = docId(list.first);

    // 2. 读取现有成员（roomMember + 兼容旧字段 memberList）
    final members = await _loadMembers(roomId, list.first);
    if (members.containsKey(deviceId)) {
      // 已在该房间中（例如重装后重新加入）：直接进入
      final room = await fetchRoom(roomId);
      if (room == null) throw RoomException('房间不存在，请检查房间密钥');
      await _saveLocal(room);
      return room;
    }
    if (members.length >= maxMembers) {
      throw RoomException('房间已满（最多 $maxMembers 人），无法加入');
    }

    // 3. 写入自己的成员文档（只写自己的，不会被权限拒绝）
    try {
      await _addMemberDoc(
        roomId: roomId,
        roomCode: roomCode,
        deviceId: deviceId,
        nickname: nickname,
      );
    } catch (e) {
      throw RoomException('加入失败：${TcbService.friendlyError(e)}');
    }

    // 4. 并发保护：写入后回查，若超过 2 人立刻撤回自己
    final after = await _loadMembers(roomId, list.first);
    if (after.length > maxMembers) {
      await _removeMemberDocs(roomId: roomId, deviceId: deviceId);
      throw RoomException('房间已满（最多 $maxMembers 人），无法加入');
    }

    final room = await fetchRoom(roomId);
    if (room == null) throw RoomException('房间不存在，请检查房间密钥');
    await _saveLocal(room);
    return room;
  }

  /// 退出当前房间
  Future<void> leaveRoom({
    required Room room,
    required String deviceId,
  }) async {
    try {
      // 1. 删除自己的成员文档（自己的数据，权限允许）
      await _removeMemberDocs(roomId: room.objectId, deviceId: deviceId);

      // 2. 兼容旧数据：若房间主体的 memberList 里还有自己，尝试移除
      //    （只有创建者能改，失败忽略）
      final doc = await TcbService.getById(tableRoom, room.objectId);
      if (doc != null) {
        final legacy = toStringList(doc['memberList']);
        if (legacy.contains(deviceId)) {
          try {
            await TcbService.update(tableRoom, room.objectId, {
              'memberList': legacy.where((id) => id != deviceId).toList(),
            });
          } catch (e) {
            debugPrint('清理旧成员字段失败（可忽略）：$e');
          }
        }
      }
    } catch (e) {
      // 网络异常也允许本地退出，避免用户被困在房间里
      debugPrint('退出房间时请求失败：$e');
    }
    await _clearLocal();
  }

  /// 更新自己的昵称（只改自己的成员文档）
  Future<void> updateNickname({
    required Room room,
    required String deviceId,
    required String nickname,
  }) async {
    try {
      final docs = await TcbService.queryWhere(
        tableMember,
        {'roomId': room.objectId, 'deviceId': deviceId},
        limit: 5,
      );
      for (final d in docs) {
        await TcbService.update(tableMember, docId(d), {'nickname': nickname});
      }
    } catch (e) {
      debugPrint('同步昵称失败：$e');
    }
  }

  /// 读取房间最新数据（不存在返回 null）
  Future<Room?> fetchRoom(String roomId) async {
    final doc = await TcbService.getById(tableRoom, roomId);
    if (doc == null) return null;
    final members = await _loadMembers(roomId, doc);
    return Room(
      objectId: roomId,
      roomCode: toStringValue(doc['roomCode']),
      memberList: members.keys.toList(),
      memberNames: members,
      createdAt: toDate(doc['createdAt']),
    );
  }

  // ==================== 内部方法 ====================

  /// 写入自己的成员文档
  Future<void> _addMemberDoc({
    required String roomId,
    required String roomCode,
    required String deviceId,
    required String nickname,
  }) async {
    await TcbService.add(tableMember, {
      'roomId': roomId,
      'roomCode': roomCode,
      'deviceId': deviceId,
      'nickname': nickname,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// 删除自己的成员文档
  Future<void> _removeMemberDocs({
    required String roomId,
    required String deviceId,
  }) async {
    final docs = await TcbService.queryWhere(
      tableMember,
      {'roomId': roomId, 'deviceId': deviceId},
      limit: 5,
    );
    for (final d in docs) {
      try {
        await TcbService.remove(tableMember, docId(d));
      } catch (e) {
        debugPrint('删除成员文档失败：$e');
      }
    }
  }

  /// 读取房间成员：roomMember 集合 + 旧版 room.memberList 合并
  ///
  /// 返回 deviceId → 昵称
  Future<Map<String, String>> _loadMembers(
    String roomId,
    Map<String, dynamic> roomDoc,
  ) async {
    final result = <String, String>{};

    // 1. 旧版字段（兼容已有房间）
    final legacyIds = toStringList(roomDoc['memberList']);
    final legacyNames = roomDoc['memberNames'];
    if (legacyNames is Map) {
      legacyNames.forEach((k, v) => result[k.toString()] = v.toString());
    }
    for (final id in legacyIds) {
      result.putIfAbsent(id, () => '成员');
    }

    // 2. 新版成员文档（覆盖旧昵称）
    // 集合不存在或网络异常时不影响旧房间使用，只记录日志
    try {
      final docs = await TcbService.queryWhere(
        tableMember,
        {'roomId': roomId},
        orderField: 'createdAt',
        limit: 10,
      );
      for (final d in docs) {
        final id = toStringValue(d['deviceId']);
        if (id.isEmpty) continue;
        result[id] = toStringValue(d['nickname'], fallback: '成员');
      }
    } catch (e) {
      debugPrint('读取 roomMember 失败（集合可能未创建）：$e');
    }
    return result;
  }
}
