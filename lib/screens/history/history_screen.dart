import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/activity_log.dart';
import '../../services/activity_service.dart';
import '../../services/device_repository.dart';
import '../../services/household_service.dart';
import '../../theme/app_colors.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _activityService = ActivityService(FirebaseFirestore.instance);
  final _householdService = HouseholdService(FirebaseFirestore.instance);
  final _repo = DeviceRepository(FirebaseFirestore.instance);
  final _user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) return const Center(child: Text('Please log in'));

    return FutureBuilder<String?>(
      future: _householdService.getUserHouseholdId(user.uid),
      builder: (context, householdSnap) {
        if (!householdSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final householdId = householdSnap.data;
        if (householdId == null) {
          return const Center(child: Text('No household found'));
        }

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Expanded(
                  child: StreamBuilder<List<StorageBox>>(
                    stream: _repo.streamStorageBoxes(householdId),
                    builder: (context, boxSnap) {
                      final boxLabelById = <String, String>{
                        for (final b in boxSnap.data ?? const <StorageBox>[])
                          b.id: b.label,
                      };

                      return StreamBuilder<List<ActivityLog>>(
                        stream: _activityService.streamActivities(householdId),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            final error = snapshot.error.toString();
                            final isPermissionError = error.contains(
                              'permission-denied',
                            );
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 64,
                                      color: AppColors.danger,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      isPermissionError
                                          ? 'Permission Denied'
                                          : 'Error Loading History',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.deep,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isPermissionError
                                          ? 'You don\'t have permission to view history. Please make sure you are a member of this household.'
                                          : error,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.neutral,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final activities = snapshot.data!;
                          if (activities.isEmpty) {
                            return const Center(
                              child: Text(
                                'No activity yet',
                                style: TextStyle(color: AppColors.neutral),
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            itemCount: activities.length,
                            itemBuilder: (context, index) {
                              final activity = activities[index];
                              final isLast = index == activities.length - 1;
                              final prevActivity = index > 0
                                  ? activities[index - 1]
                                  : null;
                              final showTimestamp =
                                  prevActivity == null ||
                                  !_isSameDay(
                                    activity.timestamp,
                                    prevActivity.timestamp,
                                  );
                              return Column(
                                children: [
                                  if (showTimestamp) ...[
                                    const SizedBox(height: 16),
                                    Center(
                                      child: Text(
                                        _formatTimestamp(activity.timestamp),
                                        style: TextStyle(
                                          color: AppColors.neutral,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  _TimelineItem(
                                    activity: activity,
                                    isLast: isLast,
                                    storageBoxLabels: boxLabelById,
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activityDate = DateTime(date.year, date.month, date.day);

    if (activityDate == today) {
      return DateFormat('h:mm a').format(date);
    } else if (activityDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.deep),
                onPressed: () => Navigator.pop(context),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.purple,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'History',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.deep,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'All device activity in your household',
            style: TextStyle(fontSize: 14, color: AppColors.neutral),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Filters'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.purple,
              side: const BorderSide(color: AppColors.paleLavender),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final ActivityLog activity;
  final bool isLast;
  final Map<String, String> storageBoxLabels;

  const _TimelineItem({
    required this.activity,
    required this.isLast,
    this.storageBoxLabels = const <String, String>{},
  });

  String _boxLabel(dynamic boxId) {
    final id = (boxId ?? '').toString().trim();
    if (id.isEmpty) return 'Unknown';
    return storageBoxLabels[id] ?? id;
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Line & Dot
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _getColorForAction(activity.actionType),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppColors.paleLavender),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(),
                  const SizedBox(height: 12),
                  _buildCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForAction(String action) {
    switch (action.toLowerCase()) {
      case 'added':
        return AppColors.success;
      case 'moved':
        return AppColors.info;
      case 'status':
      case 'changed status':
        return AppColors.warning;
      default:
        return AppColors.purple;
    }
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.softLavender,
          backgroundImage: activity.userAvatar.startsWith('http')
              ? NetworkImage(activity.userAvatar)
              : null,
          child: !activity.userAvatar.startsWith('http')
              ? Text(
                  activity.userAvatar.trim().isNotEmpty
                      ? activity.userAvatar.trim().substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.purple,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: AppColors.deep, fontSize: 14),
              children: [
                TextSpan(
                  text: activity.userName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ' '),
                TextSpan(
                  text: _formatAction(activity.actionType),
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _timeAgo(activity.timestamp),
          style: TextStyle(color: AppColors.neutral, fontSize: 12),
        ),
      ],
    );
  }

  String _formatAction(String action) {
    switch (action.toLowerCase()) {
      case 'added':
        return 'added.';
      case 'moved':
        return 'moved.';
      case 'status':
      case 'changed status':
        return 'changed status.';
      case 'deleted':
      case 'removed':
        return 'removed.';
      default:
        return '$action.';
    }
  }

  Widget _buildCard() {
    final action = activity.actionType.toLowerCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.paleLavender),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (action == 'added') _buildAddedContent(),
          if (action == 'moved') _buildMovedContent(),
          if (action.contains('changed') || action.contains('status'))
            _buildStatusContent(),
          if (action == 'deleted' || action == 'removed')
            _buildDeletedContent(),
          if (action != 'added' &&
              action != 'moved' &&
              !(action.contains('changed') || action.contains('status')) &&
              action != 'deleted' &&
              action != 'removed')
            _buildGenericContent(),
        ],
      ),
    );
  }

  Widget _buildAddedContent() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.softLavender,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getDeviceIcon(activity.itemType),
            color: AppColors.purple,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.itemName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.deep,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Tag(text: activity.itemType),
                  if (activity.details['location'] != null) ...[
                    const Text('•', style: TextStyle(color: AppColors.neutral)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: AppColors.neutral,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          activity.details['location'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.neutral,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (activity.details['storageBoxId'] != null) ...[
                    const Text('•', style: TextStyle(color: AppColors.neutral)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.inventory_2,
                          size: 14,
                          color: AppColors.neutral,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Box ${_boxLabel(activity.details['storageBoxId'])}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.neutral,
                          ),
                        ),
                        if (activity.details['compartmentNumber'] != null)
                          Text(
                            ' • Compartment ${activity.details['compartmentNumber']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.neutral,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMovedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activity.itemName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.deep,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _LocationBox(
                label: 'From',
                value: activity.details['from'] ?? 'Unknown',
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.arrow_forward,
                color: AppColors.purple,
                size: 20,
              ),
            ),
            Expanded(
              child: _LocationBox(
                label: 'To',
                value: activity.details['to'] ?? 'Unknown',
                isHighlight: true,
              ),
            ),
          ],
        ),
        if (activity.details['storageBoxId'] != null ||
            activity.details.containsKey('compartmentNumber')) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Storage updated',
                style: TextStyle(fontSize: 12, color: AppColors.neutral),
              ),
              const SizedBox(width: 8),
              if (activity.details['fromBox'] != null ||
                  activity.details['fromCompartment'] != null) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2,
                      size: 12,
                      color: AppColors.neutral,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activity.details['fromBox'] != null
                          ? 'Box ${_boxLabel(activity.details['fromBox'])}'
                          : 'Comp. ${activity.details['fromCompartment']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.neutral,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward,
                  size: 12,
                  color: AppColors.neutral,
                ),
                const SizedBox(width: 4),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.inventory_2,
                    size: 12,
                    color: AppColors.neutral,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    activity.details['storageBoxId'] != null
                        ? 'Box ${_boxLabel(activity.details['storageBoxId'])}'
                        : 'Comp. ${activity.details['compartmentNumber']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.neutral,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStatusContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.itemName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.deep,
                ),
              ),
              const SizedBox(height: 8),
              _Tag(
                text: activity.details['newStatus'] ?? 'Updated',
                color: AppColors.warning,
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.purple,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_fix_high, color: Colors.white, size: 20),
        ),
      ],
    );
  }

  Widget _buildDeletedContent() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.overlay,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.delete_outline, color: AppColors.danger),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.itemName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.deep,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _Tag(text: activity.itemType),
                  const SizedBox(width: 8),
                  const Text(
                    'Removed',
                    style: TextStyle(fontSize: 12, color: AppColors.neutral),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenericContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activity.itemName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.deep,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _Tag(text: activity.itemType),
            const SizedBox(width: 8),
            Text(
              activity.actionType,
              style: const TextStyle(fontSize: 12, color: AppColors.neutral),
            ),
          ],
        ),
      ],
    );
  }

  IconData _getDeviceIcon(String itemType) {
    switch (itemType.toLowerCase()) {
      case 'device':
        return Icons.devices;
      case 'storage':
        return Icons.inventory_2;
      default:
        return Icons.inventory_2;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 1) return '${diff.inDays} days ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inHours > 1) return '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mins ago';
    return 'Just now';
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color? color;

  const _Tag({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppColors.info).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color ?? AppColors.info,
        ),
      ),
    );
  }
}

class _LocationBox extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _LocationBox({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlight ? AppColors.paleLavender : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlight
              ? AppColors.purple.withOpacity(0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.neutral)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.deep,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
