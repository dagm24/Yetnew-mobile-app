import 'package:cloud_firestore/cloud_firestore.dart';

class HouseholdMember {
  HouseholdMember({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedAt,
    this.avatarUrl,
    this.isOnline = false,
  });

  final String userId;
  final String name;
  final String email;
  final String role; // 'admin' or 'member'
  final DateTime joinedAt;
  final String? avatarUrl;
  final bool isOnline;

  factory HouseholdMember.fromMap(Map<String, dynamic> map, String userId) {
    final ts = map['joinedAt'];
    final joinedAt = ts is Timestamp ? ts.toDate() : DateTime.now();
    return HouseholdMember(
      userId: userId,
      name: map['name'] as String? ?? 'Unknown',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'member',
      joinedAt: joinedAt,
      avatarUrl: map['avatarUrl'] as String?,
      isOnline: map['isOnline'] as bool? ?? false,
    );
  }
}

class Household {
  Household({
    required this.id,
    required this.name,
    required this.code,
    required this.createdAt,
    required this.createdBy,
  });

  final String id;
  final String name;
  final String code;
  final DateTime createdAt;
  final String createdBy;
}

class HouseholdService {
  HouseholdService(this._db);

  final FirebaseFirestore _db;

  String _avatarFromName(String? nameOrEmail) {
    final s = (nameOrEmail ?? '').trim();
    if (s.isEmpty) return '?';
    return s[0].toUpperCase();
  }

