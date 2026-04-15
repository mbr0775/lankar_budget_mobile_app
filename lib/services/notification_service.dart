// lib/services/notification_service.dart
// Placeholder — wire up flutter_local_notifications when needed
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {
    // TODO: Initialize flutter_local_notifications
    print('NotificationService initialized (stub)');
  }

  Future<void> showSyncComplete(int count) async {
    // TODO: Show local notification
    print('Sync complete: $count items synced');
  }

  Future<void> showDailyReminder() async {
    // TODO: Schedule daily notification
  }
}