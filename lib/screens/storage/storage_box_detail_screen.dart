import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/device_repository.dart';
import '../../services/household_service.dart';
import '../../theme/app_colors.dart';
import '../devices/device_detail_screen.dart';
import 'add_storage_box_screen.dart';
import 'storage_actions_screen.dart';

class StorageBoxDetailScreen extends StatefulWidget {
  const StorageBoxDetailScreen({required this.boxId, super.key});

  final String boxId;

  @override
  State<StorageBoxDetailScreen> createState() => _StorageBoxDetailScreenState();
}

class _StorageBoxDetailScreenState extends State<StorageBoxDetailScreen> {
  final _repo = DeviceRepository(FirebaseFirestore.instance);
  final _householdService = HouseholdService(FirebaseFirestore.instance);
  final _user = FirebaseAuth.instance.currentUser;
  bool _isDeleting = false;

  Future<void> _deleteBox() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Storage Box'),
        content: const Text(
          'Are you sure you want to delete this storage box?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    final user = _user;
    if (confirm == true && user != null) {
      setState(() => _isDeleting = true);
      try {
        final householdId = await _householdService.getUserHouseholdId(
          user.uid,
        );
        if (householdId != null) {
          final avatarSource = ((user.displayName ?? user.email) ?? '').trim();
          await _repo.deleteStorageBox(
            householdId,
            widget.boxId,
            actorUserId: user.uid,
            actorName: user.displayName ?? user.email,
            actorAvatar: avatarSource.isNotEmpty
                ? avatarSource.substring(0, 1).toUpperCase()
                : '?',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Storage box deleted successfully!'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 2),
              ),
            );
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete storage box: ${e.toString()}'),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _user?.uid;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text('No user')));
    }

    return FutureBuilder<String?>(
      future: _householdService.getUserHouseholdId(userId),
      builder: (context, householdSnap) {
        if (!householdSnap.hasData || householdSnap.data == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final householdId = householdSnap.data!;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.deep),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: AppColors.deep),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddStorageBoxScreen(boxId: widget.boxId),
                  ),
                ),
              ),
            ],
          ),
          body: StreamBuilder<StorageBox?>(
            stream: _repo.streamStorageBoxes(householdId).map((boxes) {
              try {
                return boxes.firstWhere((b) => b.id == widget.boxId);
              } catch (_) {
                return null;
              }
            }),
            builder: (context, boxSnap) {
              if (!boxSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final box = boxSnap.data;
              if (box == null) {
                return const Center(child: Text('Storage box not found'));
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBoxImage(box),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBoxHeader(box, householdId),
                          const SizedBox(height: 24),
                          _buildNotes(box),
                          const SizedBox(height: 24),
                          _buildDevicesInBox(householdId),
                          const SizedBox(height: 24),
                          _buildActionButtons(box, householdId),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBoxImage(StorageBox box) {
    return Container(
      height: 300,
      width: double.infinity,
      color: AppColors.light,
      child:
          (box.imageThumbBase64 != null &&
              box.imageThumbBase64!.trim().isNotEmpty)
          ? Image.memory(base64Decode(box.imageThumbBase64!), fit: BoxFit.cover)
          : (box.imageUrl != null && box.imageUrl!.trim().isNotEmpty)
          ? Image.network(box.imageUrl!, fit: BoxFit.cover)
          : Icon(Icons.inventory_2, size: 80, color: AppColors.purple),
    );
  }

  Widget _buildBoxHeader(StorageBox box, String householdId) {
    return StreamBuilder<List<DeviceRecord>>(
      stream: _repo.streamDevicesInBox(householdId, widget.boxId),
      builder: (context, snapshot) {
        final deviceCount = snapshot.hasData
            ? snapshot.data!.length
            : box.itemCount;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              box.label,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.deep,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 18,
                  color: AppColors.purple,
                ),
                const SizedBox(width: 6),
                Text(
                  box.location,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.neutral,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softLavender,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.grid_view,
                        size: 14,
                        color: AppColors.purple,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${box.compartments} compartments',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.deep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softLavender,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.inventory_2,
                        size: 14,
                        color: AppColors.purple,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$deviceCount items',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.deep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotes(StorageBox box) {
    final notes = (box.notes ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.deep,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.overlay,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            notes.isEmpty ? 'No notes yet' : notes,
            style: const TextStyle(color: AppColors.neutral),
          ),
        ),
      ],
    );
  }

  Widget _buildDevicesInBox(String householdId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Devices in this box',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.deep,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<DeviceRecord>>(
          stream: _repo.streamDevicesInBox(householdId, widget.boxId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final devices = snapshot.data!;
            if (devices.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.overlay,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No devices stored in this box yet',
                    style: TextStyle(color: AppColors.neutral),
                  ),
                ),
              );
            }
            return Column(
              children: devices
                  .map(
                    (device) => _DeviceInBoxTile(
                      device: device,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DeviceDetailScreen(deviceId: device.id),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons(StorageBox box, String householdId) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () {
              final user = _user;
              if (user == null) return;
              final actorName = user.displayName ?? user.email ?? 'User';
              final avatarSource = actorName.trim();
              final actorAvatar = avatarSource.isNotEmpty
                  ? avatarSource.substring(0, 1).toUpperCase()
                  : '?';
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StorageActionsScreen(
                    householdId: householdId,
                    box: box,
                    repo: _repo,
                    actorUserId: user.uid,
                    actorName: actorName,
                    actorAvatar: actorAvatar,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.settings, color: Colors.white),
            label: const Text(
              'Manage Storage',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddStorageBoxScreen(boxId: box.id),
              ),
            ),
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text(
              'Edit Box',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _deleteBox,
            icon: const Icon(Icons.delete, color: AppColors.danger),
            label: const Text(
              'Delete Box',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.danger),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeviceInBoxTile extends StatelessWidget {
  const _DeviceInBoxTile({required this.device, required this.onTap});

  final DeviceRecord device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    switch (device.status) {
      case DeviceStatus.working:
        statusColor = AppColors.success;
        statusText = 'Working';
        break;
      case DeviceStatus.needsRepair:
        statusColor = AppColors.warning;
        statusText = 'Repair';
        break;
      case DeviceStatus.broken:
        statusColor = AppColors.danger;
        statusText = 'Broken';
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.paleLavender),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.light,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  (device.imageThumbBase64 != null &&
                      device.imageThumbBase64!.trim().isNotEmpty)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(device.imageThumbBase64!),
                        fit: BoxFit.cover,
                      ),
                    )
                  : (device.imageUrl != null &&
                        device.imageUrl!.trim().isNotEmpty)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(device.imageUrl!, fit: BoxFit.cover),
                    )
                  : Icon(
                      _getCategoryIcon(device.category),
                      size: 28,
                      color: AppColors.purple,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deep,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    device.compartmentNumber != null
                        ? 'Compartment ${device.compartmentNumber}'
                        : 'No compartment assigned',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.neutral,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.neutral),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'power tools':
      case 'hand tools':
        return Icons.build;
      case 'electronics':
        return Icons.devices;
      case 'appliances':
        return Icons.kitchen;
      default:
        return Icons.inventory_2;
    }
  }
}
