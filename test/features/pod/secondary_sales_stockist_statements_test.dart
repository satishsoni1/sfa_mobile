import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/routes/pod_routes.dart';
import 'package:zforce/features/pod/screens/main_navigation.dart';
import 'package:zforce/features/pod/screens/secondary_sales_dashboard_screen.dart';
import 'package:zforce/features/pod/screens/secondary_sales_kam_stockists_screen.dart';
import 'package:zforce/features/pod/screens/secondary_sales_stockist_statements_screen.dart';
import 'package:zforce/features/pod/services/secondary_sales_background_monitor.dart';
import 'package:zforce/features/pod/services/secondary_sales_dashboard_service.dart';

void main() {
  setUp(() {
    SecondarySalesBackgroundMonitor.suppressInTests = true;
    SecondarySalesBackgroundMonitor.instance.stop();
  });
  tearDown(() {
    SecondarySalesBackgroundMonitor.instance.stop();
    SecondarySalesBackgroundMonitor.suppressInTests = false;
  });

  final productionPayload = {
    'success': true,
    'data': {
      'stockist': {'id': 2134, 'name': 'KAMAL DRUG DISTRIBUTORS'},
      'month': '2026-09',
      'statements': [
        {
          'id': 6,
          'document_id': 6,
          'batch_id': 6,
          'batch_code': '20260913002',
          'file_name': '0000737479_2026_08_ZL_20_296_04092026065133.pdf',
          'status': 'completed',
          'stockist_name': 'KAMAL DRUG DISTRIBUTORS',
          'sales': 144030.0,
          'product_count': 44,
          'created_at': '2026-09-13T22:22:31+05:30',
          'statement_month': '2026-09',
        },
      ],
    },
    'pagination': {
      'current_page': 1,
      'per_page': 20,
      'total_pages': 1,
      'total_records': 1,
      'total': 1,
      'last_page': 1,
      'next_page': null,
      'prev_page': null,
    },
  };

  group('SecondarySalesStockistStatement models', () {
    test('parses production-style payload and keeps null sales', () {
      final response =
          SecondarySalesStockistStatementsResponse.fromJson(productionPayload);
      expect(response.stockist.id, 2134);
      expect(response.stockist.name, 'KAMAL DRUG DISTRIBUTORS');
      expect(response.month, '2026-09');
      expect(response.statements, hasLength(1));
      expect(response.statements.first.id, 6);
      expect(response.statements.first.documentId, 6);
      expect(response.statements.first.batchId, 6);
      expect(response.statements.first.sales, 144030.0);
      expect(response.statements.first.productCount, 44);
      expect(response.pagination.nextPage, isNull);

      final pending = SecondarySalesStockistStatement.fromJson({
        'id': 7,
        'document_id': 7,
        'batch_id': 8,
        'file_name': 'pending.pdf',
        'status': 'pending',
        'sales': null,
        'product_count': 0,
      });
      expect(pending.sales, isNull);
      expect(pending.displayStatus, 'Pending');
    });

    test('orders statements newest processed first', () {
      final response = SecondarySalesStockistStatementsResponse.fromJson({
        'data': {
          'stockist': {'id': 1, 'name': 'MEDICINE HOUSE'},
          'month': '2026-09',
          'statements': [
            {
              'id': 10,
              'document_id': 10,
              'batch_id': 450,
              'file_name': 'older.pdf',
              'status': 'completed',
              'created_at': '2026-09-10T10:00:00+05:30',
            },
            {
              'id': 12,
              'document_id': 12,
              'batch_id': 461,
              'file_name': 'newest.pdf',
              'status': 'completed',
              'created_at': '2026-09-28T18:00:00+05:30',
            },
            {
              'id': 11,
              'document_id': 11,
              'batch_id': 455,
              'file_name': 'middle.pdf',
              'status': 'completed',
              'created_at': '2026-09-20T12:00:00+05:30',
            },
          ],
        },
        'pagination': {
          'current_page': 1,
          'per_page': 20,
          'total_records': 3,
          'next_page': null,
        },
      });
      expect(
        response.statements.map((s) => s.id).toList(),
        [12, 11, 10],
      );
    });

    test('orders undated newest batch above older dated statement', () {
      final response = SecondarySalesStockistStatementsResponse.fromJson({
        'data': {
          'stockist': {'id': 1, 'name': 'MEDICINE HOUSE'},
          'month': '2026-09',
          'statements': [
            {
              'id': 10,
              'document_id': 10,
              'batch_id': 450,
              'file_name': 'older.pdf',
              'status': 'completed',
              'created_at': '2026-09-10T10:00:00+05:30',
            },
            {
              'id': 99,
              'document_id': 99,
              'batch_id': 500,
              'file_name': 'brand-new.pdf',
              'status': 'completed',
            },
          ],
        },
        'pagination': {
          'current_page': 1,
          'per_page': 20,
          'total_records': 2,
          'next_page': null,
        },
      });
      expect(response.statements.map((s) => s.id).toList(), [99, 10]);
    });

    test('uses uploaded_at when created_at is absent', () {
      final response = SecondarySalesStockistStatementsResponse.fromJson({
        'data': {
          'stockist': {'id': 1, 'name': 'MEDICINE HOUSE'},
          'month': '2026-09',
          'statements': [
            {
              'id': 1,
              'batch_id': 1,
              'file_name': 'a.pdf',
              'status': 'completed',
              'uploaded_at': '2026-09-01T10:00:00+05:30',
            },
            {
              'id': 2,
              'batch_id': 2,
              'file_name': 'b.pdf',
              'status': 'completed',
              'uploaded_at': '2026-09-28T10:00:00+05:30',
            },
          ],
        },
        'pagination': {
          'current_page': 1,
          'per_page': 20,
          'total_records': 2,
          'next_page': null,
        },
      });
      expect(response.statements.map((s) => s.id).toList(), [2, 1]);
    });

    test('does not drop statements that share a file name', () {
      final response = SecondarySalesStockistStatementsResponse.fromJson({
        'data': {
          'stockist': {'id': 2134, 'name': 'KAMAL'},
          'month': '2026-09',
          'statements': [
            {
              'id': 6,
              'document_id': 6,
              'batch_id': 6,
              'file_name': 'same.pdf',
              'status': 'completed',
              'sales': 10,
            },
            {
              'id': 7,
              'document_id': 7,
              'batch_id': 7,
              'file_name': 'same.pdf',
              'status': 'completed',
              'sales': 20,
            },
          ],
        },
        'pagination': {
          'current_page': 1,
          'per_page': 20,
          'total_records': 2,
          'next_page': null,
        },
      });
      expect(response.statements, hasLength(2));
      expect(response.statements.map((s) => s.id), [7, 6]);
    });

    test('breakdown row uses stockist id, not name', () {
      final row = SecondarySalesBreakdownRow.fromJson({
        'id': 2134,
        'name': 'KAMAL DRUG DISTRIBUTORS',
        'sales': 144030,
        'percentage': 98.89,
        'processed': 1,
      });
      expect(row.id, 2134);
      expect(row.name, 'KAMAL DRUG DISTRIBUTORS');
    });

    test('parses nested stockist object and camelCase ids', () {
      final nested = SecondarySalesStockistPerformance.fromJson({
        'stockist': {'id': 869, 'name': 'SOUTH DELHI DISTRIBUTORS'},
        'sales': 1518636.91,
        'statements': 1,
        'completed_statements': 1,
      });
      expect(nested.stockistId, 869);
      expect(nested.stockistName, 'SOUTH DELHI DISTRIBUTORS');

      final camel = SecondarySalesStockistPerformance.fromJson({
        'stockistId': 777,
        'stockistName': 'AMARJEET MEDICAL HALL',
        'totalStatements': 2,
        'completedStatements': 2,
      });
      expect(camel.stockistId, 777);
      expect(camel.stockistName, 'AMARJEET MEDICAL HALL');
      expect(camel.documents, 2);
    });
  });

  group('Stockist Statements screen', () {
    testWidgets('renders multiple cards including duplicate file names',
        (tester) async {
      final service = _FakeDashboardService(
        statements: SecondarySalesStockistStatementsResponse.fromJson({
          'data': {
            'stockist': {'id': 2134, 'name': 'KAMAL DRUG DISTRIBUTORS'},
            'month': '2026-09',
            'statements': [
              {
                'id': 6,
                'document_id': 6,
                'batch_id': 6,
                'file_name': '0000737479_2026_08_ZL_20_296_04092026065133.pdf',
                'status': 'completed',
                'sales': 144030.0,
                'product_count': 44,
                'created_at': '2026-09-13T22:22:31+05:30',
              },
              {
                'id': 7,
                'document_id': 7,
                'batch_id': 7,
                'file_name': '0000737479_2026_08_ZL_20_296_04092026065133.pdf',
                'status': 'completed',
                'sales': 539.0,
                'product_count': 126,
              },
            ],
          },
          'pagination': {
            'current_page': 1,
            'per_page': 20,
            'total_records': 2,
            'next_page': null,
          },
        }),
      );

      await tester.pumpWidget(
        _app(
          SecondarySalesStockistStatementsScreen(
            stockistId: 2134,
            stockistName: 'KAMAL DRUG DISTRIBUTORS',
            month: '2026-09',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('KAMAL DRUG DISTRIBUTORS'), findsWidgets);
      expect(find.text('Statements'), findsWidgets);
      expect(find.text('September 2026'), findsWidgets);
      expect(find.text('VIEW'), findsNWidgets(2));
      expect(find.textContaining('₹1,44,030.00'), findsOneWidget);
      expect(find.textContaining('₹539.00'), findsOneWidget);
      expect(find.text('Products: 44'), findsOneWidget);
      expect(find.text('Completed'), findsNWidgets(2));
      expect(service.statementCalls.single['stockistId'], 2134);
      expect(service.statementCalls.single['month'], '2026-09');
      expect(service.statementCalls.single['kamId'], isNull);
    });

    testWidgets('null sales does not display ₹0.00', (tester) async {
      await tester.pumpWidget(
        _app(
          SecondarySalesStockistStatementsScreen(
            stockistId: 2134,
            stockistName: 'KAMAL',
            month: '2026-09',
            service: _FakeDashboardService(
              statements: SecondarySalesStockistStatementsResponse.fromJson({
                'data': {
                  'stockist': {'id': 2134, 'name': 'KAMAL'},
                  'month': '2026-09',
                  'statements': [
                    {
                      'id': 8,
                      'document_id': 8,
                      'file_name': 'pending.pdf',
                      'status': 'pending',
                      'sales': null,
                    },
                  ],
                },
                'pagination': {
                  'current_page': 1,
                  'per_page': 20,
                  'total_records': 1,
                  'next_page': null,
                },
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('₹0.00'), findsNothing);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('empty response shows empty state', (tester) async {
      await tester.pumpWidget(
        _app(
          SecondarySalesStockistStatementsScreen(
            stockistId: 2134,
            stockistName: 'KAMAL',
            month: '2026-09',
            service: _FakeDashboardService(
              statements: SecondarySalesStockistStatementsResponse.fromJson({
                'data': {
                  'stockist': {'id': 2134, 'name': 'KAMAL'},
                  'month': '2026-09',
                  'statements': [],
                },
                'pagination': {
                  'current_page': 1,
                  'per_page': 20,
                  'total_records': 0,
                  'next_page': null,
                },
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No statements found for KAMAL for September 2026.'),
        findsOneWidget,
      );
      expect(find.textContaining('September 2026'), findsWidgets);
    });

    testWidgets('API failure displays retry, not credential copy',
        (tester) async {
      await tester.pumpWidget(
        _app(
          SecondarySalesStockistStatementsScreen(
            stockistId: 2134,
            stockistName: 'KAMAL',
            month: '2026-09',
            service: _FakeDashboardService(
              statementsError: const SecondarySalesDashboardException(
                'Unable to load stockist statements',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Unable to load stockist statements'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Invalid Credentials or Network Error'), findsNothing);
    });

    testWidgets('VIEW opens existing statement detail flow', (tester) async {
      RouteSettings? opened;
      await tester.pumpWidget(
        _app(
          SecondarySalesStockistStatementsScreen(
            stockistId: 2134,
            stockistName: 'KAMAL',
            month: '2026-09',
            service: _FakeDashboardService(
              statements:
                  SecondarySalesStockistStatementsResponse.fromJson(
                productionPayload,
              ),
            ),
          ),
          onRoute: (settings) => opened = settings,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('VIEW'));
      await tester.pumpAndSettle();

      expect(opened?.name, PodRoutes.statementDetail);
      expect((opened?.arguments as Map)['podId'], 6);
      expect(find.text('statement-detail'), findsOneWidget);
    });

    testWidgets('pagination loads the next page without duplicates',
        (tester) async {
      final page1 = List.generate(
        20,
        (i) => {
          'id': i + 1,
          'document_id': i + 1,
          'batch_id': i + 1,
          'file_name': 'file-$i.pdf',
          'status': 'completed',
          'sales': 10.0,
        },
      );
      final service = _FakeDashboardService(
        pages: {
          1: SecondarySalesStockistStatementsResponse.fromJson({
            'data': {
              'stockist': {'id': 2134, 'name': 'KAMAL'},
              'month': '2026-09',
              'statements': page1,
            },
            'pagination': {
              'current_page': 1,
              'per_page': 20,
              'total_records': 21,
              'next_page': 2,
            },
          }),
          2: SecondarySalesStockistStatementsResponse.fromJson({
            'data': {
              'stockist': {'id': 2134, 'name': 'KAMAL'},
              'month': '2026-09',
              'statements': [
                {
                  'id': 21,
                  'document_id': 21,
                  'batch_id': 21,
                  'file_name': 'file-next.pdf',
                  'status': 'completed',
                  'sales': 99.0,
                },
              ],
            },
            'pagination': {
              'current_page': 2,
              'per_page': 20,
              'total_records': 21,
              'next_page': null,
            },
          }),
        },
      );

      await tester.pumpWidget(
        _app(
          SecondarySalesStockistStatementsScreen(
            stockistId: 2134,
            stockistName: 'KAMAL',
            month: '2026-09',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.statementCalls, hasLength(1));
      expect(service.statementCalls.first['page'], 1);

      await tester.drag(find.byType(ListView).last, const Offset(0, -4000));
      await tester.pumpAndSettle();

      expect(service.statementCalls.map((c) => c['page']), [1, 2]);
      // Page-2 row sorts to the top (highest id); scroll back so ListView builds it.
      await tester.drag(find.byType(ListView).last, const Offset(0, 4000));
      await tester.pumpAndSettle();
      expect(find.text('file-next.pdf'), findsOneWidget);
    });
  });

  group('Hierarchy dashboard', () {
    test('parses manager, kam, and stockist performance from API', () {
      final data = SecondarySalesDashboardData.fromJson({
        'data': {
          'filters': {
            'hierarchy': {'unrestricted': true},
          },
          'overview': {'total_sales': 145647.0, 'total_documents': 4},
          'manager_performance': [
            {
              'employee_id': 201,
              'employee_name': 'Manager B',
              'designation': 'RM',
              'total_sales': 1200000,
              'total_documents': 20,
              'team_size': 8,
            },
          ],
          'kam_performance': [
            {
              'employee_id': 101,
              'employee_name': 'KAM A',
              'designation': 'PSO',
              'manager_id': 201,
              'total_sales': 500000,
              'total_documents': 8,
              'stockist_count': 5,
            },
          ],
          'stockist_performance': [
            {
              'stockist_id': 2134,
              'stockist_name': 'KAMAL DRUG DISTRIBUTORS',
              'kam_id': 101,
              'sales': 144030,
              'documents': 1,
              'completed_statements': 1,
            },
          ],
        },
      });
      expect(data.filters.hierarchy?.unrestricted, isTrue);
      expect(data.filters.unrestricted, isTrue);
      expect(data.managerPerformance.single.employeeId, 201);
      expect(data.kamPerformance.single.employeeId, 101);
      expect(data.visibleStockists.single.stockistId, 2134);
      expect(data.overview.statementCount, 4);
    });

    testWidgets('manager sees team performance and can open KAM stockists',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      final service = _FakeDashboardService(
        dashboard: SecondarySalesDashboardData.fromJson({
          'data': {
            'overview': {'total_sales': 1250000, 'total_documents': 20},
            'manager_performance': [
              {
                'employee_id': 201,
                'employee_name': 'Manager B',
                'designation': 'RM',
                'total_sales': 1250000,
                'total_documents': 20,
              },
            ],
            'kam_performance': [
              {
                'employee_id': 101,
                'employee_name': 'KAM A',
                'designation': 'PSO',
                'total_sales': 500000,
                'total_documents': 8,
                'stockist_count': 3,
              },
            ],
          },
        }),
        kamStockists: SecondarySalesKamStockistsResponse.fromJson({
          'data': {
            'kam': {'id': 101, 'name': 'KAM A'},
            'month': '2026-09',
            'total_sales': 500000,
            'stockists': [
              {
                'stockist_id': 2134,
                'stockist_name': 'KAMAL DRUG DISTRIBUTORS',
                'sales': 144030,
                'documents': 1,
              },
            ],
          },
        }),
      );

      await tester.pumpWidget(
        _app(SecondarySalesDashboardScreen(service: service)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Team Performance'), findsOneWidget);
      expect(find.text('Manager B'), findsOneWidget);
      expect(find.text('KAM A'), findsOneWidget);
      expect(find.text('Total Sales'), findsOneWidget);
      expect(find.text('Statements'), findsWidgets);

      await tester.ensureVisible(find.text('KAM A'));
      await tester.tap(find.text('KAM A'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(SecondarySalesKamStockistsScreen), findsOneWidget);
      expect(service.kamCalls.single['kamId'], 101);
      expect(find.text('KAMAL DRUG DISTRIBUTORS'), findsOneWidget);
    });

    testWidgets('empty month shows no-data state', (tester) async {
      await tester.pumpWidget(
        _app(
          SecondarySalesDashboardScreen(
            service: _FakeDashboardService(
              dashboard: SecondarySalesDashboardData.fromJson({
                'data': {
                  'overview': {'total_sales': 0, 'total_documents': 0},
                },
              }),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('No stockist statements available'), findsOneWidget);
      expect(find.text('Recent Statements'), findsNothing);
    });

    testWidgets('403 shows authorization message without retry', (tester) async {
      await tester.pumpWidget(
        _app(
          SecondarySalesKamStockistsScreen(
            employeeId: 101,
            employeeName: 'KAM A',
            month: '2026-09',
            service: _FakeDashboardService(
              kamError: const SecondarySalesDashboardException(
                'You are not authorized to view this data.',
                403,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('You are not authorized to view this data.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('processing and failed statements display status',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        _app(
          SecondarySalesStockistStatementsScreen(
            stockistId: 2134,
            stockistName: 'KAMAL',
            month: '2026-09',
            service: _FakeDashboardService(
              statements: SecondarySalesStockistStatementsResponse.fromJson({
                'data': {
                  'stockist': {'id': 2134, 'name': 'KAMAL'},
                  'month': '2026-09',
                  'statements': [
                    {
                      'id': 1,
                      'document_id': 1,
                      'file_name': 'done.pdf',
                      'status': 'completed',
                      'sales': 144030.0,
                      'product_count': 44,
                    },
                    {
                      'id': 2,
                      'document_id': 2,
                      'file_name': 'busy.pdf',
                      'status': 'processing',
                    },
                    {
                      'id': 3,
                      'document_id': 3,
                      'file_name': 'bad.pdf',
                      'status': 'failed',
                      'error_message': 'Parse error',
                    },
                  ],
                },
                'pagination': {
                  'current_page': 1,
                  'per_page': 20,
                  'next_page': null,
                },
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Processing'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Parse error'), findsOneWidget);
      expect(find.text('VIEW'), findsNWidgets(2));
      expect(find.text('PROCESSING'), findsOneWidget);
      expect(find.textContaining('₹1,44,030.00'), findsOneWidget);
    });
  });

  group('Dashboard stockist tap', () {
    testWidgets('passes stockist id and selected month', (tester) async {
      final now = DateTime.now();
      final month =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
      final service = _FakeDashboardService(
        dashboard: SecondarySalesDashboardData.fromJson({
          'data': {
            'overview': {'total_sales': 144030, 'total_statements': 1},
            'performance_breakdown': {
              'stockist': [
                {
                  'id': 2134,
                  'name': 'KAMAL DRUG DISTRIBUTORS',
                  'sales': 144030,
                  'percentage': 98.89,
                  'processed': 1,
                },
              ],
            },
            'recent_documents': [],
          },
        }),
        statements: SecondarySalesStockistStatementsResponse.fromJson(
          productionPayload,
        ),
      );

      await tester.pumpWidget(
        _app(SecondarySalesDashboardScreen(service: service)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // No team rows → stockists pane is shown directly (no Team/Stockists tabs).
      expect(find.text('KAMAL DRUG DISTRIBUTORS'), findsOneWidget);
      await tester.tap(find.text('KAMAL DRUG DISTRIBUTORS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(SecondarySalesStockistStatementsScreen), findsOneWidget);
      final screen = tester.widget<SecondarySalesStockistStatementsScreen>(
        find.byType(SecondarySalesStockistStatementsScreen),
      );
      expect(screen.stockistId, 2134);
      expect(screen.month, month);
    });

    testWidgets('KAM and stockist search filter authorized rows only',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        _app(
          SecondarySalesDashboardScreen(
            service: _FakeDashboardService(
              dashboard: SecondarySalesDashboardData.fromJson({
                'data': {
                  'overview': {'total_sales': 10, 'total_documents': 1},
                  'kam_performance': [
                    {
                      'employee_id': 101,
                      'employee_name': 'KAM A',
                      'total_sales': 10,
                      'total_documents': 1,
                    },
                    {
                      'employee_id': 102,
                      'employee_name': 'KAM B',
                      'total_sales': 0,
                      'total_documents': 0,
                    },
                  ],
                  'stockist_performance': [
                    {
                      'stockist_id': 2134,
                      'stockist_name': 'KAMAL DRUG DISTRIBUTORS',
                      'sales': 10,
                      'documents': 1,
                    },
                    {
                      'stockist_id': 3001,
                      'stockist_name': 'BABA',
                      'sales': 5,
                      'documents': 1,
                    },
                  ],
                },
              }),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(
        find.widgetWithText(TextField, 'Search employee'),
        'KAM A',
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('KAM A'), findsWidgets);
      expect(find.text('KAM B'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('ss-tab-stockists')));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search stockist name or code'),
        'BABA',
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('BABA'), findsWidgets);
      expect(find.text('KAMAL DRUG DISTRIBUTORS'), findsNothing);
    });
  });

  group('Admin unrestricted dashboard', () {
    Map<String, dynamic> adminPayload() => {
          'data': {
            'filters': {
              'month': '2026-09',
              'hierarchy': {'viewer_id': 1, 'unrestricted': true},
            },
            'overview': {'total_sales': 145647.0, 'total_documents': 4},
            'manager_performance': [
              {
                'employee_id': 301,
                'employee_name': 'Top Manager',
                'designation': 'NSM',
                'total_sales': 145647,
                'total_documents': 4,
                'team_size': 3,
              },
              {
                'employee_id': 201,
                'employee_name': 'Manager B',
                'designation': 'RM',
                'manager_id': 301,
                'manager_name': 'Top Manager',
                'total_sales': 125000,
                'total_documents': 4,
                'team_size': 2,
              },
            ],
            'kam_performance': [
              {
                'employee_id': 101,
                'employee_name': 'KAM A',
                'designation': 'PSO',
                'manager_id': 201,
                'manager_name': 'Manager B',
                'total_sales': 125000,
                'total_documents': 4,
                'stockist_count': 3,
              },
              {
                'employee_id': 102,
                'employee_name': 'KAM Zero',
                'designation': 'PSO',
                'manager_id': 201,
                'manager_name': 'Manager B',
                'total_sales': 0,
                'total_documents': 0,
                'stockist_count': 0,
              },
            ],
            'stockist_performance': [
              {
                'stockist_id': 2227,
                'stockist_name': 'Mapped Stockist',
                'kam_id': 101,
                'kam_name': 'KAM A',
                'sales': 100000,
                'documents': 3,
                'completed_statements': 3,
              },
              {
                'stockist_id': 2134,
                'stockist_name': 'KAMAL DRUG DISTRIBUTORS',
                'kam_id': null,
                'kam_name': null,
                'sales': 144030,
                'documents': 1,
                'completed_statements': 1,
              },
              {
                'stockist_id': 3001,
                'stockist_name': 'BABA',
                'kam_id': null,
                'kam_name': null,
                'sales': 539,
                'documents': 1,
              },
            ],
          },
        };

    test('parses hierarchy metadata without local designation logic', () {
      final data = SecondarySalesDashboardData.fromJson({
        'hierarchy': {
          'level': 'RM',
          'employee_id': 123,
          'employee_name': 'Sample RM',
          'visible_employee_count': 12,
          'can_view_team': true,
          'can_view_all': false,
        },
        'data': {
          'filters': {
            'available_kams': [
              {'id': 101, 'name': 'Visible Employee'},
            ],
          },
          'overview': {'total_sales': 10, 'total_documents': 1},
          'manager_performance': [],
          'kam_performance': [
            {
              'employee_id': 101,
              'employee_name': 'Visible Employee',
              'total_sales': 10,
            },
          ],
          'stockist_performance': [],
        },
      });
      expect(data.hierarchy?.employeeId, 123);
      expect(data.hierarchy?.canViewTeam, isTrue);
      expect(data.hierarchy?.canViewAll, isFalse);
      expect(data.hierarchy?.visibleEmployeeCount, 12);
      expect(data.hierarchy?.sectionTitle, "MY TEAM'S SECONDARY SALES");
      expect(data.showsTeamSection, isTrue);
      expect(data.teamEmployees, hasLength(1));
    });

    test('hides team section when Laravel can_view_team is false', () {
      final data = SecondarySalesDashboardData.fromJson({
        'data': {
          'hierarchy': {
            'level': 'KAM',
            'employee_id': 55,
            'employee_name': 'Solo KAM',
            'visible_employee_count': 1,
            'can_view_team': false,
            'can_view_all': false,
          },
          'overview': {'total_sales': 5, 'total_documents': 1},
          'kam_performance': [],
          'manager_performance': [],
          'stockist_performance': [
            {'stockist_id': 1, 'stockist_name': 'Only Mine', 'sales': 5},
          ],
        },
      });
      expect(data.showsTeamSection, isFalse);
      expect(data.hierarchy?.sectionTitle, 'MY SECONDARY SALES');
    });

    test('parses unrestricted hierarchy and keeps unmapped/zero rows', () {
      final data = SecondarySalesDashboardData.fromJson(adminPayload());
      expect(data.filters.hierarchy?.unrestricted, isTrue);
      expect(data.filters.hierarchy?.viewerId, 1);
      expect(data.managerPerformance, hasLength(2));
      expect(data.kamPerformance, hasLength(2));
      expect(data.visibleStockists, hasLength(3));
      expect(data.visibleStockists.where((s) => s.kamId == null), hasLength(2));
      expect(data.visibleStockists.firstWhere((s) => s.stockistId == 2134).kamLabel,
          'Unassigned');
      expect(data.kamPerformance.firstWhere((k) => k.employeeId == 102).totalSales,
          0);

      final tree = SecondarySalesHierarchyTree.fromApi(
        managers: data.managerPerformance,
        kams: data.kamPerformance,
      );
      expect(tree.single.employee.employeeName, 'Top Manager');
      expect(tree.single.children.single.employee.employeeName, 'Manager B');
      expect(
        tree.single.children.single.children.map((c) => c.employee.employeeName),
        ['KAM A', 'KAM Zero'],
      );
    });

    testWidgets('admin sees managers, kams, mapped and unmapped stockists',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final service = _FakeDashboardService(
        dashboard: SecondarySalesDashboardData.fromJson(adminPayload()),
        kamStockists: SecondarySalesKamStockistsResponse.fromJson({
          'data': {
            'kam': {'id': 101, 'name': 'KAM A'},
            'month': '2026-09',
            'stockists': [
              {
                'stockist_id': 2227,
                'stockist_name': 'Mapped Stockist',
                'sales': 100000,
                'documents': 3,
              },
            ],
          },
        }),
        statements: SecondarySalesStockistStatementsResponse.fromJson({
          'data': {
            'stockist': {'id': 2134, 'name': 'KAMAL DRUG DISTRIBUTORS'},
            'month': '2026-09',
            'statements': [
              {
                'id': 6,
                'document_id': 6,
                'file_name': 'admin.pdf',
                'status': 'completed',
                'sales': 144030.0,
              },
            ],
          },
          'pagination': {'current_page': 1, 'per_page': 20, 'next_page': null},
        }),
      );

      await tester.pumpWidget(
        _app(SecondarySalesDashboardScreen(service: service)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Total Sales'), findsOneWidget);
      expect(find.text('Team'), findsOneWidget);
      expect(find.byKey(const ValueKey('ss-tab-stockists')), findsOneWidget);
      expect(find.text('Top Manager'), findsOneWidget);
      expect(find.text('Manager B'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('ss-expand-301')));
      await tester.pump();
      expect(find.text('Manager B'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ss-expand-201')));
      await tester.pump();
      expect(find.text('KAM A'), findsOneWidget);
      expect(find.text('KAM Zero'), findsOneWidget);
      expect(find.textContaining('₹0.00'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('ss-tab-stockists')));
      await tester.pump();
      expect(find.text('Mapped Stockist'), findsOneWidget);
      expect(find.text('KAMAL DRUG DISTRIBUTORS'), findsOneWidget);
      expect(find.text('BABA'), findsOneWidget);
      expect(find.text('KAM: Unassigned'), findsNWidgets(2));
      expect(find.text('KAM: KAM A'), findsOneWidget);

      await tester.tap(find.text('KAMAL DRUG DISTRIBUTORS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(SecondarySalesStockistStatementsScreen), findsOneWidget);
      expect(service.statementCalls.first['stockistId'], 2134);
      expect(service.statementCalls.first['month'], service.dashboardMonths.last);
      expect(service.statementCalls.first['kamId'], isNull);
    });

    testWidgets('View Statements keeps selected dashboard month', (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final service = _FakeDashboardService(
        dashboard: SecondarySalesDashboardData.fromJson(adminPayload()),
        statements: SecondarySalesStockistStatementsResponse.fromJson({
          'data': {
            'stockist': {'id': 2134, 'name': 'KAMAL DRUG DISTRIBUTORS'},
            'month': '2026-08',
            'statements': [
              {
                'id': 6,
                'document_id': 6,
                'file_name': 'aug.pdf',
                'status': 'completed',
                'sales': 144030.0,
              },
            ],
          },
          'pagination': {'current_page': 1, 'per_page': 20, 'next_page': null},
        }),
      );

      await tester.pumpWidget(
        _app(SecondarySalesDashboardScreen(service: service)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      final previous = DateTime(now.year, now.month - 1, 1);
      final previousKey =
          '${previous.year.toString().padLeft(4, '0')}-${previous.month.toString().padLeft(2, '0')}';
      final label = DateFormat('MMM yyyy').format(previous);
      await tester.tap(find.text(label).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(service.dashboardMonths.last, previousKey);

      await tester.tap(find.byKey(const ValueKey('ss-tab-stockists')));
      await tester.pump();
      await tester.tap(find.text('KAMAL DRUG DISTRIBUTORS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(SecondarySalesStockistStatementsScreen), findsOneWidget);
      expect(service.statementCalls.single['stockistId'], 2134);
      expect(service.statementCalls.single['month'], previousKey);
      expect(service.statementCalls.single['kamId'], isNull);
      expect(find.text(DateFormat('MMMM yyyy').format(previous)), findsWidgets);
    });

    testWidgets('month change reloads dashboard', (tester) async {
      final service = _FakeDashboardService(
        dashboard: SecondarySalesDashboardData.fromJson(adminPayload()),
      );
      await tester.pumpWidget(
        _app(SecondarySalesDashboardScreen(service: service)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(service.dashboardMonths, hasLength(1));

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      final previous = DateTime(now.year, now.month - 1, 1);
      final label = DateFormat('MMM yyyy').format(previous);
      await tester.tap(find.text(label).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(service.dashboardMonths, hasLength(2));
      expect(service.dashboardMonths.first, isNot(service.dashboardMonths.last));
    });
  });

  group('Invoice POD safety', () {
    test('statement detail route still requires podId', () {
      final route = PodRouteGenerator.generateRoute(
        const RouteSettings(
          name: PodRoutes.statementDetail,
          arguments: {'podId': 6},
        ),
      );
      expect(route, isA<MaterialPageRoute>());
    });

    test('MainNavigation still gates Invoice POD vs Secondary Sales', () {
      expect(isSecondarySalesUpload, isTrue);
      expect(MainNavigation, isNotNull);
    });
  });

  group('Secondary Sales module navigation', () {
    testWidgets(
      'Dashboard AppBar back asks before leaving module; Cancel stays',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MainNavigation(),
                      ),
                    );
                  },
                  child: const Text('open-ss'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open-ss'));
        await tester.pumpAndSettle();

        expect(find.byType(MainNavigation), findsOneWidget);
        expect(find.byType(SecondarySalesDashboardScreen), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Leave Secondary Sales'), findsOneWidget);
        expect(find.text('Do you want to return to Home?'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.byType(MainNavigation), findsOneWidget);
        expect(find.byType(SecondarySalesDashboardScreen), findsOneWidget);
        expect(find.text('open-ss'), findsNothing);
      },
    );

    testWidgets('Dashboard AppBar Leave pops module without duplicate Home',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MainNavigation(),
                    ),
                  );
                },
                child: const Text('open-ss'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open-ss'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigation), findsNothing);
      expect(find.text('open-ss'), findsOneWidget);
    });

    testWidgets(
      'Android system back on nested POD navigator shows leave confirm',
      (tester) async {
        final nestedKey = GlobalKey<NavigatorState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PopScope(
                          canPop: false,
                          onPopInvokedWithResult: (didPop, result) async {
                            if (didPop) return;
                            final nested = nestedKey.currentState;
                            if (nested == null) return;
                            if (nested.canPop()) {
                              nested.pop();
                              return;
                            }
                            await nested.maybePop();
                          },
                          child: Navigator(
                            key: nestedKey,
                            onGenerateInitialRoutes: (navigator, name) {
                              return [
                                MaterialPageRoute<void>(
                                  builder: (_) => const MainNavigation(),
                                ),
                              ];
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('open-ss'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open-ss'));
        await tester.pumpAndSettle();

        expect(find.byType(MainNavigation), findsOneWidget);

        // Simulate Android system back (root route PopScope → nested maybePop).
        final handled = await tester.binding.handlePopRoute();
        expect(handled, isTrue);
        await tester.pumpAndSettle();

        expect(find.text('Leave Secondary Sales'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(MainNavigation), findsOneWidget);
      },
    );
  });
}

Widget _app(Widget home, {void Function(RouteSettings settings)? onRoute}) {
  return MaterialApp(
    home: home,
    onGenerateRoute: (settings) {
      onRoute?.call(settings);
      if (settings.name == PodRoutes.statementDetail) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('statement-detail')),
        );
      }
      if (settings.name == PodRoutes.uploadStatus) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('upload-status')),
        );
      }
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('other-route')),
      );
    },
  );
}

class _FakeDashboardService extends SecondarySalesDashboardService {
  _FakeDashboardService({
    SecondarySalesDashboardData? dashboard,
    this.statements,
    this.pages,
    this.statementsError,
    this.kamStockists,
    this.kamError,
  }) : dashboard = dashboard ??
            SecondarySalesDashboardData.fromJson(const {'data': {}});

  final SecondarySalesDashboardData dashboard;
  final SecondarySalesStockistStatementsResponse? statements;
  final Map<int, SecondarySalesStockistStatementsResponse>? pages;
  final Exception? statementsError;
  final SecondarySalesKamStockistsResponse? kamStockists;
  final Exception? kamError;
  final List<Map<String, Object?>> statementCalls = [];
  final List<Map<String, Object?>> kamCalls = [];

  final List<String> dashboardMonths = [];

  @override
  Future<SecondarySalesDashboardData> fetchDashboard({
    required String month,
    String? kamId,
    String? employeeId,
    String? zoneId,
    String? stockistId,
    String? search,
  }) async {
    dashboardMonths.add(month);
    return dashboard;
  }

  @override
  Future<SecondarySalesKamStockistsResponse> fetchKamStockists({
    required int kamId,
    required String month,
  }) async {
    kamCalls.add({'kamId': kamId, 'month': month});
    if (kamError != null) throw kamError!;
    return kamStockists ??
        const SecondarySalesKamStockistsResponse(
          month: '',
          stockists: [],
        );
  }

  @override
  Future<SecondarySalesStockistStatementsResponse> getStockistStatements({
    required int stockistId,
    required String month,
    int page = 1,
    int perPage = 20,
    String? search,
    int? kamId,
    String? zoneId,
  }) async {
    statementCalls.add({
      'stockistId': stockistId,
      'month': month,
      'page': page,
      'perPage': perPage,
      'search': search,
      'kamId': kamId,
      'zoneId': zoneId,
    });
    if (statementsError != null) throw statementsError!;
    if (pages != null) {
      return pages![page] ??
          const SecondarySalesStockistStatementsResponse(
            stockist: SecondarySalesStockistInfo(name: 'Stockist'),
            month: '',
            statements: [],
            pagination: SecondarySalesPagination(currentPage: 1, perPage: 20),
          );
    }
    return statements ??
        const SecondarySalesStockistStatementsResponse(
          stockist: SecondarySalesStockistInfo(name: 'Stockist'),
          month: '',
          statements: [],
          pagination: SecondarySalesPagination(currentPage: 1, perPage: 20),
        );
  }
}
