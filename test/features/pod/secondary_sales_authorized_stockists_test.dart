import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/screens/pod_upload_screen.dart';
import 'package:zforce/features/pod/services/api_client.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_service.dart';
import 'package:zforce/features/pod/widgets/secondary_sales_stockist_picker.dart';

const _payload = {
  'success': true,
  'data': [
    {'id': 2134, 'name': 'KAMAL DRUG DISTRIBUTORS'},
    {'id': 2227, 'name': 'SUKHMANI TRADERS'},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'authToken': 'token-user-a'});
  });

  group('stockist source by upload type', () {
    test('Himalaya uses GET /api/secondary-sales/stockists only', () {
      final url = stockistListUrlForUploadType(kUploadTypeSecondarySales);
      expect(url, API_SECONDARY_SALES_STOCKISTS_URL);
      expect(url, contains('secondary-sales/stockists'));
      expect(url, isNot(API_STOCKISTS_URL));
      expect(usesServerSideStockistSearch(kUploadTypeSecondarySales), isFalse);
    });

    test('Invoice POD still uses GET /api/stockists', () {
      final url = stockistListUrlForUploadType(kUploadTypeInvoicePod);
      expect(url, API_STOCKISTS_URL);
      expect(url.endsWith('stockists'), isTrue);
      expect(url.contains('secondary-sales/stockists'), isFalse);
      expect(usesServerSideStockistSearch(kUploadTypeInvoicePod), isTrue);
    });
  });

  group('authorized stockist parsing and search', () {
    test('parses production-style authorized list', () {
      final stockists = parseAuthorizedStockists(jsonEncode(_payload));
      expect(stockists, hasLength(2));
      expect(stockists.first.id, 2134);
      expect(stockists.first.name, 'KAMAL DRUG DISTRIBUTORS');
      expect(stockists.last.id, 2227);
      expect(stockists.last.name, 'SUKHMANI TRADERS');
    });

    test('search by stockist name is client-side', () {
      final stockists = parseAuthorizedStockists(jsonEncode(_payload));
      final results = filterAuthorizedStockists(stockists, 'sukhmani');
      expect(results, hasLength(1));
      expect(results.single.id, 2227);
    });

    test('search by stockist ID is client-side', () {
      final stockists = parseAuthorizedStockists(jsonEncode(_payload));
      final results = filterAuthorizedStockists(stockists, '2227');
      expect(results, hasLength(1));
      expect(results.single.name, 'SUKHMANI TRADERS');
    });

    test('does not add stockists from cached or local extras', () {
      final stockists = parseAuthorizedStockists(jsonEncode(_payload));
      final cached = const SecondarySalesStockistInfo(
        id: 9999,
        name: 'UNAUTHORIZED CACHED STOCKIST',
      );
      final filtered = filterAuthorizedStockists(stockists, 'unauthorized');
      expect(filtered, isEmpty);
      expect(stockists.any((s) => s.id == cached.id), isFalse);
    });
  });

  group('SecondarySalesStockistService', () {
    test('200 returns authorized stockists from the new API only', () async {
      final requested = <Uri>[];
      final service = SecondarySalesStockistService(
        getter: (uri) async {
          requested.add(uri);
          return http.Response(jsonEncode(_payload), 200);
        },
      );

      final stockists = await service.fetchAuthorizedStockists(
        authToken: 'token-user-a',
      );

      expect(requested, hasLength(1));
      expect(requested.single.toString(), API_SECONDARY_SALES_STOCKISTS_URL);
      expect(
        requested.any((u) => u.toString() == API_STOCKISTS_URL),
        isFalse,
      );
      expect(stockists.map((s) => s.id), [2134, 2227]);
      expect(service.loadedForToken, 'token-user-a');
    });

    test('empty data does not invent stockists', () async {
      final service = SecondarySalesStockistService(
        getter: (_) async => http.Response(
          jsonEncode({'success': true, 'data': []}),
          200,
        ),
      );
      final stockists = await service.fetchAuthorizedStockists();
      expect(stockists, isEmpty);
    });

    test('401 uses existing UnauthorizedException handling', () async {
      final service = SecondarySalesStockistService(
        getter: (_) async => throw UnauthorizedException(
          'Session expired. Please login again.',
        ),
      );
      expect(
        () => service.fetchAuthorizedStockists(),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('403 shows unauthorized stockist message', () async {
      final service = SecondarySalesStockistService(
        getter: (_) async => http.Response(
          jsonEncode({'success': false, 'message': 'Forbidden'}),
          403,
        ),
      );
      expect(
        () => service.fetchAuthorizedStockists(),
        throwsA(
          isA<SecondarySalesStockistException>().having(
            (e) => e.message,
            'message',
            kSecondarySalesStockistUnauthorizedMessage,
          ),
        ),
      );
    });

    test('404 shows stockist data unavailable', () async {
      final service = SecondarySalesStockistService(
        getter: (_) async => http.Response('not found', 404),
      );
      expect(
        () => service.fetchAuthorizedStockists(),
        throwsA(
          isA<SecondarySalesStockistException>().having(
            (e) => e.message,
            'message',
            kSecondarySalesStockistNotFoundMessage,
          ),
        ),
      );
    });

    test('500 and network errors do not fall back to /api/stockists', () async {
      final requested = <Uri>[];
      final service500 = SecondarySalesStockistService(
        getter: (uri) async {
          requested.add(uri);
          return http.Response('server error', 500);
        },
      );
      await expectLater(
        service500.fetchAuthorizedStockists(),
        throwsA(isA<SecondarySalesStockistException>()),
      );

      final serviceNet = SecondarySalesStockistService(
        getter: (uri) async {
          requested.add(uri);
          throw const SocketException('Failed host lookup');
        },
      );
      await expectLater(
        serviceNet.fetchAuthorizedStockists(),
        throwsA(isA<SecondarySalesStockistException>()),
      );

      expect(
        requested.every(
          (u) => u.toString() == API_SECONDARY_SALES_STOCKISTS_URL,
        ),
        isTrue,
      );
      expect(
        requested.any((u) => u.toString() == API_STOCKISTS_URL),
        isFalse,
      );
    });

    test('user change clears previous authorized list identity', () async {
      var token = 'token-user-a';
      final service = SecondarySalesStockistService(
        getter: (_) async => http.Response(jsonEncode(_payload), 200),
      );
      await service.fetchAuthorizedStockists(authToken: token);
      expect(service.loadedForToken, 'token-user-a');
      service.clear();
      token = 'token-user-b';
      await service.fetchAuthorizedStockists(authToken: token);
      expect(service.loadedForToken, 'token-user-b');
    });
  });

  group('upload stockist_id and 403', () {
    test('selected stockist ID is sent as stockist_id', () {
      final fields = buildSecondarySalesUploadFields(
        stockistId: 2227,
        selectedMonth: DateTime(2026, 9, 14),
      );
      expect(fields['stockist_id'], '2227');
      expect(fields.containsKey('employee_id'), isFalse);
      expect(fields.containsKey('kam_id'), isFalse);
      expect(fields.containsKey('position_code'), isFalse);
    });

    test('HTTP 403 does not navigate to upload status', () {
      expect(secondarySalesShouldNavigateToStatus(403), isFalse);
      expect(secondarySalesShouldNavigateToStatus(200), isTrue);
    });

    test('HTTP 403 displays the server authorization message', () {
      final message = secondarySalesUploadForbiddenMessage(
        jsonEncode({
          'success': false,
          'message': kSecondarySalesUploadForbiddenMessage,
        }),
      );
      expect(message, kSecondarySalesUploadForbiddenMessage);
    });
  });

  group('SecondarySalesStockistPicker', () {
    testWidgets('displays authorized stockists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecondarySalesStockistPicker(
              stockists: parseAuthorizedStockists(jsonEncode(_payload)),
              loading: false,
            ),
          ),
        ),
      );
      expect(find.text('KAMAL DRUG DISTRIBUTORS'), findsOneWidget);
      expect(find.text('ID: 2134'), findsOneWidget);
      expect(find.text('SUKHMANI TRADERS'), findsOneWidget);
      expect(find.text('ID: 2227'), findsOneWidget);
    });

    testWidgets('search by name filters authorized stockists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecondarySalesStockistPicker(
              stockists: parseAuthorizedStockists(jsonEncode(_payload)),
              loading: false,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'sukhmani');
      await tester.pump();
      expect(find.text('SUKHMANI TRADERS'), findsOneWidget);
      expect(find.text('KAMAL DRUG DISTRIBUTORS'), findsNothing);
    });

    testWidgets('search by ID filters authorized stockists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecondarySalesStockistPicker(
              stockists: parseAuthorizedStockists(jsonEncode(_payload)),
              loading: false,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '2227');
      await tester.pump();
      expect(find.text('SUKHMANI TRADERS'), findsOneWidget);
      expect(find.text('KAMAL DRUG DISTRIBUTORS'), findsNothing);
    });

    testWidgets('empty response shows empty state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SecondarySalesStockistPicker(
              stockists: [],
              loading: false,
            ),
          ),
        ),
      );
      expect(find.text(kSecondarySalesStockistEmptyMessage), findsOneWidget);
    });

    testWidgets('403 displays unauthorized message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SecondarySalesStockistPicker(
              stockists: [],
              loading: false,
              errorMessage: kSecondarySalesStockistUnauthorizedMessage,
            ),
          ),
        ),
      );
      expect(find.text(kSecondarySalesStockistUnauthorizedMessage), findsOneWidget);
    });

    testWidgets('500/network error displays error state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SecondarySalesStockistPicker(
              stockists: [],
              loading: false,
              errorMessage:
                  'Unable to load stockists. Please try again later.',
            ),
          ),
        ),
      );
      expect(
        find.text('Unable to load stockists. Please try again later.'),
        findsOneWidget,
      );
    });
  });

  group('PODUploadScreen Himalaya stockist source', () {
    testWidgets('loads authorized API and never calls /api/stockists',
        (tester) async {
      final requested = <Uri>[];
      final service = SecondarySalesStockistService(
        getter: (uri) async {
          requested.add(uri);
          return http.Response(jsonEncode(_payload), 200);
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PODUploadScreen(stockistService: service),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('KAMAL DRUG DISTRIBUTORS'), findsOneWidget);
      expect(find.text('SUKHMANI TRADERS'), findsOneWidget);
      expect(requested, hasLength(1));
      expect(requested.single.toString(), API_SECONDARY_SALES_STOCKISTS_URL);
      expect(
        requested.any((u) => u.toString() == API_STOCKISTS_URL),
        isFalse,
      );
    });

    testWidgets('403 stockist API shows unauthorized message', (tester) async {
      final service = SecondarySalesStockistService(
        getter: (_) async => http.Response(
          jsonEncode({'success': false, 'message': 'Forbidden'}),
          403,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PODUploadScreen(stockistService: service),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(kSecondarySalesStockistUnauthorizedMessage), findsOneWidget);
      expect(find.text('KAMAL DRUG DISTRIBUTORS'), findsNothing);
    });

    testWidgets('401 uses existing UnauthorizedException path', (tester) async {
      final service = SecondarySalesStockistService(
        getter: (_) async => throw UnauthorizedException(
          'Session expired. Please login again.',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PODUploadScreen(stockistService: service),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('KAMAL DRUG DISTRIBUTORS'), findsNothing);
      expect(find.text('UNAUTHORIZED CACHED STOCKIST'), findsNothing);
    });
  });
}
