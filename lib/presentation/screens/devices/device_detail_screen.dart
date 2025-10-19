import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DeviceDetailScreen extends StatelessWidget {
  final String deviceId;
  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.collection('devices').doc(deviceId);
    return Scaffold(
      appBar: AppBar(title: const Text('Device Detail')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: docRef.get(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final m = snap.data!.data();
          if (m == null) return const Center(child: Text('Not found'));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    image: m['image_url'] != null ? DecorationImage(image: NetworkImage(m['image_url']), fit: BoxFit.cover) : null,
                  ),
                  child: m['image_url'] == null ? const Icon(Icons.image, size: 48, color: Colors.black26) : null,
                ),
                const SizedBox(height: 16),
                Text(m['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Category: ${m['category'] ?? '-'}'),
                Text('Location: ${m['location'] ?? '-'}'),
                Text('Status: ${m['status'] ?? '-'}'),
                Text('Compartment: ${m['compartment_number'] ?? '-'}'),
                const SizedBox(height: 16),
                Text(m['notes'] ?? '', style: const TextStyle(color: Colors.black87)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _EditLauncher(deviceId: deviceId))),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Delete Device'),
                              content: const Text('Are you sure you want to delete this device?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await docRef.delete();
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EditLauncher extends StatelessWidget {
  final String deviceId;
  const _EditLauncher({required this.deviceId});

  @override
  Widget build(BuildContext context) {
    // Lazy import to avoid circulars
    return const SizedBox.shrink();
  }
}


