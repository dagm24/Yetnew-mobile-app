import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

Future<String> uploadHouseholdImagePlatform({
  required FirebaseStorage storage,
  required String householdId,
  required String folder,
  required String filename,
  String contentType = 'image/jpeg',
  Uint8List? bytes,
  String? filePath,
}) async {
  if (bytes == null) {
    throw ArgumentError('bytes is required on this platform');
  }

  final ref = storage
      .ref()
      .child('households')
      .child(householdId)
      .child(folder)
      .child(filename);

  final upload = await ref.putData(
    bytes,
    SettableMetadata(contentType: contentType),
  );

  return upload.ref.getDownloadURL();
}
