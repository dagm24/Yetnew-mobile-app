import 'package:cloud_firestore/cloud_firestore.dart';

enum DeviceStatus { working, needsRepair, broken }

class DeviceRecord {
  DeviceRecord({
    required this.id,
    required this.name,
    required this.status,
    required this.category,
    required this.location,
    required this.updatedAt,
    this.imageUrl,
    this.imageThumbBase64,
    this.notes,
    this.storageBoxId,
    this.compartmentNumber,
    this.lastMaintenanceAt,
    this.createdAt,
    this.createdBy,
  });

  final String id;
  final String name;
  final DeviceStatus status;
  final String category;
  final String location;
  final DateTime updatedAt;
  final String? imageUrl;
  final String? imageThumbBase64;
  final String? notes;
  final String? storageBoxId;
  final int? compartmentNumber;
  final DateTime? lastMaintenanceAt;
  final DateTime? createdAt;
  final String? createdBy;
}

class StorageBox {
  StorageBox({
    required this.id,
    required this.label,
    required this.location,
    this.imageUrl,
    this.imageThumbBase64,
    this.notes,
    this.compartments = 0,
    this.itemCount = 0,
    this.createdAt,
    this.createdBy,
    this.archived = false,
    this.gridRows,
    this.gridCols,
  });

  final String id;
  final String label;
  final String location;
  final String? imageUrl;
  final String? imageThumbBase64;
  final String? notes;
  final int compartments;
  final int itemCount;
  final DateTime? createdAt;
  final String? createdBy;
  final bool archived;
  final int? gridRows;
  final int? gridCols;
}

class DeviceHistoryEntry {
  DeviceHistoryEntry({
    required this.id,
    required this.type,
    required this.message,
    required this.at,
    this.by,
  });

  final String id;
  final String type;
  final String message;
  final DateTime at;
  final String? by;
}

class DeviceRepository {
  DeviceRepository(this._db);

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

  Future<List<DeviceRecord>> getDevices(String householdId) async {
    final snap = await _db
        .collection('households')
        .doc(householdId)
        .collection('devices')
        .orderBy('updatedAt', descending: true)
        .get();
    return snap.docs.map(_fromDoc).toList();
  }

  Future<List<StorageBox>> getStorageBoxes(String householdId) async {
    final snap = await _db
        .collection('households')
        .doc(householdId)
        .collection('storageBoxes')
        .orderBy('label')
        .get();
    return snap.docs.map(_fromStorageDoc).toList();
  }

  Stream<List<DeviceRecord>> streamDevices(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('devices')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  Stream<List<StorageBox>> streamStorageBoxes(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('storageBoxes')
        .orderBy('label')
        .snapshots()
        .map((snap) => snap.docs.map(_fromStorageDoc).toList());
  }

  StorageBox _fromStorageDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return _storageFromMap(doc.data(), doc.id);
  }

  StorageBox _storageFromMap(Map<String, dynamic> data, String id) {
    final createdTs = data['createdAt'];
    final createdAt = createdTs is Timestamp ? createdTs.toDate() : null;
    return StorageBox(
      id: id,
      label: data['label'] as String? ?? 'Storage Box',
      location: data['location'] as String? ?? 'Unknown',
      imageUrl: data['imageUrl'] as String?,
      imageThumbBase64: data['imageThumbBase64'] as String?,
      notes: data['notes'] as String?,
      compartments: (data['compartments'] as int?) ?? 0,
      itemCount: (data['itemCount'] as int?) ?? 0,
      createdAt: createdAt,
      createdBy: data['createdBy'] as String?,
      archived: (data['archived'] as bool?) ?? false,
      gridRows: data['gridRows'] as int?,
      gridCols: data['gridCols'] as int?,
    );
  }

