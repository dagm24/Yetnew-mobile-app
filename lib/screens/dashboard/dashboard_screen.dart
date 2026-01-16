import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import '../../services/device_repository.dart';
import '../../services/household_service.dart';
import '../../theme/app_colors.dart';
import '../devices/devices_list_screen.dart';
import '../devices/add_edit_device_screen.dart';
import '../devices/device_detail_screen.dart';
import '../storage/storage_list_screen.dart';
import '../storage/storage_box_detail_screen.dart';
import '../family/family_screen.dart';
import '../history/history_screen.dart';
import '../chat/ai_chat_screen.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = DeviceRepository(FirebaseFirestore.instance);
  final _householdService = HouseholdService(FirebaseFirestore.instance);
  final _user = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;

  void _goToStorageTab() {
    setState(() => _currentIndex = 2);
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
        if (!householdSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final householdId = householdSnap.data;
        if (householdId == null) {
          return const Scaffold(
            body: Center(
              child: Text('No household found. Please set up a household.'),
            ),
          );
        }

        return FutureBuilder<Household?>(
          future: _householdService.getHousehold(householdId),
          builder: (context, householdDocSnap) {
            final householdName = householdDocSnap.data?.name ?? 'Household';

            return Scaffold(
              backgroundColor: Colors.white,
              body: IndexedStack(
                index: _currentIndex,
                children: [
                  _buildHomeTab(householdId, householdName),
                  _buildDevicesTab(),
                  _buildStorageTab(),
                  _buildHistoryTab(),
                  _buildFamilyTab(),
                  const ProfileScreen(),
                ],
              ),
              bottomNavigationBar: _buildBottomNav(),
              floatingActionButton: _currentIndex == 0
                  ? FloatingActionButton(
                      heroTag: null,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => const AIChatScreen(),
                        ),
                      ),
                      backgroundColor: AppColors.purple,
                      child: SvgPicture.asset(
                        'assets/images/ai-chat-icon.svg',
                        width: 24,
                        height: 24,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildHomeTab(String householdId, String householdName) {
    return StreamBuilder<List<DeviceRecord>>(
      stream: _repo.streamDevices(householdId),
      builder: (context, snapshot) {
        final devices = snapshot.data ?? [];
        final working = devices
            .where((d) => d.status == DeviceStatus.working)
            .length;
        final needsRepair = devices
            .where((d) => d.status == DeviceStatus.needsRepair)
            .length;
        final total = devices.length;

        return StreamBuilder<List<StorageBox>>(
          stream: _repo.streamStorageBoxes(householdId),
          builder: (context, storageSnap) {
            final storageBoxes = storageSnap.data ?? [];

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(),
                  _buildWelcomeBanner(householdName),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInventorySection(
                          total,
                          working,
                          needsRepair,
                          storageBoxes.length,
                        ),
                        const SizedBox(height: 24),
                        _buildQuickActions(),
                        const SizedBox(height: 24),
                        _buildRecentlyAdded(devices),
                        const SizedBox(height: 24),
                        _buildYourStorage(storageBoxes),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.purple,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.search, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Yetnew',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.deep,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () => setState(() => _currentIndex = 5),

            borderRadius: BorderRadius.circular(999),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.light,
              child: const Icon(Icons.person, color: AppColors.purple),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner(String householdName) {
    final displayName =
        _user?.displayName ?? _user?.email?.split('@').first ?? 'User';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.purple, AppColors.mid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, $displayName!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            householdName,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildInventorySection(
    int total,
    int working,
    int needsRepair,
    int storageBoxes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Inventory',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.deep,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            _InventoryCard(
              icon: Icons.phone_android,
              value: '$total',
              label: 'Total Devices',
              color: AppColors.softLavender,
            ),
            _InventoryCard(
              icon: Icons.inventory_2,
              value: '$storageBoxes',
              label: 'Storage Boxes',
              color: AppColors.softLavender,
            ),
            _InventoryCard(
              icon: Icons.check_circle,
              value: '$working',
              label: 'Working',
              color: AppColors.success.withOpacity(0.2),
            ),
            _InventoryCard(
              icon: Icons.build,
              value: '$needsRepair',
              label: 'Needs Repair',
              color: AppColors.warning.withOpacity(0.2),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.deep,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.add,
                label: 'Add Device',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddEditDeviceScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.inventory_2,
                label: 'Manage Storage',
                onTap: _goToStorageTab,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentlyAdded(List<DeviceRecord> devices) {
    final recent = devices.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recently Added',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.deep,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DevicesListScreen()),
              ),
              child: const Text(
                'View All',
                style: TextStyle(color: AppColors.info),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 176,
          child: recent.isEmpty
              ? Center(
                  child: Text(
                    'No devices yet',
                    style: TextStyle(color: AppColors.neutral),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: recent.length,
                  itemBuilder: (context, index) {
                    final device = recent[index];
                    return _RecentlyAddedCard(
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
                ),
        ),
      ],
    );
  }

  Widget _buildYourStorage(List<StorageBox> boxes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Storage',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.deep,
              ),
            ),
            TextButton(
              onPressed: _goToStorageTab,
              child: const Text(
                'View All',
                style: TextStyle(color: AppColors.info),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 184,
          child: boxes.isEmpty
              ? Center(
                  child: Text(
                    'No storage boxes yet',
                    style: TextStyle(color: AppColors.neutral),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: boxes.length,
                  itemBuilder: (context, index) {
                    final box = boxes[index];
                    return _StorageCard(
                      box: box,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StorageBoxDetailScreen(boxId: box.id),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDevicesTab() {
    return const DevicesListScreen();
  }

  Widget _buildStorageTab() {
    return const StorageListScreen();
  }

  Widget _buildHistoryTab() {
    return const HistoryScreen();
  }

  Widget _buildFamilyTab() {
    return const FamilyScreen();
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex < 5 ? _currentIndex : 0,
        onTap: (index) => setState(() => _currentIndex = index),

        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.purple,
        unselectedItemColor: AppColors.neutral,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.phone_android_outlined),
            activeIcon: Icon(Icons.phone_android),
            label: 'Devices',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Storage',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: 'Family',
          ),
        ],
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 150;
        final padding = compact ? 12.0 : 16.0;
        final iconSize = compact ? 24.0 : 26.0;
        final iconBox = compact ? 38.0 : 44.0;
        final valueFont = compact ? 21.0 : 24.0;
        final gap1 = compact ? 6.0 : 8.0;
        final gap2 = compact ? 2.0 : 4.0;
        final labelFont = compact ? 11.0 : 12.0;

        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.light),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: iconBox,
                height: iconBox,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: iconSize, color: AppColors.deep),
              ),
              SizedBox(height: gap1),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: valueFont,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deep,
                  ),
                ),
              ),
              SizedBox(height: gap2),
              Text(
                label,
                style: TextStyle(
                  fontSize: labelFont,
                  color: AppColors.neutral,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.light),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.purple, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deep,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentlyAddedCard extends StatelessWidget {
  const _RecentlyAddedCard({required this.device, required this.onTap});

  final DeviceRecord device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 132,
        height: 168,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.light),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 74,
              decoration: BoxDecoration(
                color: AppColors.overlay,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child:
                    (device.imageThumbBase64 != null &&
                        device.imageThumbBase64!.trim().isNotEmpty)
                    ? Image.memory(
                        base64Decode(device.imageThumbBase64!),
                        fit: BoxFit.contain,
                      )
                    : Icon(
                        _getCategoryIcon(device.category),
                        size: 30,
                        color: AppColors.purple,
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deep,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    device.category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.neutral,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
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
        return Icons.laptop;
      case 'appliances':
        return Icons.kitchen;
      default:
        return Icons.inventory_2;
    }
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.box, required this.onTap});

  final StorageBox box;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 176,
        height: 176,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.light),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.overlay,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child:
                    (box.imageThumbBase64 != null &&
                        box.imageThumbBase64!.trim().isNotEmpty)
                    ? Image.memory(
                        base64Decode(box.imageThumbBase64!),
                        fit: BoxFit.contain,
                      )
                    : const Icon(
                        Icons.inventory_2,
                        size: 30,
                        color: AppColors.purple,
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    box.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deep,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    box.location,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.neutral,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${box.compartments} compartments',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.neutral.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
