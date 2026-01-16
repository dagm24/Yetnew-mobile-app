import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class StorageUploadService {
  StorageUploadService(this._storage);

  final FirebaseStorage _storage;

  Future<String> uploadHouseholdImage({
    required String householdId,
    required String folder,
    required Uint8List bytes,
    required String filename,
  }) async {
    final ref = _storage
        .ref()
        .child('households')
        .child(householdId)
        .child(folder)
        .child(filename);

    final upload = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return upload.ref.getDownloadURL();
  }
}
