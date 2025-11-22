import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOffline = false;
  bool get isOffline => _isOffline;

  ConnectivityProvider() {
    // Cek koneksi pertama kali pas provider ini dibuat
    _checkInitialConnectivity();
  }

  // Cek koneksi awal
  Future<void> _checkInitialConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectivityStatus(result);
  }

  // Mulai ngedengerin perubahan koneksi
  void init() {
    Connectivity().onConnectivityChanged.listen((result) {
      _updateConnectivityStatus(result);
    });
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