  Future<void> addDevice({
    required String householdId,
    required String name,
    required DeviceStatus status,
    required String category,
    required String location,
    String? imageUrl,
    String? imageThumbBase64,
    String? notes,
    String? storageBoxId,
    String? createdBy,
    int? compartmentNumber,
    DateTime? lastMaintenanceAt,
    String? actorUserId,
    String? actorName,
    String? actorAvatar,
  }) async {
    final now = FieldValue.serverTimestamp();
    final data = {
      'name': name,
      'status': status.name,
      'category': category,
      'location': location,
      'updatedAt': now,
      'createdAt': now,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (imageThumbBase64 != null) 'imageThumbBase64': imageThumbBase64,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (storageBoxId != null && storageBoxId.isNotEmpty)
        'storageBoxId': storageBoxId,
      if (compartmentNumber != null) 'compartmentNumber': compartmentNumber,
      if (lastMaintenanceAt != null)
        'lastMaintenanceAt': Timestamp.fromDate(lastMaintenanceAt),
      if (createdBy != null) 'createdBy': createdBy,
    };
    final deviceRef = await _db
        .collection('households')
        .doc(householdId)
        .collection('devices')
        .add(data);

    await _writeDeviceHistory(
      householdId: householdId,
      deviceId: deviceRef.id,
      type: 'created',
      message: 'Device created',
      by: createdBy,
    );

    // Update storage box item count if stored in a box
    if (storageBoxId != null) {
      await _updateStorageBoxItemCount(householdId, storageBoxId, 1);
    }

    final uid = actorUserId ?? '';
    final uname = (actorName ?? createdBy ?? 'User').trim();
    await _logActivity(
      householdId: householdId,
      userId: uid,
      userName: uname.isEmpty ? 'User' : uname,
      userAvatar: (actorAvatar ?? _avatarFromName(uname)),
      actionType: 'added',
      itemType: 'device',
      itemName: name,
      details: {
        'location': location,
        if (storageBoxId != null && storageBoxId.isNotEmpty)
          'storageBoxId': storageBoxId,
        if (compartmentNumber != null) 'compartmentNumber': compartmentNumber,
        'status': status.name,
      },
    );
  }

  Future<void> updateDevice({
    required String householdId,
    required String deviceId,
    String? name,
    DeviceStatus? status,
    String? category,
    String? location,
    String? imageUrl,
    String? imageThumbBase64,
    String? notes,
    String? storageBoxId,
    int? compartmentNumber,
    DateTime? lastMaintenanceAt,
    String? oldStorageBoxId,
    String? updatedBy,
    String? actorUserId,
    String? actorName,
    String? actorAvatar,
  }) async {
    final before = await getDevice(householdId, deviceId);
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (name != null) data['name'] = name;
    if (status != null) data['status'] = status.name;
    if (category != null) data['category'] = category;
    if (location != null) data['location'] = location;
    if (imageUrl != null) data['imageUrl'] = imageUrl;
    if (imageThumbBase64 != null) data['imageThumbBase64'] = imageThumbBase64;
    if (notes != null) data['notes'] = notes;
    if (storageBoxId != null) {
      if (storageBoxId.isEmpty) {
        data['storageBoxId'] = FieldValue.delete();
        data['compartmentNumber'] = FieldValue.delete();
      } else {
        data['storageBoxId'] = storageBoxId;
      }
    }
    if (compartmentNumber != null) {
      data['compartmentNumber'] = compartmentNumber;
    }
    if (lastMaintenanceAt != null) {
      data['lastMaintenanceAt'] = Timestamp.fromDate(lastMaintenanceAt);
    }
    await _db
        .collection('households')
        .doc(householdId)
        .collection('devices')
        .doc(deviceId)
        .update(data);

    final changed = <String>[];
    if (name != null) changed.add('name');
    if (status != null) changed.add('status');
    if (category != null) changed.add('category');
    if (location != null) changed.add('location');
    if (imageUrl != null) changed.add('photo');
    if (imageThumbBase64 != null) changed.add('photo');
    if (notes != null) changed.add('notes');
    if (storageBoxId != null || oldStorageBoxId != null) changed.add('storage');
    if (compartmentNumber != null) changed.add('compartment');
    if (lastMaintenanceAt != null) changed.add('maintenance');

    await _writeDeviceHistory(
      householdId: householdId,
      deviceId: deviceId,
      type: 'updated',
      message: changed.isEmpty
          ? 'Device updated'
          : 'Updated: ${changed.join(', ')}',
      by: updatedBy,
    );

    // Update storage box item counts
    if (oldStorageBoxId != null && oldStorageBoxId != storageBoxId) {
      await _updateStorageBoxItemCount(householdId, oldStorageBoxId, -1);
    }
    if (storageBoxId != null && storageBoxId != oldStorageBoxId) {
      await _updateStorageBoxItemCount(householdId, storageBoxId, 1);
    }

    final afterName = name ?? before?.name ?? 'Device';
    final uid = actorUserId ?? '';
    final uname = (actorName ?? updatedBy ?? 'User').trim();
    final beforeLocation = before?.location;
    final beforeStatus = before?.status;
    final beforeBox = before?.storageBoxId;
    final beforeCompartment = before?.compartmentNumber;

    String actionType = 'changed';
    final details = <String, dynamic>{};
    if (location != null &&
        beforeLocation != null &&
        location != beforeLocation) {
      actionType = 'moved';
      details['from'] = beforeLocation;
      details['to'] = location;
    } else if (storageBoxId != null && storageBoxId != beforeBox) {
      actionType = 'moved';
      details['from'] = (beforeBox == null || beforeBox.isEmpty)
          ? (beforeLocation ?? 'Unassigned')
          : 'Box $beforeBox';
      details['to'] = (storageBoxId.isEmpty)
          ? (location ?? beforeLocation ?? 'Unassigned')
          : 'Box $storageBoxId';
      if (compartmentNumber != null)
        details['compartmentNumber'] = compartmentNumber;
    } else if (compartmentNumber != null &&
        compartmentNumber != beforeCompartment) {
      actionType = 'moved';
      details['from'] = beforeCompartment == null
          ? 'No compartment'
          : 'Compartment $beforeCompartment';
      details['to'] = 'Compartment $compartmentNumber';
    } else if (status != null &&
        beforeStatus != null &&
        status != beforeStatus) {
      actionType = 'status';
      details['newStatus'] = status.name;
    }

    await _logActivity(
      householdId: householdId,
      userId: uid,
      userName: uname.isEmpty ? 'User' : uname,
      userAvatar: (actorAvatar ?? _avatarFromName(uname)),
      actionType: actionType,
      itemType: 'device',
      itemName: afterName,
      details: details.isEmpty ? null : details,
    );
  }

