import 'dart:async';
import 'package:flutter/services.dart';

class SmartReminderStatus {
  final bool isEnabled;
  final bool hasNotificationListenerPermission;
  final bool hasUsageStatsPermission;

  const SmartReminderStatus({
    required this.isEnabled,
    required this.hasNotificationListenerPermission,
    required this.hasUsageStatsPermission,
  });
}

class MonitoredBank {
  final String package;
  final String name;
  bool isEnabled;

  MonitoredBank({
    required this.package,
    required this.name,
    required this.isEnabled,
  });

  factory MonitoredBank.fromMap(Map<dynamic, dynamic> map) {
    return MonitoredBank(
      package: map['package'] as String,
      name: map['name'] as String,
      isEnabled: map['enabled'] as bool? ?? true,
    );
  }
}

class SmartReminderService {
  static final SmartReminderService _instance = SmartReminderService._internal();
  factory SmartReminderService() => _instance;
  SmartReminderService._internal();

  static const MethodChannel _channel = MethodChannel('com.spendr/smart_reminders');

  final StreamController<Map<String, dynamic>> _promptController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get promptStream => _promptController.stream;

  void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onTransactionPrompt') {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        _promptController.add(data);
      }
    });
  }

  Future<SmartReminderStatus> checkPermissions() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('checkPermissions');
      if (res != null) {
        return SmartReminderStatus(
          isEnabled: res['isEnabled'] as bool? ?? true,
          hasNotificationListenerPermission: res['notificationListener'] as bool? ?? false,
          hasUsageStatsPermission: res['usageStats'] as bool? ?? false,
        );
      }
    } catch (_) {}
    return const SmartReminderStatus(
      isEnabled: false,
      hasNotificationListenerPermission: false,
      hasUsageStatsPermission: false,
    );
  }

  Future<bool> requestNotificationListenerPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestNotificationListenerPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestUsageStatsPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestUsageStatsPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setSmartRemindersEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setSmartRemindersEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  Future<List<MonitoredBank>> getMonitoredBanks() async {
    try {
      final list = await _channel.invokeListMethod<Map<dynamic, dynamic>>('getMonitoredBanks');
      if (list != null) {
        return list.map((item) => MonitoredBank.fromMap(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> setMonitoredBanks(List<String> packages) async {
    try {
      await _channel.invokeMethod('setMonitoredBanks', {'packages': packages});
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getInitialPrompt() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getInitialPrompt');
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return null;
  }

  Future<void> testBankReminder() async {
    try {
      await _channel.invokeMethod('testBankReminder');
    } catch (_) {}
  }
}
