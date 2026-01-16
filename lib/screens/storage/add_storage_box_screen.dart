import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../../services/device_repository.dart';
import '../../services/household_service.dart';
import '../../theme/app_colors.dart';

class AddStorageBoxScreen extends StatefulWidget {
  const AddStorageBoxScreen({this.boxId, super.key});

  final String? boxId;

  @override
  State<AddStorageBoxScreen> createState() => _AddStorageBoxScreenState();
}

class _AddStorageBoxScreenState extends State<AddStorageBoxScreen> {
  final _repo = DeviceRepository(FirebaseFirestore.instance);
  final _householdService = HouseholdService(FirebaseFirestore.instance);
  final _user = FirebaseAuth.instance.currentUser;
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  String? _imageUrl;
  String? _imageThumbBase64;
  bool _uploadingImage = false;
  String? _selectedLocation;
  int _compartments = 16;
  bool _isLoading = false;
  List<String> _locations = [
    'Living Room',
    'Kitchen',
    'Bedroom',
    'Garage',
    'Workshop',
    'Home Office',
    'Bathroom',
    'Basement',
    'Attic',
  ];

  List<String> _uniqueStrings(List<String> items) {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in items) {
      final s = raw.trim();
      if (s.isEmpty) continue;
      if (seen.add(s)) out.add(s);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    if (widget.boxId != null) {
      _loadBox();
    }
  }

  Future<void> _loadBox() async {
    if (_user?.uid == null || widget.boxId == null) return;
    final householdId = await _householdService.getUserHouseholdId(_user!.uid);
    if (householdId == null) return;
    final box = await _repo.getStorageBox(householdId, widget.boxId!);
    if (box != null && mounted) {
      setState(() {
        _nameController.text = box.label;
        _selectedLocation = box.location.trim();
        _compartments = box.compartments;
        _notesController.text = box.notes ?? '';
        _imageUrl = box.imageUrl;
        _imageThumbBase64 = box.imageThumbBase64;
      });
    }
  }

  Future<String> _toThumbBase64(Uint8List originalBytes) async {
    const targetWidth = 320;
    final codec = await ui.instantiateImageCodec(
      originalBytes,
      targetWidth: targetWidth,
    );
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final pngBytes = byteData?.buffer.asUint8List();
    if (pngBytes == null) {
      throw StateError('Failed to encode thumbnail');
    }
    return base64Encode(pngBytes);
  }

