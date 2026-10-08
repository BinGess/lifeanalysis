import 'package:shared_preferences/shared_preferences.dart';

abstract class LocalStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class DeviceStore implements LocalStore {
  static const key = 'life_guide_native_v1';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw StateError('无法保存');
    }
  }

  @override
  Future<void> clear() async {
    if (!await (await SharedPreferences.getInstance()).remove(key)) {
      throw StateError('无法清空本机记录');
    }
  }
}
