// CoupleMealLog 应用入口
//
// 启动流程：
// 1. 异步初始化云开发环境（环境 ID 见 core/app_config.dart）；
// 2. 启动 MaterialApp：免注册模式，直接进入「房间选择页」
//    （已加入过房间的设备会直接进入首页）。
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/tcb_service.dart';

Future<void> main() async {
  // 绑定 Flutter 引擎，确保在 runApp 之前可以安全调用插件
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化云开发（数据库 + 云存储 + 匿名登录共用同一个环境）
  try {
    await TcbService.init();
  } catch (e) {
    // 初始化失败不阻塞启动：房间选择页会显示配置提示
    debugPrint('云开发初始化失败：$e');
  }

  runApp(const CoupleMealLogApp());
}
