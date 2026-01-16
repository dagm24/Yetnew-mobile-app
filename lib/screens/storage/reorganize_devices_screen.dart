import 'package:flutter/material.dart';
import '../../services/device_repository.dart';
import '../../theme/app_colors.dart';

class ReorganizeDevicesScreen extends StatefulWidget {
  final String householdId;
  final String boxId;
  final DeviceRepository repo;
  final String actorUserId;
  final String actorName;
  final String actorAvatar;

  const ReorganizeDevicesScreen({
    required this.householdId,
    required this.boxId,
    required this.repo,
    required this.actorUserId,
    required this.actorName,
    required this.actorAvatar,
    super.key,
  });

  @override
  State<ReorganizeDevicesScreen> createState() =>
      _ReorganizeDevicesScreenState();
}

class _ReorganizeDevicesScreenState extends State<ReorganizeDevicesScreen> {
  List<DeviceRecord> _devices = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Fetch devices in this box once for reordering
    final all = await widget.repo.getDevices(widget.householdId);
    setState(() {
      _devices = all.where((d) => d.storageBoxId == widget.boxId).toList();
      // Sort by current compartmentNumber (nulls last)
      _devices.sort((a, b) {
        final ac = a.compartmentNumber ?? 1 << 20;
        final bc = b.compartmentNumber ?? 1 << 20;
        return ac.compareTo(bc);
      });
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      for (var i = 0; i < _devices.length; i++) {
        final d = _devices[i];
        await widget.repo.updateDevice(
          householdId: widget.householdId,
          deviceId: d.id,
          compartmentNumber: i + 1,
          updatedBy: widget.actorName,
          actorUserId: widget.actorUserId,
          actorName: widget.actorName,
          actorAvatar: widget.actorAvatar,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reorganize Devices'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.deep),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: _devices.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _devices.removeAt(oldIndex);
                        _devices.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final d = _devices[index];
                      return ListTile(
                        key: ValueKey(d.id),
                        leading: const Icon(Icons.drag_handle),
                        title: Text(
                          d.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          d.compartmentNumber == null
                              ? 'Unassigned'
                              : 'Compartment ${d.compartmentNumber}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _saving ? 'Saving...' : 'Save Order',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