  Future<String?> _resolveUserName(String userId) async {
    if (userId.trim().isEmpty) return null;
    try {
      final doc = await _db.collection('users').doc(userId).get();
      final data = doc.data();
      if (data == null) return null;
      final name = (data['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) return name;
      final displayName = (data['displayName'] as String?)?.trim();
      if (displayName != null && displayName.isNotEmpty) return displayName;
      final email = (data['email'] as String?)?.trim();
      if (email != null && email.isNotEmpty) return email;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _logActivity({
    required String householdId,
    required String userId,
    required String userName,
    required String userAvatar,
    required String actionType,
    required String itemType,
    required String itemName,
    Map<String, dynamic>? details,
  }) async {
    var resolvedName = userName.trim();
    if (resolvedName.isEmpty || resolvedName.toLowerCase() == 'user') {
      resolvedName = (await _resolveUserName(userId)) ?? resolvedName;
    }
    if (resolvedName.isEmpty) resolvedName = 'Someone';

    var resolvedAvatar = userAvatar.trim();
    if (resolvedAvatar.isEmpty || resolvedAvatar == '?') {
      resolvedAvatar = _avatarFromName(resolvedName);
    }

    await _db
        .collection('households')
        .doc(householdId)
        .collection('activity')
        .add({
          'householdId': householdId,
          'userId': userId,
          'userName': resolvedName,
          'userAvatar': resolvedAvatar,
          'actionType': actionType,
          'itemType': itemType,
          'itemName': itemName,
          'details': details ?? {},
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  Future<String> createHousehold({
    required String userId,
    required String householdName,
    required String userName,
    required String userEmail,
    String? householdCode,
  }) async {
    final now = FieldValue.serverTimestamp();

    // Use the household code as the document id so joining can be a single `get`.
    // Retry a few times to reduce chance of id collision.
    final requestedCode = householdCode?.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9-]'),
      '',
    );

    for (var attempt = 0; attempt < 5; attempt++) {
      final code =
          (attempt == 0 && requestedCode != null && requestedCode.isNotEmpty)
          ? requestedCode
          : _generateHouseholdCode(householdName);
      final householdDoc = _db.collection('households').doc(code);

      final created = await _db.runTransaction<bool>((tx) async {
        final existing = await tx.get(householdDoc);
        if (existing.exists) return false;
        tx.set(householdDoc, {
          'name': householdName,
          'code': code,
          'createdAt': now,
          'createdBy': userId,
        });
        return true;
      });

      if (!created) continue;

      // Add creator as admin member
      await householdDoc.collection('members').doc(userId).set({
        'name': userName,
        'email': userEmail,
        'role': 'admin',
        'joinedAt': now,
        'isOnline': true,
      });

      // Upsert user document with householdId
      await _db.collection('users').doc(userId).set({
        'householdId': householdDoc.id,
        'name': userName,
        'email': userEmail,
        'updatedAt': now,
      }, SetOptions(merge: true));

      await _logActivity(
        householdId: householdDoc.id,
        userId: userId,
        userName: userName,
        userAvatar: _avatarFromName(userName),
        actionType: 'added',
        itemType: 'household',
        itemName: householdName,
        details: {'code': householdDoc.id},
      );

      return householdDoc.id;
    }

    throw StateError('Failed to create household. Please try again.');
  }

  Future<bool> joinHousehold({
    required String userId,
    required String householdCode,
    required String userName,
    required String userEmail,
  }) async {
    final householdId = householdCode.toUpperCase();
    final householdDoc = await _db
        .collection('households')
        .doc(householdId)
        .get();
    if (!householdDoc.exists) return false;

    // Check if already a member
    final memberDoc = await _db
        .collection('households')
        .doc(householdId)
        .collection('members')
        .doc(userId)
        .get();

    if (memberDoc.exists) {
      // Already a member, just update user document
      await _db.collection('users').doc(userId).set({
        'householdId': householdId,
        'name': userName,
        'email': userEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    }

    // Add as member
    await _db
        .collection('households')
        .doc(householdId)
        .collection('members')
        .doc(userId)
        .set({
          'name': userName,
          'email': userEmail,
          'role': 'member',
          'joinedAt': FieldValue.serverTimestamp(),
          'isOnline': true,
        });

    // Update user document
    await _db.collection('users').doc(userId).set({
      'householdId': householdId,
      'name': userName,
      'email': userEmail,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _logActivity(
      householdId: householdId,
      userId: userId,
      userName: userName,
      userAvatar: _avatarFromName(userName),
      actionType: 'joined',
      itemType: 'member',
      itemName: userName,
    );

    return true;
  }

  Future<String?> getUserHouseholdId(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    final householdId = userDoc.data()?['householdId'] as String?;
    if (householdId == null || householdId.trim().isEmpty) return null;

    // Important: Firestore/Storage security rules gate almost everything on
    // `/households/{householdId}/members/{uid}` existing. If the user doc points
    // to a household they are not actually a member of (stale/partial data),
    // the app will see "permission denied" across devices/history/storage.
    try {
      final memberDoc = await _db
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(userId)
          .get();

      if (memberDoc.exists) return householdId;

      // Clean up stale linkage so the app can route to SetupHousehold.
      await _db.collection('users').doc(userId).set({
        'householdId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return null;
    } on FirebaseException catch (e) {
      // If rules are misconfigured/deployed incorrectly, this may throw
      // permission-denied. In that case, we still return the raw householdId so
      // screens can show a more specific error state/log.
      if (e.code == 'permission-denied') return householdId;
      rethrow;
    }
  }

  Future<Household?> getHousehold(String householdId) async {
    final doc = await _db.collection('households').doc(householdId).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    final ts = data['createdAt'];
    final createdAt = ts is Timestamp ? ts.toDate() : DateTime.now();
    return Household(
      id: doc.id,
      name: data['name'] as String? ?? 'Household',
      code: data['code'] as String? ?? '',
      createdAt: createdAt,
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  Stream<List<HouseholdMember>> streamHouseholdMembers(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('members')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => HouseholdMember.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> streamHouseholdActivity(
    String householdId, {
    int limit = 10,
  }) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('activity')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  Future<void> updateMemberOnlineStatus(
    String householdId,
    String userId,
    bool isOnline,
  ) async {
    await _db
        .collection('households')
        .doc(householdId)
        .collection('members')
        .doc(userId)
        .update({'isOnline': isOnline});
  }

  Future<void> removeMember(String householdId, String userId) async {
    final memberRef = _db
        .collection('households')
        .doc(householdId)
        .collection('members')
        .doc(userId);
    final memberSnap = await memberRef.get();
    final memberData = memberSnap.data();
    final memberName = (memberData?['name'] as String?) ?? 'Member';

    await _db
        .collection('households')
        .doc(householdId)
        .collection('members')
        .doc(userId)
        .delete();

    await _logActivity(
      householdId: householdId,
      userId: userId,
      userName: memberName,
      userAvatar: _avatarFromName(memberName),
      actionType: 'removed',
      itemType: 'member',
      itemName: memberName,
    );
    await _db.collection('users').doc(userId).set({
      'householdId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Leaves the household and clears the user's `householdId`.
  ///
  /// If the leaving user is the household owner (`createdBy`) and there are other
  /// members, ownership is transferred to another member (and that member is
  /// promoted to `admin`) to keep the household usable.
  Future<void> leaveHousehold({
    required String householdId,
    required String userId,
  }) async {
    final householdRef = _db.collection('households').doc(householdId);
    final membersRef = householdRef.collection('members');
    final leavingMemberRef = membersRef.doc(userId);
    final userRef = _db.collection('users').doc(userId);

    String leavingName = 'Member';
    String leavingEmail = '';
    bool transferredOwnership = false;

    final householdSnap = await householdRef.get();
    if (!householdSnap.exists) {
      await userRef.set({
        'householdId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    final householdData = householdSnap.data() ?? {};
    final createdBy = (householdData['createdBy'] as String?) ?? '';

    final leavingSnap = await leavingMemberRef.get();
    final leavingData = leavingSnap.data();
    leavingName = (leavingData?['name'] as String?) ?? leavingName;
    leavingEmail = (leavingData?['email'] as String?) ?? leavingEmail;

    final membersSnap = await membersRef.get();
    final otherMembers = membersSnap.docs.where((d) => d.id != userId).toList();

    final batch = _db.batch();
    if (createdBy == userId && otherMembers.isNotEmpty) {
      final newOwner = otherMembers.first;
      batch.update(householdRef, {
        'createdBy': newOwner.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(membersRef.doc(newOwner.id), {
        'role': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transferredOwnership = true;
    }

    batch.delete(leavingMemberRef);
    batch.set(userRef, {
      'householdId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();

    await _logActivity(
      householdId: householdId,
      userId: userId,
      userName: leavingName,
      userAvatar: _avatarFromName(leavingName),
      actionType: transferredOwnership ? 'left (owner transferred)' : 'left',
      itemType: 'member',
      itemName: leavingName.isNotEmpty ? leavingName : (leavingEmail),
    );
  }

  /// Updates the user's display name in both `users/{userId}` and (if present)
  /// the household member record.
  Future<void> updateProfile({
    required String userId,
    required String name,
    required String email,
    String? householdId,
  }) async {
    final now = FieldValue.serverTimestamp();
    await _db.collection('users').doc(userId).set({
      'name': name,
      'email': email,
      'updatedAt': now,
    }, SetOptions(merge: true));

    final hid = householdId?.trim();
    if (hid != null && hid.isNotEmpty) {
      await _db
          .collection('households')
          .doc(hid)
          .collection('members')
          .doc(userId)
          .set({
            'name': name,
            'email': email,
            'updatedAt': now,
          }, SetOptions(merge: true));
    }
  }

  String _generateHouseholdCode(String name) {
    final year = DateTime.now().year.toString().substring(2); // Last 2 digits
    final namePart = name.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final cleanName = namePart.length > 4
        ? namePart.substring(0, 4)
        : namePart.padRight(4, 'X');
    final random = (DateTime.now().millisecondsSinceEpoch % 10000)
        .toString()
        .padLeft(4, '0');
    final randomPart = random.substring(0, 2);
    return 'YN-$cleanName$year-$randomPart';
  }
}
