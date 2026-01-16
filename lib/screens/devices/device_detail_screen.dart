import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/device_repository.dart';
import '../../services/household_service.dart';
import '../../theme/app_colors.dart';
import 'add_edit_device_screen.dart';
import 'device_actions_screen.dart';
import '../storage/storage_box_detail_screen.dart';

class DeviceDetailScreen extends StatefulWidget {
  const DeviceDetailScreen({required this.deviceId, super.key});

  final String deviceId;

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final _repo = DeviceRepository(FirebaseFirestore.instance);
  final _householdService = HouseholdService(FirebaseFirestore.instance);
  final _user = FirebaseAuth.instance.currentUser;
  int _historyVisibleCount = 4;

  Future<void> _deleteDevice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Device'),
        content: const Text('Are you sure you want to delete this device?'),
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
    if (confirm != true || user == null) return;

    try {
      final householdId = await _householdService.getUserHouseholdId(user.uid);
      if (householdId != null) {
        final actorName = (user.displayName ?? user.email ?? 'User').trim();
        final actorAvatar = actorName.isNotEmpty
            ? actorName.substring(0, 1).toUpperCase()
            : '?';
        await _repo.deleteDevice(
          householdId,
          widget.deviceId,
          actorUserId: user.uid,
          actorName: actorName,
          actorAvatar: actorAvatar,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device deleted successfully!'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete device: ${e.toString()}'),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 3),
          ),
        );
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
              icon: const Icon(Icons.close, color: AppColors.deep),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: AppColors.deep),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddEditDeviceScreen(deviceId: widget.deviceId),
                  ),
                ),
              ),
            ],
          ),
          body: StreamBuilder<List<DeviceRecord>>(
            stream: _repo.streamDevices(householdId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final devices = snapshot.data!;
              DeviceRecord? device;
              try {
                device = devices.firstWhere((d) => d.id == widget.deviceId);
              } catch (_) {
                device = null;
              }

              if (device == null) {
                return const Center(child: Text('Device not found'));
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDeviceImage(device),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDeviceHeader(device),
                          const SizedBox(height: 16),
                          _buildSummaryBar(device),
                          const SizedBox(height: 24),
                          _buildBasicInformation(device),
                          const SizedBox(height: 24),
                          _buildStorageLocation(householdId, device),
                          const SizedBox(height: 24),
                          _buildHistory(householdId),
                          const SizedBox(height: 24),
                          _buildDetails(device),
                          const SizedBox(height: 24),
                          _buildMetadata(device),
                          const SizedBox(height: 32),
                          _buildActionButtons(householdId, device),
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

  Widget _buildDeviceImage(DeviceRecord device) {
    return Container(
      height: 300,
      width: double.infinity,
      color: AppColors.light,
      child:
          (device.imageThumbBase64 != null &&
              device.imageThumbBase64!.trim().isNotEmpty)
          ? Image.memory(
              base64Decode(device.imageThumbBase64!),
              fit: BoxFit.cover,
            )
          : (device.imageUrl != null && device.imageUrl!.trim().isNotEmpty)
          ? Image.network(device.imageUrl!, fit: BoxFit.cover)
          : Icon(
              _getCategoryIcon(device.category),
              size: 80,
              color: AppColors.purple,
            ),
    );
  }

  Widget _buildDeviceHeader(DeviceRecord device) {
    Color statusColor;
    String statusText;
    switch (device.status) {
      case DeviceStatus.working:
        statusColor = AppColors.success;
        statusText = 'Active';
        break;
      case DeviceStatus.needsRepair:
        statusColor = AppColors.warning;
        statusText = 'Needs Repair';
        break;
      case DeviceStatus.broken:
        statusColor = AppColors.danger;
        statusText = 'Broken';
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            device.name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.deep,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBar(DeviceRecord device) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.paleLavender),
          bottom: BorderSide(color: AppColors.paleLavender),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(
            icon: _getCategoryIcon(device.category),
            label: device.category,
          ),
          _SummaryItem(icon: Icons.location_on, label: device.location),
          _SummaryItem(
            icon: Icons.check_circle,
            label: device.status == DeviceStatus.working
                ? 'In Use'
                : 'Not In Use',
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInformation(DeviceRecord device) {
    return _Section(
      title: 'Basic Information',
      children: [
        _InfoRow(
          icon: Icons.category,
          label: 'Category',
          value: device.category,
        ),
        _InfoRow(
          icon: Icons.location_on,
          label: 'Location',
          value: device.location,
        ),
        _InfoRow(
          icon: Icons.info,
          label: 'Current Status',
          value: _getStatusText(device.status),
          valueColor: _getStatusColor(device.status),
        ),
      ],
    );
  }

  Widget _buildStorageLocation(String householdId, DeviceRecord device) {
    final boxId = device.storageBoxId;
    if (boxId == null || boxId.isEmpty) {
      return _Section(
        title: 'Storage Location',
        children: const [
          _InfoRow(
            icon: Icons.inventory_2,
            label: 'Storage Box',
            value: 'Not stored in a box',
          ),
        ],
      );
    }

    return StreamBuilder<List<StorageBox>>(
      stream: _repo.streamStorageBoxes(householdId),
      builder: (context, snap) {
        final boxes = snap.data ?? const <StorageBox>[];
        final box = boxes.where((b) => b.id == boxId).firstOrNull;
        final boxLabel = box?.label ?? boxId;
        final boxSubtitle = box == null ? null : box.location;

        return _Section(
          title: 'Storage Location',
          children: [
            _InfoRow(
              icon: Icons.inventory_2,
              label: 'Storage Box',
              value: boxLabel,
              subtitle: boxSubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StorageBoxDetailScreen(boxId: boxId),
                ),
              ),
            ),
            if (device.compartmentNumber != null)
              _InfoRow(
                icon: Icons.grid_view,
                label: 'Compartment',
                value: device.compartmentNumber.toString(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHistory(String householdId) {
    return _Section(
      title: 'History',
      children: [
        StreamBuilder<List<DeviceHistoryEntry>>(
          stream: _repo.streamDeviceHistory(householdId, widget.deviceId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final entries = snap.data!;
            if (entries.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.overlay,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No history yet',
                  style: TextStyle(color: AppColors.neutral),
                ),
              );
            }

            final visible = entries.take(_historyVisibleCount).toList();

            return Column(
              children: [
                ...visible.map(
                  (e) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.overlay,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.message,
                          style: const TextStyle(
                            color: AppColors.deep,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${e.at.day}/${e.at.month}/${e.at.year} ${e.at.hour}:${e.at.minute.toString().padLeft(2, '0')}'
                          '${e.by != null ? ' • ${e.by}' : ''}',
                          style: const TextStyle(
                            color: AppColors.neutral,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (entries.length > _historyVisibleCount)
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () {
                        final next = _historyVisibleCount + 4;
                        setState(() {
                          _historyVisibleCount = next > entries.length
                              ? entries.length
                              : next;
                        });
                      },
                      child: const Text(
                        'See more',
                        style: TextStyle(
                          color: AppColors.purple,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDetails(DeviceRecord device) {
    return _Section(
      title: 'Details',
      subtitle: 'Additional Notes',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.overlay,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            device.notes ?? 'No additional notes',
            style: const TextStyle(
              color: AppColors.neutral,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadata(DeviceRecord device) {
    return _Section(
      title: 'Metadata',
      children: [
        _InfoRow(
          icon: Icons.calendar_today,
          label: 'Created',
          value: device.createdAt != null
              ? '${device.createdAt!.day}/${device.createdAt!.month}/${device.createdAt!.year} at ${device.createdAt!.hour}:${device.createdAt!.minute.toString().padLeft(2, '0')}'
              : 'Unknown',
        ),
        _InfoRow(
          icon: Icons.update,
          label: 'Last Updated',
          value:
              '${device.updatedAt.day}/${device.updatedAt.month}/${device.updatedAt.year} at ${device.updatedAt.hour}:${device.updatedAt.minute.toString().padLeft(2, '0')}',
        ),
        _InfoRow(
          icon: Icons.person,
          label: 'Created By',
          value: device.createdBy ?? 'Unknown',
          subtitle: _user?.email,
        ),
      ],
    );
  }

  Widget _buildActionButtons(String householdId, DeviceRecord device) {
    final actorName = (_user?.displayName ?? _user?.email ?? 'User').trim();
    final actorAvatar = actorName.isNotEmpty
        ? actorName.substring(0, 1).toUpperCase()
        : '?';
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddEditDeviceScreen(deviceId: device.id),
              ),
            ),
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text(
              'Edit Device',
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
                builder: (_) => DeviceActionsScreen(
                  householdId: householdId,
                  device: device,
                  repo: _repo,
                  actorUserId: _user?.uid ?? '',
                  actorName: actorName,
                  actorAvatar: actorAvatar,
                ),
              ),
            ),

            icon: const Icon(
              Icons.settings_applications,
              color: AppColors.deep,
            ),
            label: const Text(
              'Manage Actions',
              style: TextStyle(
                color: AppColors.deep,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.softLavender,
              elevation: 0,
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
            onPressed: _deleteDevice,
            icon: const Icon(Icons.delete, color: AppColors.danger),
            label: const Text(
              'Delete Device',
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

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'power tools':
      case 'hand tools':
        return Icons.build;
      case 'electronics':
        return Icons.laptop;
      case 'appliances':
        return Icons.kitchen;
      default:
        return Icons.inventory_2;
    }
  }

  String _getStatusText(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.working:
        return 'Active - In Daily Use';
      case DeviceStatus.needsRepair:
        return 'Needs Repair';
      case DeviceStatus.broken:
        return 'Broken';
    }
  }

  Color _getStatusColor(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.working:
        return AppColors.success;
      case DeviceStatus.needsRepair:
        return AppColors.warning;
      case DeviceStatus.broken:
        return AppColors.danger;
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deep,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.neutral,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.purple, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.neutral,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: valueColor ?? AppColors.deep,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.neutral,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onTap != null)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.chevron_right, color: AppColors.neutral),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: content,
            ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.purple, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.neutral,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
