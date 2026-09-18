import 'dart:async';
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
import 'package:zforce/features/pod/services/secondary_sales_stockist_list_controller.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_service.dart';
import 'package:zforce/features/pod/widgets/secondary_sales_stockist_picker.dart';

const _payload = {
  'success': true,
  'data': [
    {'id': 2134, 'name': 'KAMAL DRUG DISTRIBUTORS'},
    {'id': 2227, 'name': 'SUKHMANI TRADERS'},
  ],
  'current_page': 1,
  'last_page': 1,
  'per_page': 50,
  'total': 2,
};

List<Map<String, dynamic>> _namedStockists(
  int count, {
  int startId = 1,
  required String prefix,
}) {
  return [
    for (var i = 0; i < count; i++)
      {'id': startId + i, 'name': '$prefix ${startId + i}'},
  ];
}

Map<String, dynamic> _page({
  required int page,
  required int lastPage,
  required int total,
  required List<Map<String, dynamic>> data,
  int perPage = 50,
}) {
  return {
    'success': true,
    'data': data,
    'current_page': page,
    'last_page': lastPage,
    'next_page': page < lastPage ? page + 1 : null,
    'per_page': perPage,
    'total': total,
  };
}

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
      expect(usesServerSideStockistSearch(kUploadTypeSecondarySales), isTrue);
    });

    test('Invoice POD still uses GET /api/stockists', () {
      final url = stockistListUrlForUploadType(kUploadTypeInvoicePod);
      expect(url, API_STOCKISTS_URL);
      expect(url.endsWith('stockists'), isTrue);
      expect(url.contains('secondary-sales/stockists'), isFalse);
      expect(usesServerSideStockistSearch(kUploadTypeInvoicePod), isTrue);
    });
  });

  group('authorized stockist parsing and URI', () {
    test('parses production-style authorized list', () {
      final stockists = parseAuthorizedStockists(jsonEncode(_payload));
      expect(stockists, hasLength(2));
      expect(stockists.first.id, 2134);
      expect(stockists.first.name, 'KAMAL DRUG DISTRIBUTORS');
      expect(stockists.last.id, 2227);
      expect(stockists.last.name, 'SUKHMANI TRADERS');
    });

    test('page 1 URI always sends page=1 and per_page=50', () {
      final uri = authorizedStockistsUri();
      expect(uri.queryParameters['page'], '1');
      expect(uri.queryParameters['per_page'], '50');
      expect(uri.queryParameters.containsKey('search'), isFalse);
      expect(uri.queryParameters.containsKey('group_id'), isFalse);
      expect(uri.toString(), contains('secondary-sales/stockists'));
    });

    test('empty search is omitted and never becomes A', () {
      final uri = authorizedStockistsUri(page: 1, search: '   ');
      expect(uri.queryParameters['search'], isNull);
      expect(uri.queryParameters['search'], isNot('A'));
    });

    test('search term is sent only when non-empty', () {
      final uri = authorizedStockistsUri(page: 1, search: 'PHARMA');
      expect(uri.queryParameters['search'], 'PHARMA');
      expect(uri.queryParameters['page'], '1');
      expect(uri.queryParameters['per_page'], '50');
    });

    test('does not add stockists from cached or local extras', () {
      final stockists = parseAuthorizedStockists(jsonEncode(_payload));
      final cached = const SecondarySalesStockistInfo(
        id: 9999,
        name: 'UNAUTHORIZED CACHED STOCKIST',
      );
      expect(stockists.any((s) => s.id == cached.id), isFalse);
    });

    test('merge keeps existing records and skips duplicate IDs', () {
      final page1 = [
        const SecondarySalesStockistInfo(id: 1, name: 'A K PHARMA'),
        const SecondarySalesStockistInfo(id: 2, name: 'BANSAL MEDICAL'),
      ];
      final page2 = [
        const SecondarySalesStockistInfo(id: 2, name: 'BANSAL MEDICAL'),
        const SecondarySalesStockistInfo(id: 3, name: 'CHANDRA PHARMA'),
      ];
      final merged = mergeAuthorizedStockists(page1, page2);
      expect(merged.map((s) => s.id), [1, 2, 3]);
    });

    test('parses last_page from a pagination object', () {
      final parsed = parseAuthorizedStockistsPage(
        jsonEncode({
          'success': true,
          'data': _namedStockists(50, prefix: 'A'),
          'pagination': {
            'current_page': 1,
            'last_page': 76,
            'next_page': 2,
            'per_page': 50,
            'total': 3781,
          },
        }),
      );
      expect(parsed.stockists, hasLength(50));
      expect(parsed.currentPage, 1);
      expect(parsed.lastPage, 76);
      expect(parsed.nextPage, 2);
      expect(parsed.total, 3781);
      expect(parsed.hasMorePages, isTrue);
    });

    test('parses next page from Laravel next_page_url and total_pages', () {
      final parsed = parseAuthorizedStockistsPage(
        jsonEncode({
          'success': true,
          'data': _namedStockists(50, prefix: 'A'),
          'current_page': 1,
          'per_page': 50,
          'total': 120,
          'total_pages': 3,
          'next_page_url':
              'https://himalaya.globalspace.in/api/secondary-sales/stockists?page=2',
        }),
      );
      expect(parsed.lastPage, 3);
      expect(parsed.nextPage, 2);
      expect(parsed.hasMorePages, isTrue);
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
      expect(requested.single.path, contains('secondary-sales/stockists'));
      expect(requested.single.queryParameters['page'], '1');
      expect(requested.single.queryParameters['per_page'], '50');
      expect(
        requested.any((u) => u.path.endsWith('/stockists') &&
            !u.path.contains('secondary-sales')),
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
        requested.every((u) => u.path.contains('secondary-sales/stockists')),
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

  group('SecondarySalesStockistListController pagination', () {
    test('A. ADMIN page 1 + page 2 display 100 unique stockists', () async {
      final requested = <Uri>[];
      final service = SecondarySalesStockistService(
        getter: (uri) async {
          requested.add(uri);
          final page = int.parse(uri.queryParameters['page'] ?? '1');
          expect(uri.queryParameters['per_page'], '50');
          if (page == 1) {
            return http.Response(
              jsonEncode(_page(
                page: 1,
                lastPage: 2,
                total: 100,
                data: _namedStockists(50, prefix: 'A'),
              )),
              200,
            );
          }
          return http.Response(
            jsonEncode(_page(
              page: 2,
              lastPage: 2,
              total: 100,
              data: _namedStockists(50, startId: 51, prefix: 'B'),
            )),
            200,
          );
        },
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      expect(controller.stockists, hasLength(50));
      await controller.loadMore();
      expect(controller.stockists, hasLength(100));
      expect(controller.stockists.map((s) => s.id).toSet(), hasLength(100));
      expect(controller.stockists.first.name, startsWith('A '));
      expect(controller.stockists.last.name, startsWith('B '));
    });

    test('B. ADMIN stops requesting after last_page', () async {
      final requested = <Uri>[];
      final service = SecondarySalesStockistService(
        getter: (uri) async {
          requested.add(uri);
          return http.Response(
            jsonEncode(_page(
              page: int.parse(uri.queryParameters['page'] ?? '1'),
              lastPage: 2,
              total: 100,
              data: _namedStockists(50, prefix: 'A'),
            )),
            200,
          );
        },
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      await controller.loadMore();
      await controller.loadMore();
      await controller.loadMore();
      expect(requested, hasLength(2));
      expect(requested.last.queryParameters['page'], '2');
      expect(controller.hasNextPage, isFalse);
    });

    test('C. non-admin with 44 stockists does not request page 2', () async {
      final requested = <Uri>[];
      final service = SecondarySalesStockistService(
        getter: (uri) async {
          requested.add(uri);
          return http.Response(
            jsonEncode(_page(
              page: 1,
              lastPage: 1,
              total: 44,
              data: _namedStockists(44, prefix: 'EMP'),
            )),
            200,
          );
        },
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      await controller.loadMore();
      expect(controller.stockists, hasLength(44));
      expect(requested, hasLength(1));
      expect(requested.single.queryParameters.containsKey('group_id'), isFalse);
    });

    test('D. non-admin with 120 stockists loads 50 + 50 + 20', () async {
      final requested = <Uri>[];
      final service = SecondarySalesStockistService(
        getter: (uri) async {
          requested.add(uri);
          final page = int.parse(uri.queryParameters['page'] ?? '1');
          if (page == 1) {
            return http.Response(
              jsonEncode(_page(
                page: 1,
                lastPage: 3,
                total: 120,
                data: _namedStockists(50, prefix: 'E1'),
              )),
              200,
            );
          }
          if (page == 2) {
            return http.Response(
              jsonEncode(_page(
                page: 2,
                lastPage: 3,
                total: 120,
                data: _namedStockists(50, startId: 51, prefix: 'E2'),
              )),
              200,
            );
          }
          return http.Response(
            jsonEncode(_page(
              page: 3,
              lastPage: 3,
              total: 120,
              data: _namedStockists(20, startId: 101, prefix: 'E3'),
            )),
            200,
          );
        },
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      expect(controller.stockists, hasLength(50));
      await controller.loadMore();
      expect(controller.stockists, hasLength(100));
      await controller.loadMore();
      expect(controller.stockists, hasLength(120));
      expect(requested.map((u) => u.queryParameters['page']), ['1', '2', '3']);
    });

    test('E. Flutter displays only API results and never adds extras', () async {
      final service = SecondarySalesStockistService(
        getter: (_) async => http.Response(
          jsonEncode(_page(
            page: 1,
            lastPage: 1,
            total: 1,
            data: [
              {'id': 2227, 'name': 'SUKHMANI TRADERS'},
            ],
          )),
          200,
        ),
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      expect(controller.stockists, hasLength(1));
      expect(controller.stockists.single.id, 2227);
      expect(controller.stockists.any((s) => s.id == 2418), isFalse);
    });

    test('F. search resets pagination to page 1 and does not mix lists', () async {
      final requested = <Uri>[];
      final service = SecondarySalesStockistService(
        getter: (uri) async {
          requested.add(uri);
          final search = uri.queryParameters['search'] ?? '';
          final page = uri.queryParameters['page'];
          if (search == 'PHARMA') {
            return http.Response(
              jsonEncode(_page(
                page: 1,
                lastPage: 1,
                total: 1,
                data: [
                  {'id': 9, 'name': 'CHANDRA PHARMA'},
                ],
              )),
              200,
            );
          }
          return http.Response(
            jsonEncode(_page(
              page: int.parse(page ?? '1'),
              lastPage: 2,
              total: 100,
              data: _namedStockists(50, prefix: 'A'),
            )),
            200,
          );
        },
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      await controller.loadMore();
      expect(controller.currentPage, 2);
      await controller.applySearch('PHARMA');
      expect(controller.currentSearch, 'PHARMA');
      expect(controller.currentPage, 1);
      expect(controller.stockists, hasLength(1));
      expect(controller.stockists.single.name, 'CHANDRA PHARMA');
      expect(requested.last.queryParameters['search'], 'PHARMA');
      expect(requested.last.queryParameters['page'], '1');
    });

    test('G. stale search response cannot overwrite a newer search', () async {
      final abc = Completer<http.Response>();
      final service = SecondarySalesStockistService(
        getter: (uri) async {
          final search = uri.queryParameters['search'] ?? '';
          if (search == 'ABC') return abc.future;
          return http.Response(
            jsonEncode(_page(
              page: 1,
              lastPage: 1,
              total: 1,
              data: [
                {'id': 2, 'name': 'XYZ TRADERS'},
              ],
            )),
            200,
          );
        },
      );
      final controller = SecondarySalesStockistListController(service: service);
      final first = controller.applySearch('ABC');
      await controller.applySearch('XYZ');
      abc.complete(http.Response(
        jsonEncode(_page(
          page: 1,
          lastPage: 1,
          total: 1,
          data: [
            {'id': 1, 'name': 'ABC AGENCY'},
          ],
        )),
        200,
      ));
      await first;
      expect(controller.stockists, hasLength(1));
      expect(controller.stockists.single.name, 'XYZ TRADERS');
      expect(controller.currentSearch, 'XYZ');
    });

    test('H. duplicate stockist IDs from later pages are not shown twice', () async {
      final service = SecondarySalesStockistService(
        getter: (uri) async {
          final page = int.parse(uri.queryParameters['page'] ?? '1');
          if (page == 1) {
            return http.Response(
              jsonEncode(_page(
                page: 1,
                lastPage: 2,
                total: 3,
                data: [
                  {'id': 869, 'name': 'A K PHARMA'},
                  {'id': 1, 'name': 'A B C AGENCIES'},
                ],
              )),
              200,
            );
          }
          return http.Response(
            jsonEncode(_page(
              page: 2,
              lastPage: 2,
              total: 3,
              data: [
                {'id': 869, 'name': 'A K PHARMA'},
                {'id': 2, 'name': 'BANSAL MEDICAL'},
              ],
            )),
            200,
          );
        },
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      await controller.loadMore();
      expect(controller.stockists.where((s) => s.id == 869), hasLength(1));
      expect(controller.stockists.map((s) => s.id).toSet(), hasLength(3));
    });

    test('I. refresh resets pagination to page 1', () async {
      var page1Calls = 0;
      final service = SecondarySalesStockistService(
        getter: (uri) async {
          final page = int.parse(uri.queryParameters['page'] ?? '1');
          if (page == 1) page1Calls++;
          return http.Response(
            jsonEncode(_page(
              page: page,
              lastPage: 2,
              total: 100,
              data: _namedStockists(50, startId: page == 1 ? 1 : 51, prefix: 'R'),
            )),
            200,
          );
        },
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      await controller.loadMore();
      expect(controller.currentPage, 2);
      controller.reset();
      expect(controller.stockists, isEmpty);
      expect(controller.currentPage, 0);
      await controller.refresh();
      expect(controller.currentPage, 1);
      expect(controller.stockists, hasLength(50));
      expect(page1Calls, 2);
    });

    test('J. page 2 loading does not clear page 1', () async {
      final page2 = Completer<http.Response>();
      final service = SecondarySalesStockistService(
        getter: (uri) async {
          final page = int.parse(uri.queryParameters['page'] ?? '1');
          if (page == 1) {
            return http.Response(
              jsonEncode(_page(
                page: 1,
                lastPage: 2,
                total: 100,
                data: _namedStockists(50, prefix: 'A'),
              )),
              200,
            );
          }
          return page2.future;
        },
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      final more = controller.loadMore();
      expect(controller.isLoadingMore, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.stockists, hasLength(50));
      page2.complete(http.Response(
        jsonEncode(_page(
          page: 2,
          lastPage: 2,
          total: 100,
          data: _namedStockists(50, startId: 51, prefix: 'B'),
        )),
        200,
      ));
      await more;
      expect(controller.stockists, hasLength(100));
    });

    test('page 2 error keeps page 1 records', () async {
      final service = SecondarySalesStockistService(
        getter: (uri) async {
          final page = int.parse(uri.queryParameters['page'] ?? '1');
          if (page == 1) {
            return http.Response(
              jsonEncode(_page(
                page: 1,
                lastPage: 2,
                total: 100,
                data: _namedStockists(50, prefix: 'A'),
              )),
              200,
            );
          }
          return http.Response('server error', 500);
        },
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      await controller.loadMore();
      expect(controller.stockists, hasLength(50));
      expect(controller.currentPage, 1);
      expect(controller.loadMoreError, isNotNull);
      expect(controller.stockists.first.name, startsWith('A '));
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
    Future<void> pumpPicker(
      WidgetTester tester, {
      required SecondarySalesStockistListController controller,
      SecondarySalesStockistInfo? selected,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecondarySalesStockistPicker(
              controller: controller,
              selected: selected,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('displays authorized stockists', (tester) async {
      final service = SecondarySalesStockistService(
        getter: (_) async => http.Response(jsonEncode(_payload), 200),
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      await pumpPicker(tester, controller: controller);
      expect(find.text('KAMAL DRUG DISTRIBUTORS'), findsOneWidget);
      expect(find.text('ID: 2134'), findsOneWidget);
      expect(find.text('SUKHMANI TRADERS'), findsOneWidget);
      expect(find.text('ID: 2227'), findsOneWidget);
    });

    testWidgets('search by name uses the stockists API', (tester) async {
      final requested = <Uri>[];
      final service = SecondarySalesStockistService(
        getter: (uri) async {
          requested.add(uri);
          final search = uri.queryParameters['search'] ?? '';
          if (search.toLowerCase() == 'sukhmani') {
            return http.Response(
              jsonEncode(_page(
                page: 1,
                lastPage: 1,
                total: 1,
                data: [
                  {'id': 2227, 'name': 'SUKHMANI TRADERS'},
                ],
              )),
              200,
            );
          }
          return http.Response(jsonEncode(_payload), 200);
        },
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      await pumpPicker(tester, controller: controller);
      await tester.enterText(find.byType(TextField), 'sukhmani');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      expect(find.text('SUKHMANI TRADERS'), findsOneWidget);
      expect(find.text('KAMAL DRUG DISTRIBUTORS'), findsNothing);
      expect(requested.last.queryParameters['search'], 'sukhmani');
      expect(requested.last.queryParameters['page'], '1');
    });

    testWidgets('search by ID uses the stockists API', (tester) async {
      final requested = <Uri>[];
      final service = SecondarySalesStockistService(
        getter: (uri) async {
          requested.add(uri);
          if (uri.queryParameters['search'] == '2227') {
            return http.Response(
              jsonEncode(_page(
                page: 1,
                lastPage: 1,
                total: 1,
                data: [
                  {'id': 2227, 'name': 'SUKHMANI TRADERS'},
                ],
              )),
              200,
            );
          }
          return http.Response(jsonEncode(_payload), 200);
        },
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      await pumpPicker(tester, controller: controller);
      await tester.enterText(find.byType(TextField), '2227');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      expect(find.text('SUKHMANI TRADERS'), findsOneWidget);
      expect(requested.last.queryParameters['search'], '2227');
    });

    testWidgets('empty response shows empty state', (tester) async {
      final service = SecondarySalesStockistService(
        getter: (_) async => http.Response(
          jsonEncode(_page(page: 1, lastPage: 1, total: 0, data: [])),
          200,
        ),
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      await pumpPicker(tester, controller: controller);
      expect(find.text(kSecondarySalesStockistEmptyMessage), findsOneWidget);
    });

    testWidgets('403 displays unauthorized message', (tester) async {
      final service = SecondarySalesStockistService(
        getter: (_) async => http.Response(
          jsonEncode({'success': false, 'message': 'Forbidden'}),
          403,
        ),
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      await pumpPicker(tester, controller: controller);
      expect(find.text(kSecondarySalesStockistUnauthorizedMessage), findsOneWidget);
    });

    testWidgets('500/network error displays error state', (tester) async {
      final service = SecondarySalesStockistService(
        getter: (_) async => http.Response('server error', 500),
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      await pumpPicker(tester, controller: controller);
      expect(
        find.text('Unable to load stockists. Please try again later.'),
        findsOneWidget,
      );
    });

    testWidgets('renders B/C/D stockists returned by the API', (tester) async {
      final service = SecondarySalesStockistService(
        getter: (_) async => http.Response(
          jsonEncode(_page(
            page: 1,
            lastPage: 1,
            total: 4,
            data: [
              {'id': 869, 'name': 'A K PHARMA'},
              {'id': 3001, 'name': 'BANSAL MEDICAL AGENCY'},
              {'id': 3002, 'name': 'CHANDRA PHARMA'},
              {'id': 3003, 'name': 'DELHI DRUG HOUSE'},
            ],
          )),
          200,
        ),
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      await pumpPicker(tester, controller: controller);
      expect(find.text('A K PHARMA'), findsOneWidget);
      expect(find.text('BANSAL MEDICAL AGENCY'), findsOneWidget);
      expect(find.text('CHANDRA PHARMA'), findsOneWidget);
      expect(find.text('DELHI DRUG HOUSE'), findsOneWidget);
    });

    testWidgets('empty search box does not filter to A only', (tester) async {
      final service = SecondarySalesStockistService(
        getter: (_) async => http.Response(
          jsonEncode(_page(
            page: 1,
            lastPage: 1,
            total: 2,
            data: [
              {'id': 869, 'name': 'A K PHARMA'},
              {'id': 3001, 'name': 'BANSAL MEDICAL AGENCY'},
            ],
          )),
          200,
        ),
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      await pumpPicker(tester, controller: controller);
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '');
      expect(find.text('A K PHARMA'), findsOneWidget);
      expect(find.text('BANSAL MEDICAL AGENCY'), findsOneWidget);
    });

    testWidgets('keeps selected stockist while another page loads', (tester) async {
      final selected = const SecondarySalesStockistInfo(
        id: 869,
        name: 'A K PHARMA',
      );
      final page2 = Completer<http.Response>();
      final service = SecondarySalesStockistService(
        getter: (uri) async {
          final page = int.parse(uri.queryParameters['page'] ?? '1');
          if (page == 1) {
            return http.Response(
              jsonEncode(_page(
                page: 1,
                lastPage: 2,
                total: 3,
                data: [
                  {'id': 869, 'name': 'A K PHARMA'},
                  {'id': 1, 'name': 'A B C AGENCIES'},
                ],
              )),
              200,
            );
          }
          return page2.future;
        },
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      await pumpPicker(tester, controller: controller, selected: selected);
      final more = controller.loadMore();
      await tester.pump();
      expect(find.text('A K PHARMA'), findsWidgets);
      page2.complete(http.Response(
        jsonEncode(_page(
          page: 2,
          lastPage: 2,
          total: 3,
          data: [
            {'id': 2, 'name': 'BANSAL MEDICAL'},
          ],
        )),
        200,
      ));
      await more;
      await tester.pump();
      expect(find.text('A K PHARMA'), findsWidgets);
    });

    testWidgets('search field keeps focus while typing A, AB, ABC', (tester) async {
      final searchStarted = Completer<void>();
      final searchDone = Completer<http.Response>();
      final service = SecondarySalesStockistService(
        getter: (uri) async {
          final search = uri.queryParameters['search'] ?? '';
          if (search == 'ABC') {
            searchStarted.complete();
            return searchDone.future;
          }
          return http.Response(jsonEncode(_payload), 200);
        },
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      await pumpPicker(tester, controller: controller);

      final field = find.byKey(const ValueKey('ss-stockist-search-field'));
      await tester.tap(field);
      await tester.pump();

      Future<void> typeAndAssertFocus(String value) async {
        await tester.enterText(field, value);
        await tester.pump();
        final textField = tester.widget<TextField>(field);
        expect(textField.enabled, isTrue);
        expect(textField.focusNode!.hasFocus, isTrue);
        expect(textField.controller!.text, value);
      }

      await typeAndAssertFocus('A');
      await typeAndAssertFocus('AB');
      await typeAndAssertFocus('ABC');
      await tester.pump(const Duration(milliseconds: 450));
      await searchStarted.future;
      var textField = tester.widget<TextField>(field);
      expect(textField.enabled, isTrue);
      expect(textField.focusNode!.hasFocus, isTrue);
      expect(controller.isLoading, isTrue);

      searchDone.complete(http.Response(
        jsonEncode(_page(
          page: 1,
          lastPage: 1,
          total: 1,
          data: [
            {'id': 3, 'name': 'ABC AGENCY'},
          ],
        )),
        200,
      ));
      await tester.pump();
      await tester.pump();
      textField = tester.widget<TextField>(field);
      expect(textField.enabled, isTrue);
      expect(textField.focusNode!.hasFocus, isTrue);
      expect(textField.controller!.text, 'ABC');
      expect(find.text('ABC AGENCY'), findsOneWidget);
    });

    testWidgets('scrolling the stockist list appends page 2', (tester) async {
      final requested = <Uri>[];
      final service = SecondarySalesStockistService(
        getter: (uri) async {
          requested.add(uri);
          final page = int.parse(uri.queryParameters['page'] ?? '1');
          if (page == 1) {
            return http.Response(
              jsonEncode(_page(
                page: 1,
                lastPage: 2,
                total: 100,
                data: _namedStockists(50, prefix: 'A'),
              )),
              200,
            );
          }
          return http.Response(
            jsonEncode(_page(
              page: 2,
              lastPage: 2,
              total: 100,
              data: _namedStockists(50, startId: 51, prefix: 'B'),
            )),
            200,
          );
        },
      );
      final controller = SecondarySalesStockistListController(service: service);
      await controller.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RefreshIndicator(
              onRefresh: () async {},
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {},
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SecondarySalesStockistPicker(controller: controller),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(controller.stockists, hasLength(50));
      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(requested.map((u) => u.queryParameters['page']), contains('2'));
      expect(controller.stockists, hasLength(100));
      expect(controller.stockists.first.name, startsWith('A '));
      expect(controller.stockists.last.name, startsWith('B '));
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
      expect(requested.single.path, contains('secondary-sales/stockists'));
      expect(requested.single.queryParameters['page'], '1');
      expect(requested.single.queryParameters['per_page'], '50');
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