  Future<void> deleteDevice(
    String householdId,
    String deviceId, {
    String? actorUserId,
    String? actorName,
    String? actorAvatar,
  }) async {
    // Get device to check storage box
    final device = await getDevice(householdId, deviceId);
    if (device?.storageBoxId != null) {
      await _updateStorageBoxItemCount(householdId, device!.storageBoxId!, -1);
    }

    if (device != null) {
      final uid = actorUserId ?? '';
      final uname = (actorName ?? device.createdBy ?? 'User').trim();
      await _logActivity(
        householdId: householdId,
        userId: uid,
        userName: uname.isEmpty ? 'User' : uname,
        userAvatar: (actorAvatar ?? _avatarFromName(uname)),
        actionType: 'deleted',
        itemType: 'device',
        itemName: device.name,
        details: {
          'location': device.location,
          if (device.storageBoxId != null && device.storageBoxId!.isNotEmpty)
            'storageBoxId': device.storageBoxId,
          if (device.compartmentNumber != null)
            'compartmentNumber': device.compartmentNumber,
        },
      );
    }

    await _db
        .collection('households')
        .doc(householdId)
        .collection('devices')
        .doc(deviceId)
        .delete();
  }

  Future<DeviceRecord?> getDevice(String householdId, String deviceId) async {
    final doc = await _db
        .collection('households')
        .doc(householdId)
        .collection('devices')
        .doc(deviceId)
        .get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return _deviceFromMap(data, doc.id);
  }

  Future<void> _updateStorageBoxItemCount(
    String householdId,
    String storageBoxId,
    int delta,
  ) async {
    final boxRef = _db
        .collection('households')
        .doc(householdId)
        .collection('storageBoxes')
        .doc(storageBoxId);
    final boxDoc = await boxRef.get();
    if (boxDoc.exists) {
      final currentCount = (boxDoc.data()?['itemCount'] as int?) ?? 0;
      await boxRef.update({
        'itemCount': (currentCount + delta).clamp(0, double.infinity).toInt(),
      });
    }
  }