  Future<void> _pickAndUploadImage() async {
    final userId = _user?.uid;
    if (userId == null) return;

    setState(() => _uploadingImage = true);
    try {
      final householdId = await _householdService.getUserHouseholdId(userId);
      if (householdId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No household found. Please set up a household first.',
            ),
          ),
        );
        return;
      }

      XFile? picked;
      if (kIsWeb) {
        final ImagePicker picker = ImagePicker();
        picked = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
      } else {
        picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
      }
      if (picked == null) {
        if (mounted) setState(() => _uploadingImage = false);
        return;
      }

      try {
        final bytes = await picked.readAsBytes();
        final thumbBase64 = await _toThumbBase64(bytes);

        if (!mounted) return;
        setState(() {
          _imageThumbBase64 = thumbBase64;
          _imageUrl = null;
        });

        // If editing an existing box, persist the image immediately so list
        // thumbnails update even if user navigates back.
        if (widget.boxId != null) {
          final user = _user;
          if (user != null) {
            final avatarSource = ((user.displayName ?? user.email) ?? '')
                .trim();
            await _repo.updateStorageBox(
              householdId: householdId,
              boxId: widget.boxId!,
              imageThumbBase64: thumbBase64,
              actorUserId: user.uid,
              actorName: user.displayName ?? user.email,
              actorAvatar: avatarSource.isNotEmpty
                  ? avatarSource.substring(0, 1).toUpperCase()
                  : '?',
            );
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image saved successfully!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        final errorMsg = e.toString();
        final isPermissionError =
            errorMsg.contains('permission-denied') ||
            errorMsg.contains('object-not-found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPermissionError
                  ? 'Image save failed: Permission denied. Please try again.'
                  : 'Image save failed: $errorMsg',
            ),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Only catch errors not already handled above
      if (!mounted) return;
      final errorMsg = e.toString();
      if (!errorMsg.contains('Failed to read image') &&
          !errorMsg.contains('Image save failed')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMsg'),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveBox() async {
    if (_nameController.text.trim().isEmpty || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _user;
      if (user == null) return;
      final userId = user.uid;

      final householdId = await _householdService.getUserHouseholdId(userId);
      if (householdId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No household found. Please set up a household first.',
            ),
          ),
        );
        return;
      }

      if (widget.boxId != null) {
        final avatarSource = ((user.displayName ?? user.email) ?? '').trim();
        await _repo.updateStorageBox(
          householdId: householdId,
          boxId: widget.boxId!,
          label: _nameController.text.trim(),
          location: _selectedLocation!,
          imageUrl: _imageUrl,
          imageThumbBase64: _imageThumbBase64,
          notes: _notesController.text.trim(),
          compartments: _compartments,
          actorUserId: user.uid,
          actorName: user.displayName ?? user.email,
          actorAvatar: avatarSource.isNotEmpty
              ? avatarSource.substring(0, 1).toUpperCase()
              : '?',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage box updated successfully!'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        final avatarSource = ((user.displayName ?? user.email) ?? '').trim();
        await _repo.addStorageBox(
          householdId: householdId,
          label: _nameController.text.trim(),
          location: _selectedLocation!,
          imageUrl: _imageUrl,
          imageThumbBase64: _imageThumbBase64,
          notes: _notesController.text.trim(),
          compartments: _compartments,
          createdBy: user.email,
          actorUserId: user.uid,
          actorName: user.displayName ?? user.email,
          actorAvatar: avatarSource.isNotEmpty
              ? avatarSource.substring(0, 1).toUpperCase()
              : '?',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage box created successfully!'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        final isPermissionError = errorMsg.contains('permission-denied');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPermissionError
                  ? 'Permission denied. Please make sure you are a member of this household.'
                  : 'Error: $errorMsg',
            ),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.deep),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.boxId == null ? 'Add Storage Box' : 'Edit Storage Box',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.deep,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageUpload(),
            const SizedBox(height: 24),
            _buildBoxNameField(),
            const SizedBox(height: 20),
            _buildLocationField(),
            const SizedBox(height: 20),
            _buildCompartmentsField(),
            const SizedBox(height: 20),
            _buildNotesField(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Box Image',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.deep,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _uploadingImage ? null : _pickAndUploadImage,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.purple,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: _uploadingImage
                ? const Center(child: CircularProgressIndicator())
                : ((_imageThumbBase64 != null &&
                          _imageThumbBase64!.trim().isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(
                            base64Decode(_imageThumbBase64!),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : ((_imageUrl != null && _imageUrl!.trim().isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  _imageUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt,
                                    size: 48,
                                    color: AppColors.purple,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to add photo',
                                    style: TextStyle(
                                      color: AppColors.neutral,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ))),
          ),
        ),
      ],
    );
  }

  Widget _buildBoxNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Box Name',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.deep,
              ),
            ),
            Text('*', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'Enter box name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.paleLavender),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.paleLavender),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.purple, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationField() {
    final selected = (_selectedLocation ?? '').trim();
    final locations = _uniqueStrings([
      ..._locations,
      if (selected.isNotEmpty) selected,
    ]);
    final matches = selected.isEmpty
        ? 0
        : locations.where((loc) => loc == selected).length;
    final value = matches == 1 ? selected : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.deep,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            hintText: 'Select location',
            suffixIcon: const Icon(
              Icons.arrow_drop_down,
              color: AppColors.purple,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.paleLavender),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.paleLavender),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.purple, width: 2),
            ),
          ),
          items: locations
              .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
              .toList(),
          onChanged: (value) =>
              setState(() => _selectedLocation = value?.trim()),
        ),
      ],
    );
  }

  Widget _buildCompartmentsField() {
    final gridSize = _getGridSize(_compartments);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Number of Compartments',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.deep,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.paleLavender),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CompartmentButton(
                    icon: Icons.remove,
                    onPressed: () {
                      if (_compartments > 1) {
                        setState(() => _compartments--);
                      }
                    },
                  ),
                  const SizedBox(width: 24),
                  Column(
                    children: [
                      Text(
                        '$_compartments',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deep,
                        ),
                      ),
                      Text(
                        '$gridSize grid',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.neutral,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  _CompartmentButton(
                    icon: Icons.add,
                    onPressed: () {
                      if (_compartments < 100) {
                        setState(() => _compartments++);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Slider(
                value: _compartments.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                activeColor: AppColors.purple,
                inactiveColor: AppColors.paleLavender,
                onChanged: (value) =>
                    setState(() => _compartments = value.toInt()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.deep,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Add any relevant information',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.paleLavender),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.paleLavender),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.purple, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveBox,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.purple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  String _getGridSize(int compartments) {
    final sqrt = (compartments / 2).ceil();
    final cols = sqrt;
    final rows = (compartments / cols).ceil();
    return '$rows x $cols';
  }
}

class _CompartmentButton extends StatelessWidget {
  const _CompartmentButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.purple, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.purple, size: 20),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
