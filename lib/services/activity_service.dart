import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_log.dart';

class ActivityService {
  final FirebaseFirestore _db;

  ActivityService(this._db);

  // Stream activities for a household
  Stream<List<ActivityLog>> streamActivities(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('activity')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ActivityLog.fromFirestore(doc)).toList();
    });
  }

  // Add an activity
  Future<void> logActivity({
    required String householdId,
    required String userId,
    required String userName,
    required String userAvatar,
    required String actionType,
    required String itemType,
    required String itemName,
    Map<String, dynamic>? details,
  }) async {
    await _db
        .collection('households')
        .doc(householdId)
        .collection('activity')
        .add({
      'householdId': householdId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'actionType': actionType,
      'itemType': itemType,
      'itemName': itemName,
      'details': details ?? {},
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