  Future<void> addStorageBox({
    required String householdId,
    required String label,
    required String location,
    String? imageUrl,
    String? imageThumbBase64,
    String? notes,
    int compartments = 0,
    String? createdBy,
    String? actorUserId,
    String? actorName,
    String? actorAvatar,
  }) async {
    await _db
        .collection('households')
        .doc(householdId)
        .collection('storageBoxes')
        .add({
          'label': label,
          'location': location,
          'compartments': compartments,
          'itemCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          if (imageUrl != null) 'imageUrl': imageUrl,
          if (imageThumbBase64 != null) 'imageThumbBase64': imageThumbBase64,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (createdBy != null) 'createdBy': createdBy,
        });

    final uid = actorUserId ?? '';
    final uname = (actorName ?? createdBy ?? 'User').trim();
    await _logActivity(
      householdId: householdId,
      userId: uid,
      userName: uname.isEmpty ? 'User' : uname,
      userAvatar: (actorAvatar ?? _avatarFromName(uname)),
      actionType: 'added',
      itemType: 'storage',
      itemName: label,
      details: {'location': location},
    );
  }

  Future<void> updateStorageBox({
    required String householdId,
    required String boxId,
    String? label,
    String? location,
    String? imageUrl,
    String? imageThumbBase64,
    String? notes,
    int? compartments,
    bool? archived,
    int? gridRows,
    int? gridCols,
    String? actorUserId,
    String? actorName,
    String? actorAvatar,
  }) async {
    final before = await getStorageBox(householdId, boxId);
    final data = <String, dynamic>{};
    if (label != null) data['label'] = label;
    if (location != null) data['location'] = location;
    if (imageUrl != null) data['imageUrl'] = imageUrl;
    if (imageThumbBase64 != null) data['imageThumbBase64'] = imageThumbBase64;
    if (notes != null) data['notes'] = notes;
    if (compartments != null) data['compartments'] = compartments;
    if (archived != null) data['archived'] = archived;
    if (gridRows != null) data['gridRows'] = gridRows;
    if (gridCols != null) data['gridCols'] = gridCols;
    await _db
        .collection('households')
        .doc(householdId)
        .collection('storageBoxes')
        .doc(boxId)
        .update(data);

    final uid = actorUserId ?? '';
    final uname = (actorName ?? 'User').trim();
    final actionType =
        (location != null && before != null && location != before.location)
        ? 'moved'
        : 'changed';
    final details = <String, dynamic>{};
    if (actionType == 'moved' && before != null) {
      details['from'] = before.location;
      details['to'] = location;
    }
    if (archived != null) {
      details['archived'] = archived;
    }
    if (compartments != null) {
      details['compartments'] = compartments;
      if (gridRows != null && gridCols != null) {
        details['grid'] = {'rows': gridRows, 'cols': gridCols};
      }
    }

    await _logActivity(
      householdId: householdId,
      userId: uid,
      userName: uname.isEmpty ? 'User' : uname,
      userAvatar: (actorAvatar ?? _avatarFromName(uname)),
      actionType: actionType,
      itemType: 'storage',
      itemName: label ?? before?.label ?? 'Storage Box',
      details: details.isEmpty ? null : details,
    );
  }

  Future<void> removeAllDevicesFromBox({
    required String householdId,
    required String boxId,
    String? actorUserId,
    String? actorName,
    String? actorAvatar,
  }) async {
    final devicesSnap = await _db
        .collection('households')
        .doc(householdId)
        .collection('devices')
        .where('storageBoxId', isEqualTo: boxId)
        .get();

    final batch = _db.batch();
    for (final d in devicesSnap.docs) {
      batch.update(d.reference, {
        'storageBoxId': FieldValue.delete(),
        'compartmentNumber': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    // Reset count to 0
    await _db
        .collection('households')
        .doc(householdId)
        .collection('storageBoxes')
        .doc(boxId)
        .update({'itemCount': 0});

    final box = await getStorageBox(householdId, boxId);
    final uid = actorUserId ?? '';
    final uname = (actorName ?? box?.createdBy ?? 'User').trim();
    await _logActivity(
      householdId: householdId,
      userId: uid,
      userName: uname.isEmpty ? 'User' : uname,
      userAvatar: (actorAvatar ?? _avatarFromName(uname)),
      actionType: 'cleared',
      itemType: 'storage',
      itemName: box?.label ?? 'Storage Box',
      details: {'clearedDevices': devicesSnap.docs.length},
    );
  }

  Stream<List<DeviceHistoryEntry>> streamDeviceHistory(
    String householdId,
    String deviceId,
  ) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('devices')
        .doc(deviceId)
        .collection('history')
        .orderBy('at', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data();
            final atTs = data['at'];
            final at = atTs is Timestamp ? atTs.toDate() : DateTime.now();
            return DeviceHistoryEntry(
              id: doc.id,
              type: data['type'] as String? ?? 'updated',
              message: data['message'] as String? ?? 'Updated',
              at: at,
              by: data['by'] as String?,
            );
          }).toList(),
        );
  }

