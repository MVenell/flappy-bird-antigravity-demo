import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save score history
  Future<void> saveScore(int score) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _db.collection('scores').add({
        'userId': userId,
        'score': score,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print("Score saved to Firestore: $score");
    } catch (e) {
      print("Error saving score to Firestore: $e");
    }
  }
}
