import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lankar/navigation/app_bottom_nav.dart';
import 'package:lankar/providers/auth_provider.dart';
import 'package:lankar/providers/books_provider.dart';
import 'package:lankar/screens/books/book_list_screen.dart';
import 'package:lankar/screens/books/cash_entry_screen.dart';
import 'package:lankar/services/hive_service.dart';
import 'package:lankar/services/hybrid_storage_service.dart';
import 'package:lankar/utils/app_theme.dart';
import 'package:lankar/utils/constants.dart';
import 'package:lankar/widgets/app_feedback.dart';
import 'package:lankar/widgets/book_card_widget.dart';
import 'package:lankar/widgets/books_design.dart';

List<Map<String, dynamic>> _sampleBooks() => [
  for (final (id, name, balance, days) in [
    ('b1', 'Everyday spending', 3420.5, 0),
    ('b2', 'Savings & goals', 5100.0, 2),
    ('b3', 'Travel fund', -68.5, 4),
  ])
    {
      'id': id,
      'name': name,
      'balance': balance,
      'created_at': DateTime.now()
          .subtract(Duration(days: days))
          .toIso8601String(),
      'synced': id != 'b3',
    },
];

class _BooksTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => !const bool.fromEnvironment('CAPTURE_PREVIEWS');
}

class _Books extends BooksNotifier {
  _Books(this.records, {this.loadError = false})
    : super(HybridStorageService(), null);
  List<Map<String, dynamic>> records;
  bool loadError;
  bool failCreate = false;
  bool failRename = false;
  bool failDelete = false;
  int loads = 0;
  int creates = 0;
  int renames = 0;
  int deletes = 0;
  Completer<void>? gate;

  @override
  Future<void> loadBooks() async {
    loads++;
    state = loadError
        ? AsyncValue.error(const SocketException('fixture'), StackTrace.current)
        : AsyncValue.data(List.of(records));
  }

  @override
  Future<Map<String, dynamic>?> createBook(String name) async {
    creates++;
    await gate?.future;
    if (failCreate) throw const SocketException('fixture');
    final book = {
      'id': 'new-$creates',
      'name': name,
      'balance': 0.0,
      'created_at': DateTime.now().toIso8601String(),
      'synced': false,
    };
    records = [book, ...records];
    await loadBooks();
    return book;
  }

  @override
  Future<bool> renameBook(String bookId, String newName) async {
    renames++;
    if (failRename) throw const SocketException('fixture');
    records = [
      for (final book in records)
        if (book['id'] == bookId) {...book, 'name': newName} else book,
    ];
    await loadBooks();
    return true;
  }

  @override
  Future<bool> deleteBook(String bookId) async {
    deletes++;
    if (failDelete) throw const SocketException('fixture');
    records = records.where((book) => book['id'] != bookId).toList();
    await loadBooks();
    return true;
  }
}

