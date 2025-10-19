import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String? get _householdId => null; // TODO: wire real household selection

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }

    final devicesCol = firestore.collection('devices');
    final boxesCol = firestore.collection('storageBoxes');

    final overallCounts = Future.wait<int>([
      devicesCol.where('createdBy', isEqualTo: user.uid).count().get().then((v) => v.count ?? 0),
      devicesCol.where('createdBy', isEqualTo: user.uid).where('status', isEqualTo: 'working').count().get().then((v) => v.count ?? 0),
      devicesCol.where('createdBy', isEqualTo: user.uid).where('status', isEqualTo: 'needs-repair').count().get().then((v) => v.count ?? 0),
      devicesCol.where('createdBy', isEqualTo: user.uid).where('status', isEqualTo: 'broken').count().get().then((v) => v.count ?? 0),
      boxesCol.where('createdBy', isEqualTo: user.uid).count().get().then((v) => v.count ?? 0),
    ]);

    final recentDevicesStream = devicesCol
        .where('createdBy', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FutureBuilder<List<int>>(
              future: overallCounts,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const _StatsGrid(loading: true);
                }
                final data = snap.data!; // [total, working, needsRepair, broken, boxes]
                return _StatsGrid(
                  total: data[0],
                  working: data[1],
                  needsRepair: data[2],
                  broken: data[3],
                  boxes: data[4],
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/devices/add'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Device'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/storage'),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Manage Storage'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Recent Devices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: recentDevicesStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No recent devices'),
                  );
                }
                return Column(
                  children: docs.map((d) {
                    final m = d.data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text(m['name'] ?? ''),
                        subtitle: Text((m['status'] ?? 'unknown').toString()),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final bool loading;
  final int? total;
  final int? working;
  final int? needsRepair;
  final int? broken;
  final int? boxes;
  const _StatsGrid({this.loading = false, this.total, this.working, this.needsRepair, this.broken, this.boxes});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCard(title: 'Total Devices', value: loading ? null : total),
      _StatCard(title: 'Working', value: loading ? null : working, color: const Color(0xFF10B981)),
      _StatCard(title: 'Needs Repair', value: loading ? null : needsRepair, color: const Color(0xFFF59E0B)),
      _StatCard(title: 'Broken', value: loading ? null : broken, color: const Color(0xFFEF4444)),
      _StatCard(title: 'Storage Boxes', value: loading ? null : boxes),
    ];
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.6,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: cards,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int? value;
  final Color? color;
  const _StatCard({required this.title, this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontFamily: 'Poppins', color: Colors.black54)),
          const SizedBox(height: 6),
          value == null
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, fontFamily: 'Poppins', color: color ?? Colors.black)),
        ],
      ),
    );
  }
}


