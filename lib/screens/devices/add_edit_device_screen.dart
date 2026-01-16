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
import 'devices_list_screen.dart';

class AddEditDeviceScreen extends StatefulWidget {
  const AddEditDeviceScreen({this.deviceId, super.key});

  final String? deviceId;

  @override
  State<AddEditDeviceScreen> createState() => _AddEditDeviceScreenState();
}

class _AddEditDeviceScreenState extends State<AddEditDeviceScreen> {
  final _repo = DeviceRepository(FirebaseFirestore.instance);
  final _householdService = HouseholdService(FirebaseFirestore.instance);
  final _user = FirebaseAuth.instance.currentUser;
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  String? _imageUrl;
  String? _imageThumbBase64;
  bool _uploadingImage = false;
  String? _selectedCategory;
  String? _selectedLocation;
  DeviceStatus _selectedStatus = DeviceStatus.working;
  String? _selectedStorageBox;
  bool _isLoading = false;
  List<String> _categories = [
    'Power Tools',
    'Hand Tools',
    'Electronics',
    'Appliances',
    'General',
  ];
  List<String> _locations = [
    'Home Office',
    'Garage',
    'Workshop',
    'Living Room',
    'Bedroom',
    'Kitchen',
  ];
  List<StorageBox> _storageBoxes = [];

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
    if (widget.deviceId != null) {
      _loadDevice();
    }
    _loadStorageBoxes();
  }

  Future<void> _loadDevice() async {
    if (_user?.uid == null || widget.deviceId == null) return;
    final householdId = await _householdService.getUserHouseholdId(_user!.uid);
    if (householdId == null) return;
    final device = await _repo.getDevice(householdId, widget.deviceId!);
    if (device != null && mounted) {
      setState(() {
        _nameController.text = device.name;
        _selectedCategory = device.category.trim();
        _selectedLocation = device.location.trim();
        _selectedStatus = device.status;
        _selectedStorageBox = device.storageBoxId;
        _notesController.text = device.notes ?? '';
        _imageUrl = device.imageUrl;
        _imageThumbBase64 = device.imageThumbBase64;
      });
    }
  }

  Future<String> _toThumbBase64(Uint8List originalBytes) async {
    // Keep Firestore doc size safe: generate a small thumbnail.
    // Firestore has a 1 MiB per-document limit.
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
        // On web, use file picker
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

        // If editing an existing device, persist the image immediately so the
        // list thumbnail updates even if user navigates back.
        if (widget.deviceId != null) {
          final user = _user;
          if (user != null) {
            final avatarSource = ((user.displayName ?? user.email) ?? '')
                .trim();
            await _repo.updateDevice(
              householdId: householdId,
              deviceId: widget.deviceId!,
              imageThumbBase64: thumbBase64,
              updatedBy: (user.displayName ?? user.email ?? 'Someone').trim(),
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

  Future<void> _loadStorageBoxes() async {
    if (_user?.uid == null) return;
    final householdId = await _householdService.getUserHouseholdId(_user!.uid);
    if (householdId == null) return;
    final boxes = await _repo.streamStorageBoxes(householdId).first;
    if (mounted) {
      setState(() {
        _storageBoxes = boxes;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveDevice() async {
    if (_nameController.text.trim().isEmpty ||
        _selectedCategory == null ||
        _selectedLocation == null) {
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

      if (widget.deviceId != null) {
        final oldDevice = await _repo.getDevice(householdId, widget.deviceId!);
        final avatarSource = ((user.displayName ?? user.email) ?? '').trim();
        await _repo.updateDevice(
          householdId: householdId,
          deviceId: widget.deviceId!,
          name: _nameController.text.trim(),
          status: _selectedStatus,
          category: _selectedCategory!,
          location: _selectedLocation!,
          imageUrl: _imageUrl,
          imageThumbBase64: _imageThumbBase64,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          storageBoxId: _selectedStorageBox,
          oldStorageBoxId: oldDevice?.storageBoxId,
          updatedBy: (user.displayName ?? user.email ?? 'Someone').trim(),
          actorUserId: user.uid,
          actorName: user.displayName ?? user.email,
          actorAvatar: avatarSource.isNotEmpty
              ? avatarSource.substring(0, 1).toUpperCase()
              : '?',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device updated successfully!'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        final avatarSource = ((user.displayName ?? user.email) ?? '').trim();
        await _repo.addDevice(
          householdId: householdId,
          name: _nameController.text.trim(),
          status: _selectedStatus,
          category: _selectedCategory!,
          location: _selectedLocation!,
          imageUrl: _imageUrl,
          imageThumbBase64: _imageThumbBase64,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          storageBoxId: _selectedStorageBox,
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
              content: Text('Device added successfully!'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
          // Navigate to devices list screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DevicesListScreen()),
          );
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
          icon: const Icon(Icons.close, color: AppColors.deep),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.deviceId == null ? 'Add Device' : 'Edit Device',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.deep,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveDevice,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.purple,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageUpload(),
            const SizedBox(height: 24),
            _buildDeviceNameField(),
            const SizedBox(height: 20),
            _buildCategoryField(),
            const SizedBox(height: 20),
            _buildLocationField(),
            const SizedBox(height: 20),
            _buildStatusSection(),
            const SizedBox(height: 20),
            _buildStorageBoxField(),
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
    return GestureDetector(
      onTap: _uploadingImage ? null : _pickAndUploadImage,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.light,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.paleLavender, width: 2),
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
                                'Tap to add image',
                                style: TextStyle(
                                  color: AppColors.neutral,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ))),
      ),
    );
  }

  Widget _buildDeviceNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Device Name',
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
            hintText: 'e.g., Makita Power Drill',
            helperText: 'Enter a descriptive name',
            helperStyle: TextStyle(color: AppColors.neutral, fontSize: 12),
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

  Widget _buildCategoryField() {
    final selected = (_selectedCategory ?? '').trim();
    final categories = _uniqueStrings([
      ..._categories,
      if (selected.isNotEmpty) selected,
    ]);
    final value = selected.isNotEmpty && categories.contains(selected)
        ? selected
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Category',
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
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            hintText: 'Select category',
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
          items: categories
              .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
              .toList(),
          onChanged: (value) =>
              setState(() => _selectedCategory = value?.trim()),
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
    final value = selected.isNotEmpty && locations.contains(selected)
        ? selected
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Current Location',
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
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            hintText: 'Select location',
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

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.deep,
              ),
            ),
            Text('*', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatusRadio(
                status: DeviceStatus.working,
                selected: _selectedStatus == DeviceStatus.working,
                icon: Icons.check_circle,
                color: AppColors.success,
                onTap: () =>
                    setState(() => _selectedStatus = DeviceStatus.working),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatusRadio(
                status: DeviceStatus.needsRepair,
                selected: _selectedStatus == DeviceStatus.needsRepair,
                icon: Icons.warning,
                color: AppColors.warning,
                onTap: () =>
                    setState(() => _selectedStatus = DeviceStatus.needsRepair),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatusRadio(
                status: DeviceStatus.broken,
                selected: _selectedStatus == DeviceStatus.broken,
                icon: Icons.close,
                color: AppColors.danger,
                onTap: () =>
                    setState(() => _selectedStatus = DeviceStatus.broken),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStorageBoxField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Store In Box (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.deep,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedStorageBox,
          decoration: InputDecoration(
            hintText: 'No box selected',
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
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('No box selected'),
            ),
            ..._storageBoxes.map(
              (box) => DropdownMenuItem(value: box.id, child: Text(box.label)),
            ),
          ],
          onChanged: (value) => setState(() => _selectedStorageBox = value),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes or Details (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.deep,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 5,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Any additional information...',
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
        onPressed: _isLoading ? null : _saveDevice,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.purple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Save Device',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _StatusRadio extends StatelessWidget {
  const _StatusRadio({
    required this.status,
    required this.selected,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final DeviceStatus status;
  final bool selected;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    String label;
    switch (status) {
      case DeviceStatus.working:
        label = 'Working';
        break;
      case DeviceStatus.needsRepair:
        label = 'Needs Repair';
        break;
      case DeviceStatus.broken:
        label = 'Broken';
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.paleLavender,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : AppColors.neutral,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
