import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/hive_service.dart';
import 'auth_provider.dart';
import 'books_provider.dart';

/// Rebuilds when books change and streams local entry updates, including sync.
final analyticsEntriesProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      if (!ref.watch(isLoggedInProvider)) return Stream.value([]);
      final books = ref.watch(booksProvider);
      if (books.hasError) {
        Error.throwWithStackTrace(books.error!, books.stackTrace!);
      }
      final ids = (books.asData?.value ?? []).map((book) => book['id']).toSet();
      if (ids.isEmpty) return Stream.value([]);
      final box = HiveService().entriesBox;
      List<Map<String, dynamic>> read() => [
        for (final entry in box.values)
          if (ids.contains(entry['book_id'])) Map<String, dynamic>.from(entry),
      ];
      final initial = read();
      final controller = StreamController<List<Map<String, dynamic>>>();
      final subscription = box.watch().listen((_) {
        try {
          controller.add(read());
        } catch (error, stack) {
          controller.addError(error, stack);
        }
      }, onError: controller.addError);
      controller.add(initial);
      ref.onDispose(() {
        unawaited(subscription.cancel());
        unawaited(controller.close());
      });
      return controller.stream;
    });
