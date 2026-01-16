import 'package:flutter/material.dart';
import '../../services/device_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_dialogs.dart';

class StorageActionsScreen extends StatefulWidget {
  final String householdId;
  final StorageBox box;
  final DeviceRepository repo;
  final String actorUserId;
  final String actorName;
  final String actorAvatar;

  const StorageActionsScreen({
    required this.householdId,
    required this.box,
    required this.repo,
    required this.actorUserId,
    required this.actorName,
    required this.actorAvatar,
    super.key,
  });

  @override
  State<StorageActionsScreen> createState() => _StorageActionsScreenState();
}

class _StorageActionsScreenState extends State<StorageActionsScreen> {
  late String _pendingLabel;
  late String _pendingLocation;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pendingLabel = widget.box.label;
    _pendingLocation = widget.box.location;
  }

  Future<void> _renameBox() async {
    final name = await showAppTextInputDialog(
      context: context,
      title: 'Rename box',
      confirmText: 'Save',
      initialValue: _pendingLabel,
      fieldLabel: 'Box name',
      hintText: 'e.g. Tool Box, Spare Parts',
      helperText: 'Keep it short and recognizable.',
      icon: Icons.inventory_2_outlined,
    );
    if (name == null || name.isEmpty) return;
    setState(() => _pendingLabel = name);
  }

  Future<void> _changeLocation() async {
    final loc = await showAppTextInputDialog(
      context: context,
      title: 'Change location',
      confirmText: 'Move',
      initialValue: _pendingLocation,
      fieldLabel: 'Location',
      hintText: 'e.g. Workshop, Garage',
      helperText: 'Where this box is stored.',
      icon: Icons.location_on_outlined,
    );
    if (loc == null || loc.isEmpty) return;
    setState(() => _pendingLocation = loc);
  }

  Future<List<DeviceRecord>> _devicesInThisBox() async {
    final devices = await widget.repo.getDevices(widget.householdId);
    return devices
        .where((d) => (d.storageBoxId ?? '') == widget.box.id)
        .toList();
  }

  Future<void> _selectDevicesToRemove() async {
    final devices = await _devicesInThisBox();
    if (!mounted) return;
    if (devices.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No devices in this box.')));
      return;
    }

    final selectedIds = await showAppMultiSelectBottomSheet(
      context: context,
      title: 'Select devices',
      subtitle: 'Choose devices to remove from this box.',
      confirmText: 'Remove',
      items: [
        for (final d in devices)
          AppMultiSelectItem(
            id: d.id,
            title: d.name,
            subtitle: d.category,
            leading: const Icon(Icons.devices_other_outlined),
          ),
      ],
    );
    if (selectedIds == null || selectedIds.isEmpty) return;

    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Remove selected devices',
      message:
          'Remove ${selectedIds.length} device(s) from this box? They will remain in your devices list.',
      confirmText: 'Remove',
    );
    if (ok != true) return;

    for (final id in selectedIds) {
      await widget.repo.updateDevice(
        householdId: widget.householdId,
        deviceId: id,
        storageBoxId: '',
        oldStorageBoxId: widget.box.id,
        updatedBy: widget.actorName,
        actorUserId: widget.actorUserId,
        actorName: widget.actorName,
        actorAvatar: widget.actorAvatar,
      );
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _deleteSpecificDevices() async {
    final devices = await _devicesInThisBox();
    if (!mounted) return;
    if (devices.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No devices in this box.')));
      return;
    }

    final selectedIds = await showAppMultiSelectBottomSheet(
      context: context,
      title: 'Delete specific devices',
      subtitle: 'Select devices to permanently delete.',
      confirmText: 'Continue',
      items: [
        for (final d in devices)
          AppMultiSelectItem(
            id: d.id,
            title: d.name,
            subtitle: d.category,
            leading: const Icon(Icons.devices_other_outlined),
          ),
      ],
    );
    if (selectedIds == null || selectedIds.isEmpty) return;

    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Delete selected devices',
      message: 'This will permanently delete ${selectedIds.length} device(s).',
      confirmText: 'Delete',
      destructive: true,
    );
    if (ok != true) return;

    for (final id in selectedIds) {
      await widget.repo.deleteDevice(
        widget.householdId,
        id,
        actorUserId: widget.actorUserId,
        actorName: widget.actorName,
        actorAvatar: widget.actorAvatar,
      );
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  bool get _hasChanges {
    return _pendingLabel.trim() != widget.box.label.trim() ||
        _pendingLocation.trim() != widget.box.location.trim();
  }

  Future<void> _saveChanges() async {
    if (_saving) return;
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.updateStorageBox(
        householdId: widget.householdId,
        boxId: widget.box.id,
        label: _pendingLabel.trim() != widget.box.label.trim()
            ? _pendingLabel.trim()
            : null,
        location: _pendingLocation.trim() != widget.box.location.trim()
            ? _pendingLocation.trim()
            : null,
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

  Future<void> _removeAllDevices() async {
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Remove all devices',
      message: 'This clears all devices from this box. The box will stay.',
      confirmText: 'Remove',
    );
    if (ok != true) return;
    await widget.repo.removeAllDevicesFromBox(
      householdId: widget.householdId,
      boxId: widget.box.id,
      actorUserId: widget.actorUserId,
      actorName: widget.actorName,
      actorAvatar: widget.actorAvatar,
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _archiveBox() async {
    await widget.repo.updateStorageBox(
      householdId: widget.householdId,
      boxId: widget.box.id,
      archived: true,
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
            Text(
              _pendingLabel,
              style: const TextStyle(
                color: AppColors.deep,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              'Manage this storage box',
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
                  icon: Icons.edit,
                  iconColor: Colors.purple,
                  title: 'Rename Box',
                  subtitle: _pendingLabel,
                  hasTrailingIcon: true,
                  trailingIcon: Icons.keyboard_arrow_down,
                  onTap: _renameBox,
                ),
                const SizedBox(height: 12),
                _ActionItem(
                  icon: Icons.location_on,
                  iconColor: Colors.cyan,
                  title: 'Change Location',
                  subtitle: _pendingLocation,
                  hasTrailingIcon: true,
                  trailingIcon: Icons.keyboard_arrow_down,
                  onTap: _changeLocation,
                ),
                const SizedBox(height: 12),
                _ActionItem(
                  icon: Icons.checklist_outlined,
                  iconColor: Colors.tealAccent.shade700,
                  title: 'Select Devices',
                  subtitle: 'Remove specific devices from this box',
                  isChevron: true,
                  onTap: _selectDevicesToRemove,
                ),
                const SizedBox(height: 12),
                _ActionItem(
                  icon: Icons.delete_sweep_outlined,
                  iconColor: AppColors.danger,
                  title: 'Delete Specific Devices',
                  subtitle: 'Select and permanently delete',
                  titleColor: AppColors.danger,
                  subtitleColor: AppColors.danger.withOpacity(0.6),
                  isChevron: true,
                  isDestructive: true,
                  onTap: _deleteSpecificDevices,
                ),
                const SizedBox(height: 12),
                _ActionItem(
                  icon: Icons.unarchive,
                  iconColor: Colors.orangeAccent,
                  title: 'Remove All Devices',
                  subtitle: 'Keep box, clear contents',
                  isChevron: true,
                  onTap: _removeAllDevices,
                ),
                const SizedBox(height: 12),
                _ActionItem(
                  icon: Icons.archive,
                  iconColor: Colors.blueGrey,
                  title: 'Archive Box',
                  subtitle: 'Move to archived list',
                  isChevron: true,
                  onTap: _archiveBox,
                ),
                const SizedBox(height: 12),
                _ActionItem(
                  icon: Icons.delete_outline,
                  iconColor: AppColors.danger,
                  title: 'Delete Box',
                  titleColor: AppColors.danger,
                  subtitle: 'Permanently remove',
                  subtitleColor: AppColors.danger.withOpacity(0.6),
                  isChevron: true,
                  isDestructive: true,
                  onTap: () async {
                    final ok = await showAppConfirmDialog(
                      context: context,
                      title: 'Delete box',
                      message: 'This will permanently delete the box.',
                      confirmText: 'Delete',
                      destructive: true,
                    );
                    if (ok != true) return;
                    await widget.repo.deleteStorageBox(
                      widget.householdId,
                      widget.box.id,
                      actorUserId: widget.actorUserId,
                      actorName: widget.actorName,
                      actorAvatar: widget.actorAvatar,
                    );
                    if (!mounted) return;
                    Navigator.pop(context);
                  },
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
