import 'dart:developer' as dev;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const storage = FlutterSecureStorage();
  static const _sessionKey = 'SESSION';
  static const _offlineLogsKey = 'OFFLINE_LOGS';

  static Future<void> persistSession(String session) async =>
      storage.write(key: _sessionKey, value: session);

  static Future<String?> getSession() async => storage.read(key: _sessionKey);

  static Future<void> deleteSession() async => storage.delete(key: _sessionKey);

  static Future<void> persistOfflineLogs(String logger) async {
    dev.log('persists offline logs', name: 'SecureStorage.persistOfflineLogs');
    print('persist: $logger');
    storage.write(key: _offlineLogsKey, value: logger);
  }

  static Future<String?> getOfflineLogs() async {
    dev.log('get offline logs', name: 'SecureStorage.getOfflineLogs');
    return storage.read(key: _offlineLogsKey);
  }

  static Future<void> deleteOfflineLogs() async {
    dev.log('delete offline logs', name: 'SecureStorage.deleteOfflineLogs');
    storage.delete(key: _offlineLogsKey);
  }
}
