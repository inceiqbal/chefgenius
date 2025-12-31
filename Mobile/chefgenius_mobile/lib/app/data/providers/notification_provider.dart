import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../main.dart' show notificationsPlugin; // FIX: Import plugin global yang sudah diinisialisasi

class NotificationProvider with ChangeNotifier {
  // --- Tambahan untuk alarm timer masak ---
  final List<VoidCallback> _alarmStopListeners = [];

  void addAlarmStopListener(VoidCallback cb) {
    _alarmStopListeners.add(cb);
  }

  void removeAlarmStopListener(VoidCallback cb) {
    _alarmStopListeners.remove(cb);
  }

  void notifyAlarmStopped() {
    for (final cb in List<VoidCallback>.from(_alarmStopListeners)) {
      cb();
    }
  }

  final _supabase = Supabase.instance.client;
  // FIX: Hapus instance lokal, gunakan plugin global dari main.dart
  int _unreadCount = 0;
  RealtimeChannel? _subscription;

  int get unreadCount => _unreadCount;

  void init() {
    debugPrint('[NOTIF] NotificationProvider.init() called');
    _fetchUnreadCount();
    _subscribeToNotifications();
  }

  /// Reset provider state - call this on logout
  void reset() {
    debugPrint('[NOTIF] NotificationProvider.reset() called');
    _subscription?.unsubscribe();
    _subscription = null;
    _unreadCount = 0;
    notifyListeners();
  }

  /// Reinitialize for new user - call this after login with different account
  void reinit() {
    debugPrint('[NOTIF] NotificationProvider.reinit() called');
    // First reset old state
    reset();
    // Then init for new user
    _fetchUnreadCount();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  /// Refresh unread count - can be called from outside
  Future<void> refreshUnreadCount() async {
    await _fetchUnreadCount();
  }

  Future<void> _fetchUnreadCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      debugPrint('[NOTIF] _fetchUnreadCount() for user: $userId');
      
      // FIX: Supabase Flutter SDK .count() returns PostgrestResponse, not int directly
      // We need to use .select() with head:true and count option, or just count the list
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      
      final count = (response as List).length;
      debugPrint('[NOTIF] _fetchUnreadCount count: $count');
      _unreadCount = count;
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching notification count: $e");
    }
  }

  void _subscribeToNotifications() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    debugPrint('[NOTIF] Subscribing to realtime channel for user: $userId');
    _subscription = _supabase.channel('public:notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            try {
              debugPrint('[NOTIF] Realtime payload eventType=${payload.eventType} newRecord=${payload.newRecord} oldRecord=${payload.oldRecord}');
              await _fetchUnreadCount();

              // Handle Local Notification for INSERT
              if (payload.eventType == PostgresChangeEvent.insert) {
                final newRecord = payload.newRecord;
                await _showLocalNotification(newRecord);
              }
            } catch (e) {
              debugPrint('[NOTIF] Error in realtime callback: $e');
            }
          },
        )
        .subscribe();
  }

  Future<void> _showLocalNotification(Map<String, dynamic> record) async {
    try {
      final message = record['message'] ?? 'Ada aktivitas baru';
      final actorId = record['actor_id'];
      String title = 'ChefGenius';

      if (actorId != null) {
        final actorRes = await _supabase
            .from('profiles')
            .select('username')
            .eq('id', actorId)
            .maybeSingle();
        if (actorRes != null) {
          title = actorRes['username'] ?? 'Seseorang';
        }
      }

      const androidDetails = AndroidNotificationDetails(
        'chefgenius_channel', 
        'ChefGenius Notifications',
        importance: Importance.max,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);
      
      await notificationsPlugin.show(
        record['id'].hashCode,
        title,
        message,
        details,
      );
    } catch (e) {
      debugPrint("Gagal tampilkan notifikasi lokal: $e");
    }
  }

  Future<void> markAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
      
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint("Error marking notifications as read: $e");
    }
  }
}