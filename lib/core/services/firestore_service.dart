import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Uploads a specific key-value string/primitive to Firestore for the current user.
  /// Silently returns if the user is not logged in.
  static Future<void> uploadData(String key, dynamic data) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _db
            .collection('users')
            .doc(user.uid)
            .collection('data')
            .doc(key)
            .set({
          'value': data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Fail silently so local functionality persists even if offline
        print("Error syncing $key to Firestore: $e");
      }
    }
  }

  /// Downloads all user synced documents from Firestore and writes them back into local SharedPreferences.
  static Future<void> downloadAndRestoreData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _db
          .collection('users')
          .doc(user.uid)
          .collection('data')
          .get();

      if (snapshot.docs.isEmpty) return; // No cloud data exists yet

      final prefs = await SharedPreferences.getInstance();
      for (var doc in snapshot.docs) {
        final key = doc.id;
        final data = doc.data()['value'];

        if (data is String) {
          await prefs.setString(key, data);
        } else if (data is bool) {
          await prefs.setBool(key, data);
        } else if (data is int) {
          await prefs.setInt(key, data);
        } else if (data is double) {
          await prefs.setDouble(key, data);
        } else if (data is List) {
          await prefs.setStringList(key, List<String>.from(data));
        }
      }
    } catch (e) {
      print("Error restoring from Firestore: $e");
    }
  }
  /// Returns a stream of all user data documents for the current user.
  static Stream<QuerySnapshot<Map<String, dynamic>>> getUserDataStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('data')
        .snapshots();
  }
}