void main() {
  _BooksTestBinding();
  late Directory hiveDirectory;
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final font = Platform.environment['AUTH_PREVIEW_FONT'];
    if (font != null) {
      final loader = FontLoader('Roboto')
        ..addFont(File(font).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
    hiveDirectory = await Directory.systemTemp.createTemp('lankar-books-test-');
    Hive.init(hiveDirectory.path);
    HiveService().syncQueueBox = await Hive.openBox<Map>('books-test-sync');
    HiveService().entriesBox = await Hive.openBox<Map>('books-test-entries');
    HiveService().booksBox = await Hive.openBox<Map>('books-test-books');
  });
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({PrefKeys.selectedCurrency: 1}),
  );
  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  Widget app({
    bool dark = false,
    double scale = 1,
    bool empty = false,
    bool signedIn = true,
    bool loadError = false,
    double keyboard = 0,
  }) => ProviderScope(
    overrides: [
      isLoggedInProvider.overrideWithValue(signedIn),
      booksProvider.overrideWith(
        (_) => _Books(empty ? [] : _sampleBooks(), loadError: loadError),
      ),
    ],
    child: MaterialApp(
      scaffoldMessengerKey: AppFeedback.messengerKey,
      theme: dark ? AppTheme.dark : AppTheme.light,
      themeAnimationDuration: Duration.zero,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: RepaintBoundary(
          key: const ValueKey('books-preview'),
          child: child!,
        ),
      ),
      home: Scaffold(
        body: const BookListScreen(),
        bottomNavigationBar: AppBottomNav(selectedIndex: 1, onTap: (_) {}),
      ),
    ),
  );

  Future<void> show(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1,
    bool empty = false,
    bool signedIn = true,
    bool loadError = false,
    double keyboard = 0,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        dark: dark,
        scale: scale,
        empty: empty,
        signedIn: signedIn,
        loadError: loadError,
        keyboard: keyboard,
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/icon/app_icon.png'),
        tester.element(find.byType(BookListScreen)),
      ),
    );
    await tester.pumpAndSettle();
  }

  _Books notifier(WidgetTester tester) =>
      ProviderScope.containerOf(
            tester.element(find.byType(BookListScreen)),
          ).read(booksProvider.notifier)
          as _Books;

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('books-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/design-previews/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> manage(WidgetTester tester, String name, String action) async {
    final menu = find.byTooltip('Manage $name');
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
    expect(find.byType(CashEntryScreen), findsNothing);
  }

  testWidgets('real balances, negative values, themes and entry navigation', (
    tester,
  ) async {
    await show(tester);
    expect(find.textContaining('8,452.00'), findsOneWidget);
    expect(find.text('Cash books'), findsOneWidget);
    await capture(tester, 'books');
    final books = notifier(tester);
    await tester.ensureVisible(find.text('Everyday spending'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Everyday spending'));
    await tester.pumpAndSettle();
    expect(find.byType(CashEntryScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(books.loads, 2);
    await tester.scrollUntilVisible(find.text('Travel fund'), 180);
    await tester.pumpAndSettle();
    expect(find.textContaining('-68.50'), findsOneWidget);
    expect(find.text('Saved on device'), findsOneWidget);
    await capture(tester, 'books-list');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await show(tester, dark: true);
    await capture(tester, 'books-dark');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'search, clear and sorting work without changing combined totals',
    (tester) async {
      await show(tester);
      await tester.enterText(
        find.byKey(const ValueKey('book-search')),
        '  SAVINGS  ',
      );
      await tester.pumpAndSettle();
      expect(find.text('Savings & goals'), findsOneWidget);
      expect(find.text('Everyday spending'), findsNothing);
      expect(find.textContaining('8,452.00'), findsOneWidget);
      expect(find.text('1 of 3 books'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('book-search')),
        'no such book',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching books'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sort cash books'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Highest balance'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<BookCardWidget>(find.byType(BookCardWidget))
            .first
            .book['id'],
        'b2',
      );
      await tester.tap(find.byTooltip('Sort cash books'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name A-Z'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<BookCardWidget>(find.byType(BookCardWidget))
            .first
            .book['id'],
        'b1',
      );
      await tester.tap(find.byTooltip('Refresh cash books'));
      await tester.pumpAndSettle();
      expect(notifier(tester).loads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'create validates, keeps failed input, blocks duplicates and confirms saved result',
    (tester) async {
      await show(tester);
      final books = notifier(tester)..failCreate = true;
      await tester.tap(find.text('New book'));
      await tester.pumpAndSettle();
      await capture(tester, 'books-create');
      await tester.tap(find.text('Create book'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a book name'), findsOneWidget);
      expect(books.creates, 0);
      await tester.enterText(
        find.byKey(const ValueKey('book-name')),
        '  Holiday plans  ',
      );
      await tester.tap(find.text('Create book'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('book-name')))
            .controller!
            .text,
        '  Holiday plans  ',
      );
      expect(find.byType(FeedbackCard), findsOneWidget);
      books.failCreate = false;
      books.gate = Completer<void>();
      await tester.tap(find.text('Create book'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final saveButton = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(saveButton.onPressed, isNull);
      expect(books.creates, 2);
      books.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(books.records.first['name'], 'Holiday plans');
      expect(find.text('Cash book created'), findsOneWidget);
      expect(find.textContaining('Saved on this device.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rename preserves failed input and confirms only a successful rename',
    (tester) async {
      await show(tester);
      final books = notifier(tester)..failRename = true;
      await manage(tester, 'Everyday spending', 'Rename');
      await tester.enterText(
        find.byKey(const ValueKey('book-name')),
        'Daily spending',
      );
      await tester.tap(find.text('Save name'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(books.records.first['name'], 'Everyday spending');
      expect(find.text('Cash book renamed'), findsNothing);
      books.failRename = false;
      await tester.tap(find.text('Save name'));
      await tester.pumpAndSettle();
      expect(books.records.first['name'], 'Daily spending');
      expect(find.text('Cash book renamed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('delete confirms, cancels and retains the book on failure', (
    tester,
  ) async {
    await show(tester);
    final books = notifier(tester)..failDelete = true;
    await manage(tester, 'Everyday spending', 'Delete');
    await tester.tap(find.text('Keep book'));
    await tester.pumpAndSettle();
    expect(books.deletes, 0);
    await manage(tester, 'Everyday spending', 'Delete');
    await tester.tap(find.text('Delete book'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(books.records.length, 3);
    expect(find.text('Cash book deleted'), findsNothing);
    books.failDelete = false;
    await tester.tap(find.text('Delete book'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(books.records.length, 2);
    expect(find.text('Cash book deleted'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty, signed-out and retry states are actionable', (
    tester,
  ) async {
    await show(tester, empty: true);
    expect(find.text('Give your money a home'), findsOneWidget);
    await capture(tester, 'books-empty');
    await tester.ensureVisible(find.text('Create your first book'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create your first book'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await show(tester, signedIn: false);
    expect(find.text('Sign in to Lankar'), findsOneWidget);
    expect(find.text('New book'), findsNothing);
    expect(find.byType(BooksSummaryCard), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await show(tester, loadError: true);
    expect(find.text('Try again'), findsOneWidget);
    notifier(tester).loadError = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Everyday spending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small dark layout and dialog fit enlarged text and keyboard', (
    tester,
  ) async {
    await show(tester, dark: true, scale: 1.6, size: const Size(320, 640));
    await capture(tester, 'books-large-text');
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('New book'));
    await tester.pumpAndSettle();
    await capture(tester, 'books-dialog-large-text');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await show(tester, keyboard: 260, size: const Size(320, 640));
    await tester.tap(find.text('New book'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('book-name')),
      'A long cash book name',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'book artwork animates and respects reduced motion and inactive tabs',
    (tester) async {
      Widget artwork({bool reduced = false, bool active = true}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: TickerMode(enabled: active, child: const BookStackArtwork()),
        ),
      );
      List<double> matrix() => List.of(
        tester
            .widget<Transform>(
              find.descendant(
                of: find.byType(BookStackArtwork),
                matching: find.byType(Transform),
              ),
            )
            .transform
            .storage,
      );
      await tester.pumpWidget(artwork());
      final initial = matrix();
      await tester.pump(const Duration(seconds: 1));
      expect(matrix(), isNot(initial));
      await tester.pumpWidget(artwork(reduced: true));
      final still = matrix();
      await tester.pump(const Duration(seconds: 1));
      expect(matrix(), still);
      await tester.pumpWidget(artwork(active: false));
      final paused = matrix();
      await tester.pump(const Duration(seconds: 1));
      expect(matrix(), paused);
      expect(tester.takeException(), isNull);
    },
  );
}
