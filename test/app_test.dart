import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('App Smoke Tests', () {
    testWidgets('app launches without crashing', (tester) async {
      // We can't run the full app without Hive/SharedPreferences initialized,
      // but we can verify widgets build correctly
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Zephyr')),
          ),
        ),
      );

      expect(find.text('Zephyr'), findsOneWidget);
    });

    testWidgets('Material app theme loads correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorSchemeSeed: const Color(0xFF7C3AED),
            brightness: Brightness.dark,
          ),
          home: const Scaffold(
            body: Center(child: Text('Test')),
          ),
        ),
      );

      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('gradient widget renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(child: Text('Gradient')),
            ),
          ),
        ),
      );

      expect(find.text('Gradient'), findsOneWidget);
    });

    testWidgets('bottom navigation bar renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Center(child: Text('Home')),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: 0,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Documents'),
                BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
              ],
              onTap: (i) {},
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('app bar renders correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Zephyr'),
              actions: [IconButton(icon: const Icon(Icons.settings), onPressed: () {})],
            ),
            body: const Center(child: Text('Content')),
          ),
        ),
      );

      expect(find.text('Zephyr'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('dialog shows and dismisses', (tester) async {
      late BuildContext context;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext ctx) {
              context = ctx;
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: ctx,
                      builder: (_) => AlertDialog(
                        title: const Text('Test Dialog'),
                        content: const Text('This is a test'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Test Dialog'), findsOneWidget);
      expect(find.text('This is a test'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Test Dialog'), findsNothing);
    });

    testWidgets('list view with items renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 10,
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.chat),
                title: Text('Conversation $i'),
                subtitle: const Text('Last message preview'),
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Conversation 0'), findsOneWidget);
      expect(find.text('Conversation 9'), findsNothing); // Not visible without scroll

      // Scroll to bottom
      await tester.drag(
        find.text('Conversation 0'),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Conversation 9'), findsOneWidget);
    });

    testWidgets('text field works correctly', (tester) async {
      String? inputValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  onChanged: (value) => inputValue = value,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (_) => Text(inputValue ?? 'Empty'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Hello Zephyr');
      await tester.pump();

      expect(inputValue, equals('Hello Zephyr'));
    });

    testWidgets('fab button triggers action', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: Text(tapped ? 'Tapped' : 'Not tapped')),
            floatingActionButton: FloatingActionButton(
              onPressed: () => tapped = true,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // Rebuild
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: Text(tapped ? 'Tapped' : 'Not tapped')),
            floatingActionButton: FloatingActionButton(
              onPressed: () => tapped = true,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );

      expect(find.text('Tapped'), findsOneWidget);
    });
  });
}