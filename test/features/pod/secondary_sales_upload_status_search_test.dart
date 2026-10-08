import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:zforce/features/pod/bloc/secondary_sales_upload_status_cubit.dart';
import 'package:zforce/features/pod/models/secondary_sales_upload_status_models.dart';
import 'package:zforce/features/pod/screens/secondary_sales_upload_status_report_screen.dart';
import 'package:zforce/features/pod/services/secondary_sales_upload_status_service.dart';

Map<String, dynamic> _reportJson({
  String level = 'team',
  String? search,
  List<Map<String, dynamic>> rows = const [],
  Map<String, dynamic>? summary,
  int page = 1,
  int lastPage = 1,
  int total = 0,
}) {
  return {
    'success': true,
    'data': {
      'level': level,
      'filters': {
        'month': '2026-10',
        'level': level,
        if (search != null) 'search': search,
      },
      'summary': summary ??
          {
            'total_customer': rows.isEmpty ? 0 : 4,
            'data_uploaded': rows.isEmpty ? 0 : 2,
            'data_not_uploaded': rows.isEmpty ? 0 : 2,
            'data_uploaded_percentage': rows.isEmpty ? 0.0 : 50.0,
            'data_not_uploaded_percentage': rows.isEmpty ? 0.0 : 50.0,
          },
      'rows': rows,
      'pagination': {
        'page': page,
        'per_page': 50,
        'total': total,
        'last_page': lastPage,
      },
    },
  };
}

http.Response _ok(Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), 200);

