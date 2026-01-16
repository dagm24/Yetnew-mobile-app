import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLog {
  final String id;
  final String householdId;
  final String userId;
  final String userName;
  final String userAvatar; // Initials or URL
  final String actionType; // 'added', 'moved', 'changed status', 'joined'
  final String itemType; // 'device', 'storage', 'member', 'household'
  final String itemName;
  final Map<String, dynamic> details; // e.g., {'from': 'Living Room', 'to': 'Bedroom'}
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.actionType,
    required this.itemType,
    required this.itemName,
    required this.details,
    required this.timestamp,
  });

  factory ActivityLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityLog(
      id: doc.id,
      householdId: data['householdId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userAvatar: data['userAvatar'] ?? '?',
      actionType: data['actionType'] ?? 'activity',
      itemType: data['itemType'] ?? 'item',
      itemName: data['itemName'] ?? 'Unknown Item',
      details: data['details'] is Map ? data['details'] : {},
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'householdId': householdId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'actionType': actionType,
      'itemType': itemType,
      'itemName': itemName,
      'details': details,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
