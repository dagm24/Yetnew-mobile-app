import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/device_repository.dart';
import '../../services/household_service.dart';
import '../../theme/app_colors.dart';
import '../family/setup_household_screen.dart';
import 'add_storage_box_screen.dart';
import 'storage_box_detail_screen.dart';

class StorageListScreen extends StatefulWidget {
  const StorageListScreen({super.key});

  @override
  State<StorageListScreen> createState() => _StorageListScreenState();
}

class _StorageListScreenState extends State<StorageListScreen> {
  final _repo = DeviceRepository(FirebaseFirestore.instance);
  final _householdService = HouseholdService(FirebaseFirestore.instance);
  final _user = FirebaseAuth.instance.currentUser;
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _householdService.getUserHouseholdId(_user?.uid ?? ''),
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
                        color: AppColors.deep,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Create or join a household to manage storage.',
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
              'Storage Boxes',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.deep,
              ),
            ),
            actions: [
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddStorageBoxScreen(),
                  ),
                ),
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                label: const Text(
                  'Create Box',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
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
                        child: Row(
                          children: [
                            Expanded(
                              child: _ViewToggleButton(
                                icon: Icons.grid_view,
                                label: 'Grid',
                                selected: _isGridView,
                                onTap: () => setState(() => _isGridView = true),
                              ),
                            ),
                            Expanded(
                              child: _ViewToggleButton(
                                icon: Icons.list,
                                label: 'List',
                                selected: !_isGridView,
                                onTap: () =>
                                    setState(() => _isGridView = false),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<StorageBox>>(
                  stream: _repo.streamStorageBoxes(householdId),
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
                                    : 'Error Loading Storage',
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
                    final boxes = snapshot.data!;
                    if (boxes.isEmpty) {
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
                              'No storage boxes yet',
                              style: TextStyle(
                                color: AppColors.neutral,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddStorageBoxScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Create Your First Box'),
                            ),
                          ],
                        ),
                      );
                    }
                    if (_isGridView) {
                      return GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.85,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: boxes.length,
                        itemBuilder: (context, index) {
                          final box = boxes[index];
                          return _StorageBoxCard(
                            box: box,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    StorageBoxDetailScreen(boxId: box.id),
                              ),
                            ),
                          );
                        },
                      );
                    } else {
                      return ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: boxes.length,
                        itemBuilder: (context, index) {
                          final box = boxes[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _StorageBoxListCard(
                              box: box,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      StorageBoxDetailScreen(boxId: box.id),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: null,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddStorageBoxScreen()),
            ),
            backgroundColor: AppColors.purple,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.softLavender : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.purple : AppColors.neutral,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.purple : AppColors.neutral,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageBoxCard extends StatelessWidget {
  const _StorageBoxCard({required this.box, required this.onTap});

  final StorageBox box;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.light,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child:
                    (box.imageThumbBase64 != null &&
                        box.imageThumbBase64!.trim().isNotEmpty)
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: Image.memory(
                          base64Decode(box.imageThumbBase64!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : (box.imageUrl != null && box.imageUrl!.trim().isNotEmpty)
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: Image.network(box.imageUrl!, fit: BoxFit.cover),
                      )
                    : Icon(
                        Icons.inventory_2,
                        size: 48,
                        color: AppColors.purple,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    box.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.grid_view,
                        text: '${box.compartments} compartments',
                      ),
                      _InfoChip(
                        icon: Icons.inventory_2,
                        text: '${box.itemCount} items',
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
}

class _StorageBoxListCard extends StatelessWidget {
  const _StorageBoxListCard({required this.box, required this.onTap});

  final StorageBox box;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.light,
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  (box.imageThumbBase64 != null &&
                      box.imageThumbBase64!.trim().isNotEmpty)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(box.imageThumbBase64!),
                        fit: BoxFit.cover,
                      ),
                    )
                  : (box.imageUrl != null && box.imageUrl!.trim().isNotEmpty)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(box.imageUrl!, fit: BoxFit.cover),
                    )
                  : Icon(Icons.inventory_2, size: 32, color: AppColors.purple),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    box.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deep,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    box.location,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.neutral,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.grid_view,
                        text: '${box.compartments} compartments',
                      ),
                      _InfoChip(
                        icon: Icons.inventory_2,
                        text: '${box.itemCount} items',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.neutral),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.softLavender,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.purple),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.deep,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
