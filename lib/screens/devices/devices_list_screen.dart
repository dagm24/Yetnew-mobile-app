import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/device_repository.dart';
import '../../services/household_service.dart';
import '../../theme/app_colors.dart';
import '../family/family_screen.dart';
import '../family/setup_household_screen.dart';
import 'device_detail_screen.dart';
import 'add_edit_device_screen.dart';

class DevicesListScreen extends StatefulWidget {
  const DevicesListScreen({super.key});

  @override
  State<DevicesListScreen> createState() => _DevicesListScreenState();
}

class _DevicesListScreenState extends State<DevicesListScreen> {
  final _repo = DeviceRepository(FirebaseFirestore.instance);
  final _householdService = HouseholdService(FirebaseFirestore.instance);
  final _user = FirebaseAuth.instance.currentUser;
  final _searchController = TextEditingController();
  String? _selectedCategory;
  DeviceStatus? _selectedStatus;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        if (householdSnap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (householdSnap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error loading household: ${householdSnap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final householdId = householdSnap.data;
        if (householdId == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'No household found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Create or join a household to manage devices.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.neutral),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SetupHouseholdScreen(),
                        ),
                      ),
                      child: const Text('Set Up Household'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Devices',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.deep,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.person, color: AppColors.deep),
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const FamilyScreen())),
              ),
              IconButton(
                icon: const Icon(Icons.grid_view, color: AppColors.deep),
                onPressed: () {},
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.overlay,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search devices...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: AppColors.neutral,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() => _searchQuery = value.toLowerCase());
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.purple,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.filter_list,
                          color: Colors.white,
                        ),
                        onPressed: _showFilterDialog,
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedCategory != null || _selectedStatus != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_selectedCategory != null)
                        _FilterChip(
                          label: 'Category: $_selectedCategory',
                          onRemove: () =>
                              setState(() => _selectedCategory = null),
                        ),
                      if (_selectedStatus != null)
                        _FilterChip(
                          label: 'Status: ${_selectedStatus!.name}',
                          onRemove: () =>
                              setState(() => _selectedStatus = null),
                        ),
                      _FilterChip(
                        label: 'Clear All',
                        onRemove: () => setState(() {
                          _selectedCategory = null;
                          _selectedStatus = null;
                        }),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: StreamBuilder<List<DeviceRecord>>(
                  stream: _repo.streamDevices(householdId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      final errorMsg = snapshot.error.toString();
                      final isPermissionError = errorMsg.contains(
                        'permission-denied',
                      );
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 64,
                                color: isPermissionError
                                    ? AppColors.danger
                                    : AppColors.neutral,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isPermissionError
                                    ? 'Permission Denied'
                                    : 'Error Loading Devices',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.deep,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isPermissionError
                                    ? 'You don\'t have access to this household. Please make sure you joined the right household (and that Firebase rules are deployed).'
                                    : errorMsg,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.neutral,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (isPermissionError)
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const SetupHouseholdScreen(),
                                    ),
                                  ),
                                  child: const Text('Fix Household Access'),
                                ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var devices = snapshot.data!;
                    if (_searchQuery.isNotEmpty) {
                      devices = devices
                          .where(
                            (d) =>
                                d.name.toLowerCase().contains(_searchQuery) ||
                                d.category.toLowerCase().contains(
                                  _searchQuery,
                                ) ||
                                d.location.toLowerCase().contains(_searchQuery),
                          )
                          .toList();
                    }
                    if (_selectedCategory != null) {
                      devices = devices
                          .where((d) => d.category == _selectedCategory)
                          .toList();
                    }
                    if (_selectedStatus != null) {
                      devices = devices
                          .where((d) => d.status == _selectedStatus)
                          .toList();
                    }

                    if (devices.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: AppColors.neutral,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No devices found',
                              style: TextStyle(
                                color: AppColors.neutral,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        return _DeviceCard(
                          device: device,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DeviceDetailScreen(deviceId: device.id),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: null,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditDeviceScreen()),
            ),
            backgroundColor: AppColors.purple,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Devices'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Category'),
              value: _selectedCategory,
              items: [
                'Power Tools',
                'Hand Tools',
                'Electronics',
                'Appliances',
              ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (value) => setState(() => _selectedCategory = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<DeviceStatus>(
              decoration: const InputDecoration(labelText: 'Status'),
              value: _selectedStatus,
              items: DeviceStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedStatus = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.purple,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.onTap});

  final DeviceRecord device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    switch (device.status) {
      case DeviceStatus.working:
        statusColor = AppColors.success;
        statusText = 'Available';
        break;
      case DeviceStatus.needsRepair:
        statusColor = AppColors.warning;
        statusText = 'In Use';
        break;
      case DeviceStatus.broken:
        statusColor = AppColors.danger;
        statusText = 'Broken';
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.paleLavender.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.light,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child:
                        (device.imageThumbBase64 != null &&
                            device.imageThumbBase64!.trim().isNotEmpty)
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: Image.memory(
                              base64Decode(device.imageThumbBase64!),
                              fit: BoxFit.cover,
                            ),
                          )
                        : (device.imageUrl != null &&
                              device.imageUrl!.trim().isNotEmpty)
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: Image.network(
                              device.imageUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            _getCategoryIcon(device.category),
                            size: 48,
                            color: AppColors.purple,
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.deep,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    device.category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.neutral,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: AppColors.purple,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          device.location,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.neutral,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
