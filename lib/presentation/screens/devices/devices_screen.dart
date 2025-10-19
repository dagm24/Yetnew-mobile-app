import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  bool grid = true;
  String? status;
  String? category;
  String? location;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Sign in required')));
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('devices');
    if (status != null && status!.isNotEmpty) q = q.where('status', isEqualTo: status);
    if (category != null && category!.isNotEmpty) q = q.where('category', isEqualTo: category);
    if (location != null && location!.isNotEmpty) q = q.where('location', isEqualTo: location);
    q = q.orderBy('created_at', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(icon: Icon(grid ? Icons.view_list : Icons.grid_view), onPressed: () => setState(() => grid = !grid)),
          IconButton(icon: const Icon(Icons.filter_list), onPressed: _openFilters),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/devices/add'),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No devices'));
          }
          if (grid) {
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: .9, crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemCount: docs.length,
              itemBuilder: (context, i) => _DeviceCard(doc: docs[i]),
            );
          } else {
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (context, i) => _DeviceTile(doc: docs[i]),
            );
          }
        },
      ),
    );
  }

  void _openFilters() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        String? tempStatus = status;
        String? tempCategory = category;
        String? tempLocation = location;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), TextButton(onPressed: () { setState(() { status = category = location = null; }); Navigator.pop(context); }, child: const Text('Clear'))]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: tempStatus,
                hint: const Text('Status'),
                items: const [
                  DropdownMenuItem(value: 'working', child: Text('Working')),
                  DropdownMenuItem(value: 'needs-repair', child: Text('Needs Repair')),
                  DropdownMenuItem(value: 'broken', child: Text('Broken')),
                ],
                onChanged: (v) => tempStatus = v,
              ),
              const SizedBox(height: 12),
              TextFormField(decoration: const InputDecoration(labelText: 'Category'), initialValue: tempCategory, onChanged: (v) => tempCategory = v.trim()),
              const SizedBox(height: 12),
              TextFormField(decoration: const InputDecoration(labelText: 'Location'), initialValue: tempLocation, onChanged: (v) => tempLocation = v.trim()),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() { status = tempStatus; category = tempCategory; location = tempLocation; });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply Filters'),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _DeviceCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    return InkWell(
      onTap: () => context.push('/devices/${doc.id}'),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 6))]),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8), image: m['image_url'] != null ? DecorationImage(image: NetworkImage(m['image_url']), fit: BoxFit.cover) : null),
                child: m['image_url'] == null ? const Icon(Icons.image, color: Colors.black26) : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(m['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            _StatusBadge(status: m['status'] ?? 'unknown'),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _DeviceTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundImage: m['image_url'] != null ? NetworkImage(m['image_url']) : null, child: m['image_url'] == null ? const Icon(Icons.image) : null),
        title: Text(m['name'] ?? ''),
        subtitle: Text('${m['category'] ?? ''} • ${m['location'] ?? ''}'),
        trailing: _StatusBadge(status: m['status'] ?? 'unknown'),
        onTap: () => context.push('/devices/${doc.id}'),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case 'working':
        return const Color(0xFF10B981);
      case 'needs-repair':
        return const Color(0xFFF59E0B);
      case 'broken':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _color.withOpacity(.12), borderRadius: BorderRadius.circular(999)),
      child: Text(status, style: TextStyle(color: _color, fontSize: 12)),
    );
  }
}


