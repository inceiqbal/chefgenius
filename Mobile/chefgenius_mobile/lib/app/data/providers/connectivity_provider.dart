import 'platform_stub_io.dart' if (dart.library.html) 'platform_stub_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOffline = false;
  bool get isOffline => _isOffline;
  bool _hasError = false; // Track jika ada error platform

  ConnectivityProvider() {
    // Cek koneksi pertama kali pas provider ini dibuat
    _checkInitialConnectivity();
  }

  // Cek koneksi awal
  Future<void> _checkInitialConnectivity() async {
    // Skip connectivity check di Windows karena sering error
    if (isWindows) {
      debugPrint("⚠️ Windows detected - skipping connectivity_plus (assume online)");
      _isOffline = false;
      _hasError = true;
      return;
    }
    
    try {
      final result = await Connectivity().checkConnectivity();
      _updateConnectivityStatus(result);
    } on PlatformException catch (e) {
      // Handle error di platform yang tidak support
      debugPrint("⚠️ Connectivity check error: $e");
      // Assume online jika tidak bisa cek
      _isOffline = false;
      _hasError = true;
    }
  }

  // Mulai ngedengerin perubahan koneksi
  void init() {
    // Skip di Windows
    if (isWindows || _hasError) {
      debugPrint("⚠️ Skipping connectivity listener (Windows or previous error)");
      return;
    }
    
    try {
      Connectivity().onConnectivityChanged.listen(
        (result) {
          _updateConnectivityStatus(result);
        },
        onError: (error) {
          // Handle stream error
          debugPrint("⚠️ Connectivity stream error: $error");
          _isOffline = false; // Assume online on error
          _hasError = true;
          notifyListeners();
        },
      );
    } on PlatformException catch (e) {
      debugPrint("⚠️ Connectivity init error: $e");
      _hasError = true;
    }
  }

  void _updateConnectivityStatus(List<ConnectivityResult> results) {
    // Kalo hasilnya 'none' (gak ada wifi, gak ada data seluler), berarti offline
    if (results.contains(ConnectivityResult.none)) {
      if (!_isOffline) {
        _isOffline = true;
        debugPrint("STATUS KONEKSI: OFFLINE");
        notifyListeners();
      }
    } else {
      // Kalo ada koneksi (wifi, data, dll), berarti online
      if (_isOffline) {
        _isOffline = false;
        debugPrint("STATUS KONEKSI: ONLINE");
        notifyListeners();
      }
    }
  }
}