/// 本地数据库引擎占位符
/// 待 IM 模块开发时，将在此处接入 Drift (SQLite) 或 Isar 引擎
class LocalDbEngine {
  static final LocalDbEngine _instance = LocalDbEngine._internal();

  factory LocalDbEngine() {
    return _instance;
  }

  LocalDbEngine._internal();

  Future<void> init() async {
    // 数据库初始化逻辑
  }
}
