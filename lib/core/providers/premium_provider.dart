import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';

class PremiumProvider extends ChangeNotifier {
  bool _isPremiumActive = false;
  DateTime? _premiumExpiryDate;
  int _remainingUploads = 0; // Removed free uploads, users must pay or watch an ad

  bool get isPremiumActive => _isPremiumActive;
  DateTime? get premiumExpiryDate => _premiumExpiryDate;
  int get remainingUploads => _remainingUploads;

  /// Returns true if the user can either upload for free (has uses left) or is currently Premium.
  bool get canUpload => _isPremiumActive || _remainingUploads > 0;

  PremiumProvider() {
    _loadState();
    _startFirestoreListener();
  }

  void _startFirestoreListener() {
    FirestoreService.getUserDataStream().listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      bool changed = false;

      for (var doc in snapshot.docs) {
        final key = doc.id;
        final data = doc.data()['value'];

        if (key == 'remaining_uploads' && data is int) {
          if (_remainingUploads != data) {
            _remainingUploads = data;
            await prefs.setInt(key, data);
            changed = true;
          }
        } else if (key == 'premium_expiry_date' && data is String) {
          final expiryDate = DateTime.tryParse(data);
          if (expiryDate != null) {
            _premiumExpiryDate = expiryDate;
            await prefs.setString(key, data);
            
            bool nowActive = expiryDate.isAfter(DateTime.now());
            if (_isPremiumActive != nowActive) {
              _isPremiumActive = nowActive;
              changed = true;
            }
          }
        }
      }

      if (changed) {
        notifyListeners();
      }
    });
  }

  Future<void> refresh() async {
    await _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();

    // Check remaining uploads (default 0)
    _remainingUploads = prefs.getInt('remaining_uploads') ?? 0;

    // Check if they have an active subscription
    final expiryStr = prefs.getString('premium_expiry_date');
    if (expiryStr != null) {
      _premiumExpiryDate = DateTime.tryParse(expiryStr);
      if (_premiumExpiryDate != null &&
          _premiumExpiryDate!.isAfter(DateTime.now())) {
        _isPremiumActive = true;
      } else {
        _isPremiumActive = false; // Expired
      }
    } else {
      _isPremiumActive = false;
    }

    notifyListeners();
  }

  /// Deducts exactly one upload, only if the user isn't currently a Premium subscriber.
  Future<void> consumeUpload() async {
    if (_isPremiumActive) return; // Unlimited!

    if (_remainingUploads > 0) {
      _remainingUploads--;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('remaining_uploads', _remainingUploads);
      FirestoreService.uploadData('remaining_uploads', _remainingUploads);
      notifyListeners();
    }
  }

  /// Called upon a successful Paystack checkout for a "Pack" of uploads (e.g., 10 Uploads Pack)
  Future<void> addUploads(int count) async {
    _remainingUploads += count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('remaining_uploads', _remainingUploads);
    FirestoreService.uploadData('remaining_uploads', _remainingUploads);
    notifyListeners();
  }

  /// Called upon a successful Paystack checkout for a "Subscription" (e.g. Monthly / Yearly)
  Future<void> setPremiumSubscription(Duration duration) async {
    // Extend duration if already active, else start from now
    DateTime baseDate = _isPremiumActive && _premiumExpiryDate != null
        ? _premiumExpiryDate!
        : DateTime.now();

    _premiumExpiryDate = baseDate.add(duration);
    _isPremiumActive = true;

    final prefs = await SharedPreferences.getInstance();
    final expiryStr = _premiumExpiryDate!.toIso8601String();
    await prefs.setString('premium_expiry_date', expiryStr);
    FirestoreService.uploadData('premium_expiry_date', expiryStr);

    notifyListeners();
  }
}
