import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import 'api_service.dart';

class NotificationService extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  Timer? _pollingTimer;
  bool _isInit = false;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  // Initialize and start polling
  void init() {
    if (_isInit) return;
    _isInit = true;
    fetchNotifications();
    // Poll every 30 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchNotifications();
    });
  }

  void stop() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isInit = false;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  Future<void> fetchNotifications() async {
    try {
      final response = await ApiService.get('/api/notifications');
      if (response.containsKey('notifications')) {
        final List<dynamic> data = response['notifications'];
        _notifications = data.map((n) => NotificationModel.fromJson(n)).toList();
        
        // Compute unread count based on fetched array
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to fetch notifications: $e');
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      final response = await ApiService.put('/api/notifications/$id/read', {});
      if (response.containsKey('success')) {
        final index = _notifications.indexWhere((n) => n.id == id);
        if (index != -1) {
          final n = _notifications[index];
          _notifications[index] = NotificationModel(
            id: n.id,
            userId: n.userId,
            title: n.title,
            message: n.message,
            type: n.type,
            isRead: true,
            createdAt: n.createdAt,
          );
          _unreadCount = _notifications.where((n) => !n.isRead).length;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final response = await ApiService.put('/api/notifications/read-all', {});
      if (response.containsKey('success')) {
        _notifications = _notifications.map((n) {
          return NotificationModel(
            id: n.id,
            userId: n.userId,
            title: n.title,
            message: n.message,
            type: n.type,
            isRead: true,
            createdAt: n.createdAt,
          );
        }).toList();
        _unreadCount = 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to mark all notifications as read: $e');
    }
  }
}
