import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zforce/features/pod/config/secondary_sales_upload_files.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_service.dart';
import 'package:zforce/features/pod/widgets/secondary_sales_upload_source_sheet.dart';

void main() {
  group('Secondary Sales upload source sheet', () {
    testWidgets(
        'shows Upload Files in Camera, Documents, Gallery, Scanner order',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecondarySalesUploadSourceSheet(
              onCamera: () {},
              onDocuments: () {},
              onGallery: () {},
              onScanner: () {},
            ),
          ),
        ),
      );

      expect(find.text('Upload Files'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Select files from device'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Select photos'), findsOneWidget);
      expect(find.text('Scanner'), findsOneWidget);
      expect(find.text('Scan a document'), findsOneWidget);
      expect(find.text('PDF Files'), findsNothing);
      expect(find.text('Add Documents'), findsNothing);

      final cameraY = tester.getTopLeft(find.text('Camera')).dy;
      final documentsY = tester.getTopLeft(find.text('Documents')).dy;
      final galleryY = tester.getTopLeft(find.text('Gallery')).dy;
      final scannerY = tester.getTopLeft(find.text('Scanner')).dy;
      expect(cameraY < documentsY, isTrue);
      expect(documentsY < galleryY, isTrue);
      expect(galleryY < scannerY, isTrue);
    });

    testWidgets('Documents option invokes the document picker callback',
        (tester) async {
      var documents = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => SecondarySalesUploadSourceSheet(
                      onCamera: () {},
                      onDocuments: () => documents++,
                      onGallery: () {},
                      onScanner: () {},
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();
      expect(documents, 1);
    });

    testWidgets('Camera, Gallery, and Scanner callbacks still work',
        (tester) async {
      var camera = 0;
      var gallery = 0;
      var scanner = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => SecondarySalesUploadSourceSheet(
                      onCamera: () => camera++,
                      onDocuments: () {},
                      onGallery: () => gallery++,
                      onScanner: () => scanner++,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();
      expect(camera, 1);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      expect(gallery, 1);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scanner'));
      await tester.pumpAndSettle();
      expect(scanner, 1);
    });
  });

  group('supported document extensions', () {
    test('accepts PDF, DOC, DOCX, TXT, JPG, JPEG, PNG, HTML, HTM', () {
      const files = [
        'statement.pdf',
        'notes.doc',
        'report.docx',
        'readme.txt',
        '1000173016.jpg',
        'scan.JPEG',
        'photo.png',
        'page.html',
        'index.htm',
      ];
      for (final name in files) {
        final ext = name.split('.').last;
        expect(
          isSecondarySalesDocumentExtension(ext),
          isTrue,
          reason: name,
        );
      }
      expect(kSecondarySalesDocumentPickerAllowsMultiple, isTrue);
      expect(
        kSecondarySalesDocumentExtensions,
        ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png', 'html', 'htm'],
      );
    });

    test('does not reject a JPG merely because the filename has no YYYY-MM', () {
      expect(isSecondarySalesDocumentExtension('jpg'), isTrue);
      expect(
        secondarySalesClientBlocksOnFilenameMonth('1000173016.jpg'),
        isFalse,
      );
      expect(
        secondarySalesClientBlocksOnFilenameMonth('35263133277806.jpg'),
        isFalse,
      );
    });
  });

  group('upload flow fields and Laravel month validation', () {
    test('selected files still send statement_month unchanged', () {
      final fields = buildSecondarySalesUploadFields(
        stockistId: 869,
        selectedMonth: DateTime(2026, 9),
      );
      expect(fields['statement_month'], '2026-09');
    });

    test('Laravel month-validation error is displayed unchanged', () {
      final message = secondarySalesUploadUnprocessableMessage(
        jsonEncode({
          'success': false,
          'message': 'You can upload statements of the selected month only.',
        }),
      );
      expect(message, 'You can upload statements of the selected month only.');
    });
  });
}
