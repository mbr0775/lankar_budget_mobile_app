// lib/widgets/sync_indicator_widget.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/hybrid_storage_service.dart';

class SyncIndicator extends StatefulWidget {
  const SyncIndicator({super.key});

  @override
  State<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<SyncIndicator> {
  final HybridStorageService _storage = HybridStorageService();
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Map>>(
      valueListenable: _storage.syncQueueBox.listenable(),
      builder: (context, box, _) {
        final count    = box.length;
        final isOnline = _storage.isOnline;

        return GestureDetector(
          onTap: (isOnline && count > 0) ? _manualSync : null,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (isOnline ? Colors.green : Colors.orange)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isOnline ? Colors.green : Colors.orange,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOnline ? Icons.cloud_done : Icons.cloud_off,
                  size: 14,
                  color: isOnline ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isOnline ? Colors.green : Colors.orange,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ],
                if (isOnline && count > 0) ...[
                  const SizedBox(width: 6),
                  _isSyncing
                      ? const SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blue)))
                      : const Icon(Icons.sync,
                          size: 14, color: Colors.blue),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _manualSync() async {
    setState(() => _isSyncing = true);
    try {
      await _storage.syncWithSupabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sync completed!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }
}