void main() {
  group('Upload Status search query builder', () {
    test('includes search when non-empty', () {
      final qp = buildSecondarySalesUploadStatusQuery(
        month: '2026-10',
        level: 'team',
        search: 'MIDNAPORE',
        zmId: 123,
      );
      expect(qp['search'], 'MIDNAPORE');
      expect(qp['level'], 'team');
      expect(qp['zm_id'], '123');
      expect(qp['month'], '2026-10');
    });

    test('omits empty or whitespace search', () {
      final empty = buildSecondarySalesUploadStatusQuery(
        month: '2026-10',
        level: 'team',
        search: '   ',
      );
      expect(empty.containsKey('search'), isFalse);

      final nullSearch = buildSecondarySalesUploadStatusQuery(
        month: '2026-10',
        level: 'team',
      );
      expect(nullSearch.containsKey('search'), isFalse);
    });

    test('customer level stays customer not stockist', () {
      final qp = buildSecondarySalesUploadStatusQuery(
        month: '2026-10',
        level: 'customer',
        search: 'ABC',
      );
      expect(qp['level'], 'customer');
      expect(qp['search'], 'ABC');
    });

    test('placeholders match report levels', () {
      expect(secondarySalesUploadStatusSearchHint('zm'), 'Search ZM');
      expect(secondarySalesUploadStatusSearchHint('sm'), 'Search SM');
      expect(secondarySalesUploadStatusSearchHint('nsm'), 'Search NSM');
      expect(secondarySalesUploadStatusSearchHint('state'), 'Search State');
      expect(secondarySalesUploadStatusSearchHint('team'), 'Search Team');
      expect(secondarySalesUploadStatusSearchHint('employee'), 'Search Employee');
      expect(
        secondarySalesUploadStatusSearchHint('customer'),
        'Search Stockist',
      );
    });
  });

  group('Upload Status search service', () {
    test('sends search query param', () async {
      Uri? seen;
      final service = SecondarySalesUploadStatusService(
        getter: (uri) async {
          seen = uri;
          return _ok(_reportJson(search: 'RAJIV'));
        },
      );
      await service.fetchReport(
        month: '2026-10',
        level: 'employee',
        search: 'RAJIV',
      );
      expect(seen!.queryParameters['search'], 'RAJIV');
      expect(seen!.queryParameters['level'], 'employee');
    });

    test('does not send search when null', () async {
      Uri? seen;
      final service = SecondarySalesUploadStatusService(
        getter: (uri) async {
          seen = uri;
          return _ok(_reportJson());
        },
      );
      await service.fetchReport(month: '2026-10', level: 'team');
      expect(seen!.queryParameters.containsKey('search'), isFalse);
    });
  });

  group('Upload Status search cubit', () {
    late List<Uri> reportUris;
    late SecondarySalesUploadStatusService service;

    setUp(() {
      reportUris = [];
      service = SecondarySalesUploadStatusService(
        getter: (uri) async {
          if (uri.path.contains('/filters/')) {
            return _ok({
              'data': [
                {'id': 1, 'name': 'ZANDRA', 'code': 'ZANDRA'},
              ],
            });
          }
          reportUris.add(uri);
          final search = uri.queryParameters['search'];
          final page = int.tryParse(uri.queryParameters['page'] ?? '1') ?? 1;
          return _ok(
            _reportJson(
              level: uri.queryParameters['level'] ?? 'team',
              search: search,
              page: page,
              lastPage: search == null ? 2 : 1,
              total: search == null ? 60 : 1,
              rows: [
                {
                  'id': 10,
                  'name': search ?? 'Team Alpha',
                  'level': uri.queryParameters['level'] ?? 'team',
                  'total_customer': 4,
                  'data_uploaded': 2,
                  'data_not_uploaded': 2,
                  'data_uploaded_percentage': 50.0,
                  'data_not_uploaded_percentage': 50.0,
                },
              ],
              summary: {
                'total_customer': 4,
                'data_uploaded': 2,
                'data_not_uploaded': 2,
                'data_uploaded_percentage': 50.0,
                'data_not_uploaded_percentage': 50.0,
              },
            ),
          );
        },
      );
    });

    test('debounces search before API call', () async {
      final cubit = SecondarySalesUploadStatusCubit(
        service: service,
        initialMonth: DateTime(2026, 10),
        searchDebounce: const Duration(milliseconds: 450),
      );
      await cubit.initialize();
      reportUris.clear();

      cubit.onSearchChanged('M');
      cubit.onSearchChanged('MI');
      cubit.onSearchChanged('MIDNAPORE');
      expect(reportUris, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 500));
      await Future<void>.delayed(Duration.zero);
      expect(reportUris, hasLength(1));
      expect(reportUris.single.queryParameters['search'], 'MIDNAPORE');
      expect(reportUris.single.queryParameters['page'], '1');
      await cubit.close();
    });

    test('applySearch resets page to 1 and stores query', () async {
      final cubit = SecondarySalesUploadStatusCubit(
        service: service,
        initialMonth: DateTime(2026, 10),
        searchDebounce: Duration.zero,
      );
      await cubit.initialize();
      await cubit.loadMore();
      reportUris.clear();

      await cubit.applySearch('DELHI');
      expect(cubit.state.searchQuery, 'DELHI');
      expect(reportUris.single.queryParameters['page'], '1');
      expect(reportUris.single.queryParameters['search'], 'DELHI');
      expect(cubit.state.report!.summary.totalCustomer, 4);
      await cubit.close();
    });

    test('level change clears search', () async {
      final cubit = SecondarySalesUploadStatusCubit(
        service: service,
        initialMonth: DateTime(2026, 10),
        searchDebounce: Duration.zero,
      );
      await cubit.initialize();
      await cubit.applySearch('MIDNAPORE');
      reportUris.clear();

      await cubit.selectLevel('employee');
      expect(cubit.state.searchQuery, isEmpty);
      expect(cubit.state.level, 'employee');
      expect(reportUris.single.queryParameters.containsKey('search'), isFalse);
      expect(reportUris.single.queryParameters['level'], 'employee');
      await cubit.close();
    });

    test('month change clears search', () async {
      final cubit = SecondarySalesUploadStatusCubit(
        service: service,
        initialMonth: DateTime(2026, 10),
        searchDebounce: Duration.zero,
      );
      await cubit.initialize();
      await cubit.applySearch('ABC');
      reportUris.clear();

      await cubit.selectMonth(DateTime(2026, 11));
      expect(cubit.state.searchQuery, isEmpty);
      expect(cubit.state.monthYyyyMm, '2026-11');
      final reportCalls =
          reportUris.where((u) => !u.path.contains('/filters/')).toList();
      expect(
        reportCalls.last.queryParameters.containsKey('search'),
        isFalse,
      );
      await cubit.close();
    });

    test('hierarchy filter change clears search', () async {
      final cubit = SecondarySalesUploadStatusCubit(
        service: service,
        initialMonth: DateTime(2026, 10),
        searchDebounce: Duration.zero,
      );
      await cubit.initialize();
      await cubit.applySearch('DELHI');
      reportUris.clear();

      await cubit.selectZm(
        const SecondarySalesUploadStatusFilterOption(id: 123, label: 'ZM A'),
      );
      expect(cubit.state.searchQuery, isEmpty);
      final last = reportUris.last;
      expect(last.queryParameters.containsKey('search'), isFalse);
      expect(last.queryParameters['zm_id'], '123');
      await cubit.close();
    });

    test('pagination preserves active search', () async {
      final calls = <Uri>[];
      final svc = SecondarySalesUploadStatusService(
        getter: (uri) async {
          if (uri.path.contains('/filters/')) {
            return _ok({'data': []});
          }
          calls.add(uri);
          final page = int.tryParse(uri.queryParameters['page'] ?? '1') ?? 1;
          return _ok(
            _reportJson(
              search: uri.queryParameters['search'],
              page: page,
              lastPage: 2,
              total: 80,
              rows: [
                {
                  'id': page,
                  'name': 'Page $page',
                  'level': 'team',
                  'total_customer': 1,
                  'data_uploaded': 1,
                  'data_not_uploaded': 0,
                  'data_uploaded_percentage': 100,
                  'data_not_uploaded_percentage': 0,
                },
              ],
            ),
          );
        },
      );
      final cubit = SecondarySalesUploadStatusCubit(
        service: svc,
        initialMonth: DateTime(2026, 10),
        searchDebounce: Duration.zero,
      );
      await cubit.initialize();
      await cubit.applySearch('ABC');
      calls.clear();
      await cubit.loadMore();
      expect(calls.single.queryParameters['search'], 'ABC');
      expect(calls.single.queryParameters['page'], '2');
      await cubit.close();
    });

    test('loadMore keeps search when more pages exist', () async {
      final calls = <Uri>[];
      final svc = SecondarySalesUploadStatusService(
        getter: (uri) async {
          if (uri.path.contains('/filters/')) {
            return _ok({'data': []});
          }
          calls.add(uri);
          final page = int.tryParse(uri.queryParameters['page'] ?? '1') ?? 1;
          return _ok(
            _reportJson(
              search: uri.queryParameters['search'],
              page: page,
              lastPage: 3,
              total: 120,
              rows: [
                {
                  'id': page,
                  'name': 'Row $page',
                  'level': 'team',
                  'total_customer': 1,
                  'data_uploaded': 1,
                  'data_not_uploaded': 0,
                  'data_uploaded_percentage': 100,
                  'data_not_uploaded_percentage': 0,
                },
              ],
            ),
          );
        },
      );
      final cubit = SecondarySalesUploadStatusCubit(
        service: svc,
        initialMonth: DateTime(2026, 10),
        searchDebounce: Duration.zero,
      );
      await cubit.initialize();
      await cubit.applySearch('ABC');
      calls.clear();
      await cubit.loadMore();
      expect(calls.single.queryParameters['search'], 'ABC');
      expect(calls.single.queryParameters['page'], '2');
      expect(cubit.state.rows, hasLength(2));
      await cubit.close();
    });

    test('older search response cannot overwrite newer', () async {
      final completers = <Completer<http.Response>>[];
      final svc = SecondarySalesUploadStatusService(
        getter: (uri) async {
          if (uri.path.contains('/filters/')) {
            return _ok({'data': []});
          }
          final c = Completer<http.Response>();
          completers.add(c);
          return c.future;
        },
      );
      final cubit = SecondarySalesUploadStatusCubit(
        service: svc,
        initialMonth: DateTime(2026, 10),
        searchDebounce: Duration.zero,
      );
      // Kick first load (initialize).
      final initFuture = cubit.initialize();
      await Future<void>.delayed(Duration.zero);
      expect(completers, isNotEmpty);
      completers.first.complete(_ok(_reportJson(rows: [
        {
          'id': 1,
          'name': 'Initial',
          'level': 'team',
          'total_customer': 1,
          'data_uploaded': 1,
          'data_not_uploaded': 0,
          'data_uploaded_percentage': 100,
          'data_not_uploaded_percentage': 0,
        },
      ])));
      await initFuture;

      completers.clear();
      final first = cubit.applySearch('ABC');
      await Future<void>.delayed(Duration.zero);
      final second = cubit.applySearch('ABCD');
      await Future<void>.delayed(Duration.zero);
      expect(completers, hasLength(2));

      // Complete newer (ABCD) first.
      completers[1].complete(
        _ok(
          _reportJson(
            search: 'ABCD',
            rows: [
              {
                'id': 2,
                'name': 'ABCD Hit',
                'level': 'team',
                'total_customer': 1,
                'data_uploaded': 1,
                'data_not_uploaded': 0,
                'data_uploaded_percentage': 100,
                'data_not_uploaded_percentage': 0,
              },
            ],
          ),
        ),
      );
      await second;
      expect(cubit.state.rows.first.displayTitle, 'ABCD Hit');

      // Complete older (ABC) afterward — must not replace.
      completers[0].complete(
        _ok(
          _reportJson(
            search: 'ABC',
            rows: [
              {
                'id': 3,
                'name': 'ABC Stale',
                'level': 'team',
                'total_customer': 1,
                'data_uploaded': 0,
                'data_not_uploaded': 1,
                'data_uploaded_percentage': 0,
                'data_not_uploaded_percentage': 100,
              },
            ],
          ),
        ),
      );
      await first;
      expect(cubit.state.rows.first.displayTitle, 'ABCD Hit');
      expect(cubit.state.searchQuery, 'ABCD');
      await cubit.close();
    });

    test('API error shows error state not empty search message', () async {
      var fail = false;
      final svc = SecondarySalesUploadStatusService(
        getter: (uri) async {
          if (uri.path.contains('/filters/')) {
            return _ok({'data': []});
          }
          if (fail) return http.Response('boom', 500);
          return _ok(_reportJson());
        },
      );
      final cubit = SecondarySalesUploadStatusCubit(
        service: svc,
        initialMonth: DateTime(2026, 10),
        searchDebounce: Duration.zero,
      );
      await cubit.initialize();
      fail = true;
      await cubit.applySearch('X');
      expect(cubit.state.errorMessage, contains('Unable to load upload status'));
      expect(cubit.state.rows, isEmpty);
      await cubit.close();
    });

    test('dispose cancels debounce timer', () async {
      final cubit = SecondarySalesUploadStatusCubit(
        service: service,
        initialMonth: DateTime(2026, 10),
        searchDebounce: const Duration(seconds: 5),
      );
      await cubit.initialize();
      reportUris.clear();
      cubit.onSearchChanged('PENDING');
      await cubit.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(reportUris, isEmpty);
    });

    test('without search still loads report', () async {
      final cubit = SecondarySalesUploadStatusCubit(
        service: service,
        initialMonth: DateTime(2026, 10),
        searchDebounce: Duration.zero,
      );
      await cubit.initialize();
      expect(cubit.state.searchQuery, isEmpty);
      expect(cubit.state.report, isNotNull);
      expect(reportUris.first.queryParameters.containsKey('search'), isFalse);
      await cubit.close();
    });
  });

  group('Upload Status search UI', () {
    testWidgets('search field appears with level placeholder', (tester) async {
      final service = SecondarySalesUploadStatusService(
        getter: (uri) async {
          if (uri.path.contains('/filters/')) {
            return _ok({'data': []});
          }
          return _ok(_reportJson(rows: []));
        },
      );
      final cubit = SecondarySalesUploadStatusCubit(
        service: service,
        initialMonth: DateTime(2026, 10),
        searchDebounce: Duration.zero,
      );
      await cubit.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: SecondarySalesUploadStatusReportScreen(cubit: cubit),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Search Team'), findsOneWidget);

      await cubit.selectLevel('employee');
      await tester.pumpAndSettle();
      expect(find.text('Search Employee'), findsOneWidget);

      await cubit.selectLevel('customer');
      await tester.pumpAndSettle();
      expect(find.text('Search Stockist'), findsOneWidget);
      expect(cubit.state.level, 'customer');

      await cubit.close();
    });

    testWidgets('empty result shows No results found for query', (tester) async {
      final service = SecondarySalesUploadStatusService(
        getter: (uri) async {
          if (uri.path.contains('/filters/')) {
            return _ok({'data': []});
          }
          return _ok(
            _reportJson(
              search: uri.queryParameters['search'],
              rows: const [],
              summary: {
                'total_customer': 0,
                'data_uploaded': 0,
                'data_not_uploaded': 0,
                'data_uploaded_percentage': 0.0,
                'data_not_uploaded_percentage': 0.0,
              },
            ),
          );
        },
      );
      final cubit = SecondarySalesUploadStatusCubit(
        service: service,
        initialMonth: DateTime(2026, 10),
        searchDebounce: Duration.zero,
      );
      await cubit.initialize();
      await cubit.applySearch('MIDNAPORE');

      await tester.pumpWidget(
        MaterialApp(
          home: SecondarySalesUploadStatusReportScreen(cubit: cubit),
        ),
      );
      await tester.pumpAndSettle();

      final emptyFinder = find.textContaining(
        'No results found for "MIDNAPORE"',
        skipOffstage: false,
      );
      await tester.ensureVisible(emptyFinder);
      await tester.pumpAndSettle();
      expect(emptyFinder, findsOneWidget);
      expect(find.text('TOTAL CUSTOMER'), findsOneWidget);
      expect(find.text('0'), findsWidgets);

      await cubit.close();
    });

    testWidgets('API error banner is shown', (tester) async {
      var fail = false;
      final service = SecondarySalesUploadStatusService(
        getter: (uri) async {
          if (uri.path.contains('/filters/')) {
            return _ok({'data': []});
          }
          if (fail) return http.Response('{}', 500);
          return _ok(_reportJson());
        },
      );
      final cubit = SecondarySalesUploadStatusCubit(
        service: service,
        initialMonth: DateTime(2026, 10),
        searchDebounce: Duration.zero,
      );
      await cubit.initialize();
      fail = true;
      await cubit.applySearch('X');

      await tester.pumpWidget(
        MaterialApp(
          home: SecondarySalesUploadStatusReportScreen(cubit: cubit),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Unable to load upload status'), findsOneWidget);
      expect(find.textContaining('No results found'), findsNothing);

      await cubit.close();
    });
  });
}
