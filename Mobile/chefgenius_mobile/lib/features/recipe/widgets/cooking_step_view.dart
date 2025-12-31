import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../app/data/providers/language_provider.dart';
import '../../../app/data/providers/notification_provider.dart';

class CookingStepView extends StatefulWidget {
  final String stepText;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback? onTimerFinished;

  const CookingStepView({
    super.key,
    required this.stepText,
    required this.stepIndex,
    required this.totalSteps,
    this.onTimerFinished,
  });

  @override
  State<CookingStepView> createState() => _CookingStepViewState();
}

class _CookingStepViewState extends State<CookingStepView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  VoidCallback? _alarmStopListener;
  Timer? _stepTimer;
  int _remainingSeconds = 0;
  bool _isTimerRunning = false;
  int _timerInitialDuration = 0;
  Duration? _detectedDuration;
  DateTime? _targetEndTime;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final AudioPlayer _alarmPlayer = AudioPlayer();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Register alarm stop listener
    _alarmStopListener = () {
      if (_isTimerRunning || _alarmPlayer.state == PlayerState.playing) {
        _cancelTimer();
      }
    };
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
      notifProvider.addAlarmStopListener(_alarmStopListener!);
    });

    _detectedDuration = _parseDurationFromText(widget.stepText);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _pulseController.forward();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
    if (_alarmStopListener != null) {
      notifProvider.removeAlarmStopListener(_alarmStopListener!);
    }
    _stepTimer?.cancel();
    _pulseController.dispose();
    _alarmPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isTimerRunning && _targetEndTime != null) {
        final now = DateTime.now();
        if (now.isAfter(_targetEndTime!)) {
          _handleTimerFinished();
        } else {
          setState(() {
            _remainingSeconds = _targetEndTime!.difference(now).inSeconds;
          });
        }
      }
    }
  }

  Duration? _parseDurationFromText(String text) {
    final regex = RegExp(
        r'(\d+)\s*(menit|jam|detik|minute|minutes|hour|hours|second|seconds)',
        caseSensitive: false);
    final match = regex.firstMatch(text);

    if (match != null) {
      int value = int.parse(match.group(1)!);
      String unit = match.group(2)!.toLowerCase();
      if (unit.contains('jam') || unit.contains('hour')) {
        return Duration(hours: value);
      }
      if (unit.contains('menit') || unit.contains('minute')) {
        return Duration(minutes: value);
      }
      return Duration(seconds: value);
    }
    return null;
  }

  void _startTimer(Duration duration) {
    _stepTimer?.cancel();
    _pulseController.forward();

    final endTime = DateTime.now().add(duration);

    setState(() {
      _timerInitialDuration = duration.inSeconds;
      _remainingSeconds = duration.inSeconds;
      _isTimerRunning = true;
      _targetEndTime = endTime;
    });

    // 1. Show ongoing notification (countdown in status bar)
    _showOngoingNotification(duration);

    // 2. Schedule main finish notification with ALARM configuration
    _scheduleAlarmNotification(duration);
    
    // 3. Schedule pre-notification (reminder)
    _schedulePreNotification(duration);

    _stepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _handleTimerFinished();
          }
        });
      }
    });
  }

  void _handleTimerFinished() {
    _stepTimer?.cancel();
    _stopTimerLogic();
    _playTimerAlarm();
    // Don't cancel notification here - let it ring until user stops it
  }

  Future<void> _showOngoingNotification(Duration duration) async {
    final int notificationId = widget.stepIndex;
    final endTime = DateTime.now().add(duration).millisecondsSinceEpoch;

    try {
      await _notificationsPlugin.show(
        notificationId,
        'Timer Masak Berjalan ⏱️',
        'Menunggu waktu habis...',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'cooking_timer_channel',
            'Timer Masak',
            channelDescription: 'Notifikasi untuk timer memasak',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            showWhen: true,
            when: endTime,
            usesChronometer: true,
            chronometerCountDown: true,
            largeIcon: const DrawableResourceAndroidBitmap('chef_cei_alarm'),
          ),
          iOS: const DarwinNotificationDetails(subtitle: 'Timer sedang berjalan'),
        ),
      );
      debugPrint('✅ Ongoing notification ditampilkan (ID: $notificationId)');
    } catch (e) {
      debugPrint("❌ Gagal show ongoing notification: $e");
    }
  }

  Future<void> _schedulePreNotification(Duration duration) async {
    final int totalSeconds = duration.inSeconds;
    int reminderOffset = 0;
    String reminderBody = "";

    if (totalSeconds >= 120) {
      reminderOffset = 60;
      reminderBody = "Tinggal 1 menit lagi nih, Chef! Siap-siap ya! ⏱️";
    } else if (totalSeconds > 10) {
      reminderOffset = 10;
      reminderBody = "Tinggal 10 detik lagi! Jangan ditinggal! 🔥";
    } else if (totalSeconds <= 10 && totalSeconds > 3) {
      reminderOffset = 3;
      reminderBody = "3... 2... 1... Siap angkat! 🚀";
    }

    if (reminderOffset > 0) {
      final preNotifId = widget.stepIndex + 1000;
      final triggerDate = tz.TZDateTime.now(tz.local)
          .add(duration - Duration(seconds: reminderOffset));

      if (triggerDate.isBefore(tz.TZDateTime.now(tz.local))) return;

      try {
        await _notificationsPlugin.zonedSchedule(
          preNotifId,
          'Siap-siap Chef! 👨‍🍳',
          reminderBody,
          triggerDate,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'cooking_timer_channel',
              'Timer Masak',
              channelDescription: 'Notifikasi untuk timer memasak',
              importance: Importance.high,
              priority: Priority.high,
              sound: const RawResourceAndroidNotificationSound('kitchen_timer'),
              styleInformation: BigTextStyleInformation(reminderBody),
            ),
            iOS: const DarwinNotificationDetails(sound: 'kitchen_timer.mp3'),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        debugPrint('✅ Pre-notification dijadwalkan (ID: $preNotifId) untuk $triggerDate');
      } catch (e) {
        debugPrint("❌ Gagal schedule pre-notifikasi: $e");
      }
    }
  }

  // ⭐ FUNGSI UTAMA: Schedule alarm notification dengan konfigurasi ALARM PENUH
  Future<void> _scheduleAlarmNotification(Duration duration) async {
    final int notificationId = widget.stepIndex + 2000; // ID berbeda untuk alarm

    // ⭐ KONFIGURASI BIG PICTURE STYLE
    const BigPictureStyleInformation bigPictureStyleInformation =
        BigPictureStyleInformation(
      DrawableResourceAndroidBitmap('chef_cei_alarm'),
      largeIcon: DrawableResourceAndroidBitmap('chef_cei_alarm'),
      contentTitle: '⏰ Waktu Habis, Chef!',
      htmlFormatContentTitle: true,
      summaryText: 'Timer memasak telah selesai. Segera cek masakan Anda!',
      htmlFormatSummaryText: true,
    );

    // ⭐ ANDROID NOTIFICATION DETAILS - FULL ALARM MODE
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'alarm_channel', // ⭐ HARUS SAMA dengan channel di main.dart
      'Alarm Timer',
      channelDescription: 'Notifikasi alarm timer dengan suara custom',
      importance: Importance.max,
      priority: Priority.high,
      
      // ⭐ SUARA & VIBRATION
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('kitchen_timer'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      
      // ⭐ LED
      enableLights: true,
      ledColor: const Color.fromARGB(255, 255, 0, 0),
      ledOnMs: 1000,
      ledOffMs: 500,
      
      // ⭐ STYLE
      styleInformation: bigPictureStyleInformation,
      
      // ⭐ FLAG INSISTENT (4): Suara loop terus sampai user action
      // ⭐ FLAG SHOW_WHEN (8): Tampilkan waktu notifikasi
      additionalFlags: Int32List.fromList(<int>[4, 8]),
      
      // ⭐ KATEGORI & VISIBILITY
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      
      // ⭐ FULL SCREEN INTENT - Muncul bahkan saat locked
      fullScreenIntent: true,
      
      // ⭐ BEHAVIOR
      autoCancel: false, // Jangan auto dismiss
      ongoing: true, // Sticky notification
      showWhen: true,
      usesChronometer: false,
      
      // ⭐ TIMEOUT (opsional - auto dismiss setelah 2 menit jika tidak direspon)
      timeoutAfter: 120000, // 120 detik
      
      // ⭐ ACTION BUTTON
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'stop_alarm',
          'Matikan Alarm',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
      
      // ⭐ TICKER (muncul di status bar saat notif baru)
      ticker: '⏰ Timer Masak Selesai!',
    );

    // ⭐ iOS CONFIGURATION
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      sound: 'kitchen_timer.mp3',
      interruptionLevel: InterruptionLevel.critical, // Bypass Do Not Disturb
      presentAlert: true,
      presentBadge: true,
      presentBanner: true,
      categoryIdentifier: 'alarmCategory',
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      final scheduledTime = tz.TZDateTime.now(tz.local).add(duration);
      
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        '⏰ Timer Selesai!',
        'Langkah ${widget.stepIndex + 1} selesai. Segera cek masakan!',
        scheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      debugPrint('✅ ========== ALARM NOTIFICATION SCHEDULED ==========');
      debugPrint('✅ Scheduled Time: $scheduledTime');
      debugPrint('✅ Notification ID: $notificationId');
      debugPrint('✅ Channel: alarm_channel');
      debugPrint('✅ Sound: kitchen_timer.mp3');
      debugPrint('✅ Flags: INSISTENT (loop) + SHOW_WHEN');
      debugPrint('✅ Full Screen Intent: true');
      debugPrint('✅ ===================================================');
    } catch (e, stackTrace) {
      debugPrint("❌ ========== ALARM SCHEDULING FAILED ==========");
      debugPrint("❌ Error: $e");
      debugPrint("❌ Stack trace: $stackTrace");
      debugPrint("❌ ==============================================");
    }
  }

  Future<void> _cancelNotification() async {
    try {
      // Cancel ongoing notification
      await _notificationsPlugin.cancel(widget.stepIndex);
      debugPrint('✅ Cancelled ongoing notification (ID: ${widget.stepIndex})');
      
      // Cancel pre-notification
      await _notificationsPlugin.cancel(widget.stepIndex + 1000);
      debugPrint('✅ Cancelled pre-notification (ID: ${widget.stepIndex + 1000})');
      
      // Cancel alarm notification
      await _notificationsPlugin.cancel(widget.stepIndex + 2000);
      debugPrint('✅ Cancelled alarm notification (ID: ${widget.stepIndex + 2000})');
    } catch (e) {
      debugPrint('❌ Error cancelling notifications: $e');
    }
  }

  void _cancelTimer() {
    _stepTimer?.cancel();
    _stopTimerLogic();
    _cancelNotification();
    _alarmPlayer.stop();
    if (mounted) setState(() => _remainingSeconds = 0);
    debugPrint('🛑 Timer cancelled by user');
  }

  void _stopTimerLogic() {
    _pulseController.stop();
    _pulseController.reset();
    setState(() {
      _isTimerRunning = false;
      _targetEndTime = null;
    });
  }

  Future<void> _playTimerAlarm() async {
    widget.onTimerFinished?.call();

    try {
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);
      await _alarmPlayer.play(AssetSource('sound/kitchen_timer.mp3'));
      debugPrint('✅ In-app alarm audio started');
    } catch (e) {
      debugPrint("❌ Gagal putar alarm in-app: $e");
    }

    if (!mounted) return;

    final lang = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/Chef_Cei/chef_cei_alarm.png',
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.timer_off, size: 80, color: Colors.red),
            ),
            const SizedBox(height: 16),
            Text(
              lang.getText('time_up_title'),
              style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              lang.getText('time_up_desc'),
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _alarmPlayer.stop();
              _cancelNotification();
              Navigator.pop(context);
              debugPrint('✅ Alarm stopped by user from dialog');
            },
            child: Text(lang.getText('ready_excl'),
                style: const TextStyle(
                    color: Colors.amber, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    ).then((_) {
      _alarmPlayer.stop();
      _cancelNotification();
    });
  }

  Color _getProgressColor(double percent) {
    if (percent > 0.5) return Colors.greenAccent;
    if (percent > 0.2) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _formatTime(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return "${d.inHours} Jam";
    if (d.inMinutes > 0) return "${d.inMinutes} Menit";
    return "${d.inSeconds} Detik";
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white12),
            ),
            child: Text(
              "${lang.getText('step_label')} ${widget.stepIndex + 1}",
              style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.5),
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30),
                    if (!_isTimerRunning)
                      Container(
                        height: 250,
                        width: 250,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
                          ]
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/Chef_Cei/chef_cei_cooking.png',
                            fit: BoxFit.cover,
                            width: 250,
                            height: 250,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.transparent,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.soup_kitchen_rounded,
                                        size: 80,
                                        color: Colors.white.withOpacity(0.5)),
                                    const SizedBox(height: 8),
                                    Text(lang.getText('ready_cook'),
                                        style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.5),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold))
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Text(widget.stepText,
                            key: ValueKey(widget.stepText),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                height: 1.6)),
                      ),
                    ),
                    if (_detectedDuration != null) ...[
                      const SizedBox(height: 40),
                      if (_isTimerRunning) ...[
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                  width: 200,
                                  height: 200,
                                  child: CircularProgressIndicator(
                                      value: 1.0,
                                      strokeWidth: 12,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.grey.withOpacity(0.2)))),
                              SizedBox(
                                width: 200,
                                height: 200,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                      begin: 1,
                                      end: _remainingSeconds /
                                          (_timerInitialDuration == 0
                                              ? 1
                                              : _timerInitialDuration)),
                                  duration: const Duration(seconds: 1),
                                  curve: Curves.linear,
                                  builder: (context, value, _) {
                                    return CircularProgressIndicator(
                                        value: value,
                                        strokeWidth: 12,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                _getProgressColor(value)),
                                        strokeCap: StrokeCap.round);
                                  },
                                ),
                              ),
                              Opacity(
                                opacity: 0.3,
                                child: Image.asset(
                                  'assets/images/Chef_Cei/chefceiguide.png',
                                  width: 120,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const SizedBox(),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_formatTime(_remainingSeconds),
                                      style: const TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: 'monospace',
                                          letterSpacing: 2,
                                          shadows: [
                                            Shadow(
                                                blurRadius: 10,
                                                color: Colors.black)
                                          ])),
                                  Text(lang.getText('time_remaining'),
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                          shadows: [
                                            Shadow(
                                                blurRadius: 5,
                                                color: Colors.black)
                                          ])),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        OutlinedButton.icon(
                            onPressed: _cancelTimer,
                            icon: const Icon(Icons.stop_circle_outlined,
                                color: Colors.redAccent, size: 24),
                            label: Text(lang.getText('cancel_caps'),
                                style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: const StadiumBorder()))
                      ] else ...[
                        Container(
                          margin: const EdgeInsets.only(top: 30),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.05)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8))
                              ],
                              border: Border.all(color: Colors.white10)),
                          child: Column(
                            children: [
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.timer_rounded,
                                        color: Colors.orangeAccent),
                                    const SizedBox(width: 8),
                                    Text(lang.getText('timer_detected'),
                                        style: const TextStyle(
                                            color: Colors.orangeAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            letterSpacing: 1))
                                  ]),
                              const SizedBox(height: 12),
                              Text(_formatDuration(_detectedDuration!),
                                  style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              const SizedBox(height: 16),
                              SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                      onPressed: () =>
                                          _startTimer(_detectedDuration!),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16)),
                                          elevation: 0),
                                      child: Text(
                                          lang.getText('start_countdown'),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)))),
                            ],
                          ),
                        )
                      ]
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}