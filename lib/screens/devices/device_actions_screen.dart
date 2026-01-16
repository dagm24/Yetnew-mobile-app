import 'package:flutter/material.dart';
import '../../services/device_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_dialogs.dart';

class DeviceActionsScreen extends StatefulWidget {
  final String householdId;
  final DeviceRecord device;
  final DeviceRepository repo;
  final String actorUserId;
  final String actorName;
  final String actorAvatar;

  const DeviceActionsScreen({
    required this.householdId,
    required this.device,
    required this.repo,
    required this.actorUserId,
    required this.actorName,
    required this.actorAvatar,
    super.key,
  });

  @override
  State<DeviceActionsScreen> createState() => _DeviceActionsScreenState();
}

class _DeviceActionsScreenState extends State<DeviceActionsScreen> {
  late String _pendingName;
  late DeviceStatus _pendingStatus;
  late String _pendingCategory;
  late String _pendingLocation;
  late String _pendingNotes;
  String? _pendingStorageBoxId;
  String? _pendingStorageBoxLabel;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pendingName = widget.device.name;
    _pendingStatus = widget.device.status;
    _pendingCategory = widget.device.category;
    _pendingLocation = widget.device.location;
    _pendingNotes = widget.device.notes ?? '';
    _pendingStorageBoxId = widget.device.storageBoxId;
  }

  String _statusText(DeviceStatus s) {
    switch (s) {
      case DeviceStatus.working:
        return 'Working';
      case DeviceStatus.needsRepair:
        return 'Repair';
      case DeviceStatus.broken:
        return 'Broken';
    }
  }

  Color _statusColor(DeviceStatus s) {
    switch (s) {
      case DeviceStatus.working:
        return AppColors.success;
      case DeviceStatus.needsRepair:
        return AppColors.warning;
      case DeviceStatus.broken:
        return AppColors.danger;
    }
  }

  Future<void> _changeStatus() async {
    final selected = await showAppSelectionBottomSheet<DeviceStatus>(
      context: context,
      title: 'Change status',
      subtitle: 'Select the current condition for this device.',
      items: [
        for (final s in DeviceStatus.values)
          AppSheetItem<DeviceStatus>(
            value: s,
            title: _statusText(s),
            leading: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _statusColor(s),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
    if (selected == null) return;
    setState(() => _pendingStatus = selected);
  }

  Future<void> _moveLocation() async {
    final confirmed = await showAppTextInputDialog(
      context: context,
      title: 'Move to location',
      confirmText: 'Move',
      initialValue: _pendingLocation,
      fieldLabel: 'Location',
      hintText: 'e.g. Workshop, Bedroom, Office',
      helperText: 'This updates where the device is located.',
      icon: Icons.location_on_outlined,
    );
    if (confirmed == null || confirmed.isEmpty) return;
    setState(() => _pendingLocation = confirmed);
  }

  Future<void> _storeInBox() async {
    final boxes = await widget.repo.getStorageBoxes(widget.householdId);
    if (!mounted) return;
    final selected = await showAppSelectionBottomSheet<StorageBox>(
      context: context,
      title: 'Store in box',
      subtitle: 'Choose where this device should be stored.',
      items: [
        for (final b in boxes)
          AppSheetItem<StorageBox>(
            value: b,
            title: b.label,
            subtitle: b.location,
            leading: const Icon(Icons.inventory_2_outlined),
          ),
      ],
    );
    if (selected == null) return;
    setState(() {
      _pendingStorageBoxId = selected.id;
      _pendingStorageBoxLabel = selected.label;
    });
  }

  Future<void> _editDetails() async {
    final result = await showAppDeviceDetailsDialog(
      context: context,
      title: 'Edit details',
      confirmText: 'Save',
      initialName: _pendingName,
      initialCategory: _pendingCategory,
      initialNotes: _pendingNotes,
    );
    if (result == null) return;

    setState(() {
      _pendingName = result.name;
      _pendingCategory = result.category;
      _pendingNotes = result.notes;
    });
  }

  Future<void> _removeFromStorage() async {
    setState(() {
      _pendingStorageBoxId = '';
      _pendingStorageBoxLabel = null;
    });
  }

  Future<void> _saveChanges() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final oldBox = widget.device.storageBoxId;
      final newBox = _pendingStorageBoxId;

      await widget.repo.updateDevice(
        householdId: widget.householdId,
        deviceId: widget.device.id,
        name: _pendingName != widget.device.name ? _pendingName : null,
        status: _pendingStatus != widget.device.status ? _pendingStatus : null,
        category: _pendingCategory != widget.device.category
            ? _pendingCategory
            : null,
        location: _pendingLocation != widget.device.location
            ? _pendingLocation
            : null,
        notes: _pendingNotes != (widget.device.notes ?? '')
            ? _pendingNotes
            : null,
        storageBoxId: (newBox ?? '') != (oldBox ?? '') ? (newBox ?? '') : null,
        oldStorageBoxId: (newBox ?? '') != (oldBox ?? '')
            ? (oldBox ?? '')
            : null,
        updatedBy: widget.actorName,
        actorUserId: widget.actorUserId,
        actorName: widget.actorName,
        actorAvatar: widget.actorAvatar,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Changes saved')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteDevice() async {
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Delete device',
      message: 'This will permanently remove the device.',
      confirmText: 'Delete',
      destructive: true,
    );
    if (ok != true) return;
    await widget.repo.deleteDevice(
      widget.householdId,
      widget.device.id,
      actorUserId: widget.actorUserId,
      actorName: widget.actorName,
      actorAvatar: widget.actorAvatar,
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3EDF7), // Light lavender from design
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.deep),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Actions',
              style: TextStyle(
                color: AppColors.deep,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              'Manage and update this device',
              style: TextStyle(
                color: AppColors.neutral.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _ActionItem(
                  icon: Icons.sync,
                  iconColor: Colors.blue,
                  title: 'Change Status',
                  subtitle: _statusText(_pendingStatus),
                  hasTrailingIcon: true,
                  trailingIcon: Icons.keyboard_arrow_down,
                  statusLabel: _statusText(_pendingStatus),
                  statusColor: _statusColor(_pendingStatus),
                  onTap: _changeStatus,
                ),
                const SizedBox(height: 12),
                _ActionItem(
                  icon: Icons.location_on,
                  iconColor: Colors.cyan,
                  title: 'Move to Location',
                  subtitle: _pendingLocation,
                  hasTrailingIcon: true,
                  trailingIcon: Icons.keyboard_arrow_down,
                  onTap: _moveLocation,
                ),
                const SizedBox(height: 12),
                _ActionItem(
                  icon: Icons.inventory_2,
                  iconColor: AppColors.purple,
                  title: 'Store in Box',
                  subtitle:
                      (_pendingStorageBoxId == null ||
                          (_pendingStorageBoxId ?? '').isEmpty)
                      ? 'Not assigned'
                      : (_pendingStorageBoxLabel ??
                            'Box ${_pendingStorageBoxId!}'),
                  hasTrailingIcon: true,
                  trailingIcon: Icons.keyboard_arrow_down,
                  onTap: _storeInBox,
                ),
                const SizedBox(height: 12),
                _ActionItem(
                  icon: Icons.edit_document,
                  iconColor: Colors.blueAccent,
                  title: 'Edit Details',
                  subtitle: _pendingNotes.trim().isEmpty
                      ? 'Add or update notes'
                      : 'Notes updated',
                  hasTrailingIcon: true,
                  trailingIcon: Icons.keyboard_arrow_down,
                  onTap: _editDetails,
                ),
                const SizedBox(height: 12),
                _ActionItem(
                  icon: Icons.remove_shopping_cart,
                  iconColor: Colors.grey,
                  title: 'Remove from Storage',
                  subtitle: 'Clear storage assignment',
                  isChevron: true,
                  onTap: _removeFromStorage,
                ),
                const SizedBox(height: 12),
                _ActionItem(
                  icon: Icons.delete,
                  iconColor: AppColors.danger,
                  title: 'Delete Device',
                  titleColor: AppColors.danger,
                  subtitle: 'Permanently remove device',
                  subtitleColor: AppColors.danger.withOpacity(0.6),
                  isChevron: true,
                  isDestructive: true,
                  onTap: _deleteDevice,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _saving ? 'Saving...' : 'Save Changes',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.paleLavender),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.deep,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool hasTrailingIcon;
  final IconData? trailingIcon;
  final bool isChevron;
  final String? statusLabel;
  final Color? statusColor;
  final Color? titleColor;
  final Color? subtitleColor;
  final bool isDestructive;
  final VoidCallback? onTap;

  const _ActionItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.hasTrailingIcon = false,
    this.trailingIcon,
    this.isChevron = false,
    this.statusLabel,
    this.statusColor,
    this.titleColor,
    this.subtitleColor,
    this.isDestructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDestructive
                ? Colors.red.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: titleColor ?? AppColors.deep,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (statusLabel != null)
                    Row(
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor!.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusLabel!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color:
                            subtitleColor ?? AppColors.neutral.withOpacity(0.6),
                      ),
                    ),
                ],
              ),
            ),
            if (hasTrailingIcon)
              Icon(
                trailingIcon,
                color: AppColors.neutral.withOpacity(0.5),
                size: 20,
              )
            else if (isChevron)
              Icon(
                Icons.chevron_right,
                color: isDestructive
                    ? Colors.red.withOpacity(0.5)
                    : AppColors.neutral.withOpacity(0.5),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