  Future<void> _writeDeviceHistory({
    required String householdId,
    required String deviceId,
    required String type,
    required String message,
    String? by,
  }) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('devices')
        .doc(deviceId)
        .collection('history')
        .add({
          'type': type,
          'message': message,
          'at': FieldValue.serverTimestamp(),
          if (by != null) 'by': by,
        });
  }

  Future<void> deleteStorageBox(
    String householdId,
    String boxId, {
    String? actorUserId,
    String? actorName,
    String? actorAvatar,
  }) async {
    final box = await getStorageBox(householdId, boxId);

    // Delete all devices in this box
    final devices = await _db
        .collection('households')
        .doc(householdId)
        .collection('devices')
        .where('storageBoxId', isEqualTo: boxId)
        .get();

    final batch = _db.batch();
    for (final device in devices.docs) {
      batch.update(device.reference, {'storageBoxId': FieldValue.delete()});
    }
    await batch.commit();

    if (box != null) {
      final uid = actorUserId ?? '';
      final uname = (actorName ?? box.createdBy ?? 'User').trim();
      await _logActivity(
        householdId: householdId,
        userId: uid,
        userName: uname.isEmpty ? 'User' : uname,
        userAvatar: (actorAvatar ?? _avatarFromName(uname)),
        actionType: 'deleted',
        itemType: 'storage',
        itemName: box.label,
        details: {'location': box.location},
      );
    }

    await _db
        .collection('households')
        .doc(householdId)
        .collection('storageBoxes')
        .doc(boxId)
        .delete();
  }

  Future<StorageBox?> getStorageBox(String householdId, String boxId) async {
    final doc = await _db
        .collection('households')
        .doc(householdId)
        .collection('storageBoxes')
        .doc(boxId)
        .get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return _storageFromMap(data, doc.id);
  }

  Stream<List<DeviceRecord>> streamDevicesInBox(
    String householdId,
    String boxId,
  ) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('devices')
        .where('storageBoxId', isEqualTo: boxId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  DeviceRecord _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return _deviceFromMap(doc.data(), doc.id);
  }

  DeviceRecord _deviceFromMap(Map<String, dynamic> data, String id) {
    final statusString = data['status'] as String? ?? 'working';
    final status = DeviceStatus.values.firstWhere(
      (s) => s.name == statusString,
      orElse: () => DeviceStatus.working,
    );

    final ts = data['updatedAt'];
    final updatedAt = ts is Timestamp ? ts.toDate() : DateTime.now();

    final createdTs = data['createdAt'];
    final createdAt = createdTs is Timestamp ? createdTs.toDate() : null;

    final maintenanceTs = data['lastMaintenanceAt'];
    final lastMaintenanceAt = maintenanceTs is Timestamp
        ? maintenanceTs.toDate()
        : null;

    return DeviceRecord(
      id: id,
      name: data['name'] as String? ?? 'Device',
      status: status,
      category: data['category'] as String? ?? 'General',
      location: data['location'] as String? ?? 'Unknown',
      updatedAt: updatedAt,
      imageUrl: data['imageUrl'] as String?,
      imageThumbBase64: data['imageThumbBase64'] as String?,
      notes: data['notes'] as String?,
      storageBoxId: data['storageBoxId'] as String?,
      compartmentNumber: data['compartmentNumber'] as int?,
      lastMaintenanceAt: lastMaintenanceAt,
      createdAt: createdAt,
      createdBy: data['createdBy'] as String?,
    );
  }
}
