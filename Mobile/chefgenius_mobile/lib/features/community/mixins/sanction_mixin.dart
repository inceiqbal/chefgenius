import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../main.dart'; // Import notificationsPlugin

mixin SanctionMixin<T extends StatefulWidget> on State<T> {
  final supabase = Supabase.instance.client;
  DateTime? sanctionEndTime;
  Timer? _sanctionTimer;

  @override
  void dispose() {
    _sanctionTimer?.cancel();
    super.dispose();
  }

  // --- HELPER: CEK STATUS SANKSI ---
  Future<bool> checkRestriction(String action) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final response = await supabase
          .from('profiles')
          .select('warning_level, sanction_end_time')
          .eq('id', userId)
          .single();
      
      final level = response['warning_level'] as int? ?? 0;
      final endTimeStr = response['sanction_end_time'] as String?;
      
      // PERBAIKAN: Jika level 0 (admin batalkan sanksi), langsung izinkan
      if (level == 0) {
        // Bersihkan UI timer jika ada
        if (mounted && sanctionEndTime != null) {
          setState(() => sanctionEndTime = null);
          _sanctionTimer?.cancel();
        }
        return false; // Tidak ada pembatasan
      }
      
      DateTime? endTime;
      if (endTimeStr != null) {
        endTime = DateTime.parse(endTimeStr).toLocal();
        
        // Cek SharedPreferences untuk status notifikasi sanksi selesai
        final prefs = await SharedPreferences.getInstance();
        final lastHandledTimeStr = prefs.getString('last_sanction_end_handled');
        final lastHandledTime = lastHandledTimeStr != null ? DateTime.parse(lastHandledTimeStr) : null;

        if (DateTime.now().isAfter(endTime)) {
          // Sanksi sudah lewat
          
          // AUTO-RESET DB: Pastikan level jadi 0 agar RLS tidak memblokir
          try {
             await supabase.from('profiles').update({
               'warning_level': 0,
               'sanction_end_time': null,
             }).eq('id', userId);
          } catch (e) {
             debugPrint("Gagal reset sanksi otomatis: $e");
          }

          // Jika belum pernah ditampilkan dialog/notif untuk waktu berakhir ini
          if (lastHandledTime == null || lastHandledTime.isBefore(endTime)) {
             if (mounted) {
                showSanctionOverDialog();
                showSanctionOverNotification();
                // Tandai sudah ditangani
                await prefs.setString('last_sanction_end_handled', endTime.toIso8601String());
             }
          }

          if (mounted && sanctionEndTime != null) {
             setState(() => sanctionEndTime = null);
          }
          return false; 
        } else {
          // Sanksi masih berjalan, jadwalkan notifikasi
          scheduleSanctionNotification(endTime);
        }
      }

      // Update State untuk UI AppBar
      if (mounted) {
        if (endTime != null) {
          setState(() => sanctionEndTime = endTime);
          startSanctionTimer();
        } else if (level == 0 && sanctionEndTime != null) {
          // Jika level 0 dan endTime null (misal dicabut admin), bersihkan timer
          setState(() => sanctionEndTime = null);
          _sanctionTimer?.cancel();
        }
      }

      if (action == 'check_only') return false;

      // Level 3: BANNED
      if (level >= 3) {
        if (mounted) showBannedDialog();
        return true; 
      }

      // Level 2: Read Only
      if (level >= 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cuma bisa baca dulu ya, lagi kena sanksi nih."), backgroundColor: Colors.orange),
          );
        }
        return true; 
      }

      // Level 1: No Upload, Like, Comment, AI.
      if (level >= 1) {
        if (action == 'save') return false; 
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Fitur ini lagi istirahat sebentar ya (Sanksi Level 1)."), backgroundColor: Colors.orange),
          );
        }
        return true; 
      }

      return false; 
    } catch (e) {
      debugPrint("Gagal cek status user: $e");
      return false; 
    }
  }

  void startSanctionTimer() {
    _sanctionTimer?.cancel();
    _sanctionTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (mounted) {
        if (sanctionEndTime != null && DateTime.now().isAfter(sanctionEndTime!)) {
          // Simpan referensi waktu sebelum di-null-kan
          final finishedTime = sanctionEndTime!;
          
          setState(() {
            sanctionEndTime = null;
            timer.cancel();
          });
          
          showSanctionOverDialog();
          showSanctionOverNotification();
          
          // Simpan ke prefs agar tidak muncul lagi saat restart app
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_sanction_end_handled', finishedTime.toIso8601String());
          
        } else {
          setState(() {});
        }
      }
    });
  }
  
  // Helper untuk load gambar aset ke file sementara (untuk notifikasi)
  Future<String> getImageFilePathFromAssets(String asset) async {
    final byteData = await rootBundle.load(asset);
    final file = File('${(await getTemporaryDirectory()).path}/${asset.split('/').last}');
    await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    return file.path;
  }

  Future<void> showSanctionOverNotification() async {
    try {
      final String largeIconPath = await getImageFilePathFromAssets('assets/images/Chef_Cei/chef_cei_alarm.png');
      
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'sanction_channel',
        'Sanksi Akun',
        channelDescription: 'Notifikasi terkait status sanksi akun',
        importance: Importance.max,
        priority: Priority.high,
        largeIcon: FilePathAndroidBitmap(largeIconPath),
        styleInformation: BigPictureStyleInformation(
          FilePathAndroidBitmap(largeIconPath),
          contentTitle: '<b>Sanksi Selesai!</b>',
          htmlFormatContentTitle: true,
          summaryText: 'Akun kamu sudah pulih. Yuk masak lagi! 🍳',
          htmlFormatSummaryText: true,
        ),
      );
      
      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await notificationsPlugin.show(
        888, // ID unik untuk notifikasi sanksi selesai
        'Hore! Sanksi Selesai!',
        'Akun kamu udah bersih lagi nih. Yuk, mulai masak dan berbagi lagi dengan bijak ya! 🍳✨',
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint("Gagal menampilkan notifikasi sanksi: $e");
    }
  }

  Future<void> scheduleSanctionNotification(DateTime endTime) async {
    try {
      final String largeIconPath = await getImageFilePathFromAssets('assets/images/Chef_Cei/chef_cei_alarm.png');
      
      await notificationsPlugin.zonedSchedule(
        888,
        'Hore! Sanksi Selesai!',
        'Akun kamu udah bersih lagi nih. Yuk, mulai masak dan berbagi lagi dengan bijak ya! 🍳✨',
        tz.TZDateTime.from(endTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'sanction_channel',
            'Sanksi Akun',
            channelDescription: 'Notifikasi terkait status sanksi akun',
            importance: Importance.max,
            priority: Priority.high,
            largeIcon: FilePathAndroidBitmap(largeIconPath),
            styleInformation: BigPictureStyleInformation(
              FilePathAndroidBitmap(largeIconPath),
              contentTitle: '<b>Sanksi Selesai!</b>',
              htmlFormatContentTitle: true,
              summaryText: 'Akun kamu sudah pulih. Yuk masak lagi! 🍳',
              htmlFormatSummaryText: true,
            ),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
       debugPrint("Gagal menjadwalkan notifikasi: $e");
    }
  }

  void showSanctionOverDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/Chef_Cei/chef_cei_alarm.png', height: 100),
            const SizedBox(height: 16),
            const Text(
              "Hore! Sanksi Selesai!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Akun kamu udah bersih lagi nih. Yuk, mulai masak dan berbagi lagi dengan bijak ya! 🍳✨",
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Siap, Chef!"),
          ),
        ],
      ),
    );
  }

  String formatRemainingTime() {
    if (sanctionEndTime == null) return '';
    final duration = sanctionEndTime!.difference(DateTime.now());
    if (duration.isNegative) return '';

    if (duration.inDays > 0) {
      return '${duration.inDays} hari ${duration.inHours % 24} jam lagi';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} jam ${duration.inMinutes % 60} menit lagi';
    } else {
      return '${duration.inMinutes} menit lagi';
    }
  }

  void showBannedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("AKUN DIBEKUKAN", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 60, color: Colors.red),
            SizedBox(height: 16),
            Text("Akun Anda telah melanggar pedoman komunitas berulang kali (Level 3)."),
            SizedBox(height: 8),
            Text("Anda tidak dapat melakukan aktivitas apapun."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              showAppealDialog();
            },
            child: const Text("Ajukan Banding"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  void showAppealDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ajukan Banding"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Jelaskan kenapa akun Anda harus dipulihkan:"),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              
              Navigator.pop(ctx);
              try {
                await supabase.from('appeals').insert({
                  'user_id': supabase.auth.currentUser!.id,
                  'reason': reason,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Banding udah dikirim! Tunggu kabar dari Chef Cei ya.")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Yah, gagal kirim banding. Coba lagi nanti ya!")));
                }
              }
            },
            child: const Text("Kirim"),
          ),
        ],
      ),
    );
  }
}
