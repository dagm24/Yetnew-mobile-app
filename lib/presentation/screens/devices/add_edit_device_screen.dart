import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddEditDeviceScreen extends StatefulWidget {
  final String? deviceId;
  const AddEditDeviceScreen({super.key, this.deviceId});

  @override
  State<AddEditDeviceScreen> createState() => _AddEditDeviceScreenState();
}

class _AddEditDeviceScreenState extends State<AddEditDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  final _compartment = TextEditingController();
  String? _storageBoxId;
  String _status = 'working';
  Uint8List? _imageBytes;
  String? _imageUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.deviceId != null) _load();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance.collection('devices').doc(widget.deviceId).get();
    final m = doc.data();
    if (m != null) {
      _name.text = (m['name'] ?? '').toString();
      _category.text = (m['category'] ?? '').toString();
      _location.text = (m['location'] ?? '').toString();
      _status = (m['status'] ?? 'working').toString();
      _imageUrl = m['image_url'] as String?;
      _notes.text = (m['notes'] ?? '').toString();
      _compartment.text = (m['compartment_number'] ?? '').toString();
      _storageBoxId = m['storage_box_id'] as String?;
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (file != null) {
      _imageBytes = await file.readAsBytes();
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      String? imageURL = _imageUrl;
      if (_imageBytes != null) {
        final ref = FirebaseStorage.instance.ref().child('devices/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putData(_imageBytes!, SettableMetadata(contentType: 'image/jpeg'));
        imageURL = await ref.getDownloadURL();
      }
      final data = {
        'name': _name.text.trim(),
        'image_url': imageURL,
        'category': _category.text.trim(),
        'location': _location.text.trim(),
        'status': _status,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'storage_box_id': _storageBoxId,
        'compartment_number': int.tryParse(_compartment.text.trim()),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (widget.deviceId == null) {
        await FirebaseFirestore.instance.collection('devices').add(data);
      } else {
        data.remove('created_at');
        await FirebaseFirestore.instance.collection('devices').doc(widget.deviceId).set(data, SetOptions(merge: true));
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.deviceId == null ? 'Add Device' : 'Edit Device')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    image: _imageBytes != null
                        ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
                        : (_imageUrl != null ? DecorationImage(image: NetworkImage(_imageUrl!), fit: BoxFit.cover) : null),
                  ),
                  child: _imageBytes == null && _imageUrl == null
                      ? const Center(child: Text('Tap to select image'))
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Device Name', prefixIcon: Icon(Icons.edit_outlined)), validator: (v) => v == null || v.isEmpty ? 'Enter name' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _category, decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined))),
              const SizedBox(height: 12),
              TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.place_outlined))),
              const SizedBox(height: 12),
              TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes_outlined))),
              const SizedBox(height: 12),
              TextFormField(controller: _compartment, decoration: const InputDecoration(labelText: 'Compartment Number', prefixIcon: Icon(Icons.grid_view_outlined))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                items: const [
                  DropdownMenuItem(value: 'working', child: Text('Working')),
                  DropdownMenuItem(value: 'needs-repair', child: Text('Needs Repair')),
                  DropdownMenuItem(value: 'broken', child: Text('Broken')),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'working'),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.flag_outlined), labelText: 'Status'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


