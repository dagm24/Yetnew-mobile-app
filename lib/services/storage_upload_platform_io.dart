import 'dart:io';
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
  final ref = storage
      .ref()
      .child('households')
      .child(householdId)
      .child(folder)
      .child(filename);

  final SettableMetadata metadata = SettableMetadata(contentType: contentType);

  TaskSnapshot upload;
  final path = (filePath ?? '').trim();
  if (path.isNotEmpty) {
    upload = await ref.putFile(File(path), metadata);
  } else if (bytes != null) {
    upload = await ref.putData(bytes, metadata);
  } else {
    throw ArgumentError('filePath or bytes is required');
  }

  return upload.ref.getDownloadURL();
}
