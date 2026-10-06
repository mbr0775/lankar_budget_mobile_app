// lib/widgets/sync_indicator_widget.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/hybrid_storage_service.dart';
import '../utils/app_errors.dart';
import 'app_feedback.dart';

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
        final count = box.length;
        final isOnline = _storage.isOnline;

        return GestureDetector(
          onTap: (isOnline && count > 0) ? _manualSync : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (isOnline ? Colors.green : Colors.orange).withValues(
                alpha: 0.15,
              ),
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
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                if (isOnline && count > 0) ...[
                  const SizedBox(width: 6),
                  _isSyncing
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        )
                      : const Icon(Icons.sync, size: 14, color: Colors.blue),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _manualSync() async {
    if (_isSyncing) return;
    if (_storage.isSyncing) {
      AppFeedback.info(
        context,
        'Sync in progress',
        'Your pending changes are already being synced.',
      );
      return;
    }
    setState(() => _isSyncing = true);
    try {
      final complete = await _storage.syncWithSupabase(retryFailed: true);
      if (!mounted) return;
      if (complete) {
        AppFeedback.success(
          context,
          'All changes synced',
          'Your cash books are up to date.',
        );
      } else {
        final failure = _storage.lastSyncFailure;
        if (failure != null && failure.kind != FailureKind.network) {
          AppFeedback.error(
            context,
            AppFailure(
              failure.title,
              '${failure.message} Pending changes are still kept on this device.',
              kind: failure.kind,
            ),
          );
          return;
        }
        final pending = await _storage.getUnsyncedCount();
        if (mounted) {
          AppFeedback.warning(
            context,
            'Some changes still need to sync',
            '$pending pending changes are kept on this device. Check your connection and tap sync to retry.',
          );
        }
      }
    } catch (error, stack) {
      AppErrors.report('Manual sync', error, stack);
      if (mounted) {
        AppFeedback.error(
          context,
          error,
          fallback:
              'Could not sync your changes. They are still saved on this device.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }
}
