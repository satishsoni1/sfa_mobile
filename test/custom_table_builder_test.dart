import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:zforce/presentation/chat/chat_screen.dart';

// TODO: Import your ChatScreen file here
// import 'package:your_app/screens/chat_screen.dart';

void main() {
  Widget buildTestableMarkdown(String markdownData) {
    return MaterialApp(
      home: Scaffold(
        body: MarkdownBody(
          data: markdownData,
          extensionSet: md.ExtensionSet.gitHubFlavored,
          builders: {'table': CustomTableBuilder()},
        ),
      ),
    );
  }

  group('CustomTableBuilder Edge Cases', () {
    testWidgets('1. Renders a perfectly formed table', (
      WidgetTester tester,
    ) async {
      // Using List.join prevents IDE auto-formatting from breaking the tables
      final String perfectTable = [
        '',
        '| Batch ID | Item | Purity | Status |',
        '|---|---|---|---|',
        '| B-001 | Gold Ring | 22K | Polishing |',
        '| B-002 | Silver Chain | 925 | Casting |',
        '',
      ].join('\n');

      await tester.pumpWidget(buildTestableMarkdown(perfectTable));
      await tester.pumpAndSettle();

      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Batch ID'), findsOneWidget);
      expect(find.text('Gold Ring'), findsOneWidget);
    });

    testWidgets('2. Handles rows with missing data cleanly', (
      WidgetTester tester,
    ) async {
      final String missingDataTable = [
        '',
        '| Batch ID | Item | Weight (g) | Status |',
        '|---|---|---|---|',
        '| B-003 | Diamond Pendant | 15.5 | Setting |',
        // Empty cells instead of missing pipes to pass the strict Markdown parser
        '| B-004 | Gold Bangle |   |   |',
        '',
      ].join('\n');

      await tester.pumpWidget(buildTestableMarkdown(missingDataTable));
      await tester.pumpAndSettle();

      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('B-004'), findsOneWidget);
      expect(find.text('Gold Bangle'), findsOneWidget);
    });

    testWidgets('3. Handles extreme long text wrapping within a cell', (
      WidgetTester tester,
    ) async {
      // Constructing the long string dynamically so the IDE doesn't add line breaks
      final String longCellText =
          'The wax mold was slightly deformed during the '
          'cooling process, resulting in minor porosity on the underside. '
          'Need to adjust temperature controls by -5 degrees for the next batch.';

      final String longTextTable = [
        '',
        '| Issue Log | Resolution Notes |',
        '|---|---|',
        '| Casting defect | $longCellText |',
        '',
      ].join('\n');

      await tester.pumpWidget(buildTestableMarkdown(longTextTable));
      await tester.pumpAndSettle();

      expect(find.byType(DataTable), findsOneWidget);
      // Verify our long string successfully rendered inside the table
      expect(find.textContaining('temperature controls'), findsOneWidget);
    });
  });
}
