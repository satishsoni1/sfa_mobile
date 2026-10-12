import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:zforce/features/pod/config/pod_config.dart';
import 'package:zforce/features/pod/models/batch_model.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/models/secondary_sales_upload_on_behalf_models.dart';
import 'package:zforce/features/pod/models/statement_detail_model.dart';
import 'package:zforce/features/pod/services/secondary_sales_multi_page_upload_service.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_service.dart';
import 'package:zforce/features/pod/services/secondary_sales_upload_on_behalf_service.dart';
import 'package:zforce/features/pod/widgets/secondary_sales_on_behalf_section.dart';

void main() {
  group('SecondarySalesUploadTeamMember model', () {
    test('parses Laravel team member payload flexibly', () {
      final member = SecondarySalesUploadTeamMember.fromJson({
        'id': 1234,
        'name': 'Rahul Sharma',
        'employee_code': 'EMP-1234',
        'designation': 'Medical Representative',
      });
      expect(member.id, 1234);
      expect(member.name, 'Rahul Sharma');
      expect(member.code, 'EMP-1234');
      expect(member.designation, 'Medical Representative');
      expect(member.subtitle, contains('Employee ID: EMP-1234'));
      expect(member.subtitle, contains('Medical Representative'));
      expect(
        member.displayLabel,
        'Rahul Sharma — Medical Representative',
      );
    });

    test('prefers Laravel label and supports null team_name', () {
      final labeled = SecondarySalesUploadTeamMember.fromJson({
        'employee_id': 123,
        'id': 123,
        'name': 'A YOGESH',
        'designation': 'MEDICAL REPRESENTATIVE',
        'team_code': '340',
        'team_name': 'AJMER TEAM',
        'label': 'A YOGESH — MEDICAL REPRESENTATIVE — AJMER TEAM',
        'is_self': false,
      });
      expect(labeled.id, 123);
      expect(labeled.displayLabel,
          'A YOGESH — MEDICAL REPRESENTATIVE — AJMER TEAM');
      expect(labeled.isSelf, isFalse);

      final noTeam = SecondarySalesUploadTeamMember.fromJson({
        'employee_id': 99,
        'name': 'ADARSH MISHRA',
        'designation': 'MR',
        'team_name': null,
      });
      expect(noTeam.displayLabel, 'ADARSH MISHRA — MR');
      expect(noTeam.teamName, isNull);
      expect(noTeam.displayLabel, isNot(contains('null')));

      final aadhithyan = SecondarySalesUploadTeamMember.fromJson({
        'employee_id': 9392,
        'id': 9392,
        'name': 'AADHITHYAN S',
        'designation': 'MR',
        'team_code': '408',
        'team_name': 'CHENNAI',
        'label': 'AADHITHYAN S — MR — CHENNAI',
        'is_self': false,
      });
      expect(aadhithyan.id, 9392);
      expect(aadhithyan.displayLabel, 'AADHITHYAN S — MR — CHENNAI');

      final selfAdmin = SecondarySalesUploadTeamMember.fromJson({
        'id': 1,
        'name': 'admin',
        'designation': 'Admin (Myself)',
        'label': 'admin — Admin (Myself)',
        'is_self': true,
      });
      expect(selfAdmin.displayLabel, 'admin — Admin (Myself)');
      expect(selfAdmin.isSelf, isTrue);
    });

    test('listFrom keeps distinct employees and skips invalid ids', () {
      final members = SecondarySalesUploadTeamMember.listFrom({
        'data': [
          {'id': 10, 'name': 'Amit Kumar'},
          {'id': 11, 'name': 'Amit Kumar', 'designation': 'MR'},
          {'name': 'No Id'},
        ],
      });
      expect(members, hasLength(2));
      expect(members.map((m) => m.id), [10, 11]);
    });

    test('listFrom tolerates nested wrappers and keyed maps without throwing',
        () {
      final nested = SecondarySalesUploadTeamMember.listFrom({
        'success': true,
        'data': {
          'team_members': [
            {
              'employee_id': 5,
              'name': 'A',
              'designation': 'MR',
              'team_name': null,
            },
          ],
        },
      });
      expect(nested, hasLength(1));
      expect(nested.first.displayLabel, 'A — MR');

      final keyed = SecondarySalesUploadTeamMember.listFrom({
        'data': {
          '12': {'id': 12, 'name': 'X'},
          '34': {'id': 34, 'name': 'Y', 'team_name': null},
        },
      });
      expect(keyed.map((m) => m.id), [12, 34]);
    });
  });

  group('SecondarySalesUploadOnBehalfService', () {
    test('team members API loads successfully', () async {
      final service = SecondarySalesUploadOnBehalfService(
        getter: (uri) async {
          expect(
            uri.toString(),
            contains('secondary-sales/upload/team-members'),
          );
          expect(uri.path, isNot(contains('/stockists')));
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 1234,
                  'name': 'Rahul Sharma',
                  'code': '1234',
                  'designation': 'Medical Representative',
                },
                {
                  'id': 1240,
                  'name': 'Amit Kumar',
                  'code': '1240',
                  'designation': 'Medical Representative',
                },
              ],
            }),
            200,
          );
        },
      );

      final members = await service.fetchTeamMembers();
      expect(members, hasLength(2));
      expect(members.first.name, 'Rahul Sharma');
      expect(members.last.id, 1240);
    });

    test('selecting employee loads stockists from employee endpoint', () async {
      final called = <String>[];
      final service = SecondarySalesUploadOnBehalfService(
        getter: (uri) async {
          called.add(uri.toString());
          expect(
            uri.toString(),
            contains('secondary-sales/upload/team-members/1240/stockists'),
          );
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 3,
                  'name': 'Stockist 3',
                  'code': 'S3',
                  'address_display': 'City A',
                },
                {
                  'id': 4,
                  'name': 'Stockist 4',
                  'code': 'S4',
                  'address_display': 'City B',
                },
                {
                  'id': 5,
                  'name': 'Stockist 5',
                  'code': 'S5',
                },
              ],
            }),
            200,
          );
        },
      );

      final stockists = await service.fetchStockistsForEmployee(1240);
      expect(stockists.map((s) => s.id), [3, 4, 5]);
      expect(called, hasLength(1));
    });

    test('same-name stockists remain separate with address', () async {
      final service = SecondarySalesUploadOnBehalfService(
        getter: (_) async => http.Response(
          jsonEncode({
            'data': [
              {
                'id': 444,
                'name': 'RICHA PHARMA',
                'code': '714987',
                'address_display':
                    'GOLA ROAD, HOSPITAL ROAD, HATPAR, NAWADA, Bihar - 805110',
              },
              {
                'id': 445,
                'name': 'RICHA PHARMA',
                'code': '714988',
                'address_display': 'MAIN BAZAR, PATNA, Bihar - 800001',
              },
            ],
          }),
          200,
        ),
      );

      final stockists = await service.fetchStockistsForEmployee(99);
      expect(stockists, hasLength(2));
      expect(stockists[0].id, 444);
      expect(stockists[1].id, 445);
      expect(stockists[0].name, stockists[1].name);
      expect(stockists[0].displayAddress, contains('NAWADA'));
      expect(stockists[1].displayAddress, contains('PATNA'));
    });

    test('403 team members shows authorization error', () async {
      final service = SecondarySalesUploadOnBehalfService(
        getter: (_) async => http.Response('{}', 403),
      );

      expect(
        () => service.fetchTeamMembers(),
        throwsA(
          isA<SecondarySalesUploadOnBehalfException>()
              .having((e) => e.isForbidden, 'isForbidden', isTrue)
              .having(
                (e) => e.message,
                'message',
                contains('not authorized'),
              ),
        ),
      );
    });

    test('403 stockists for employee shows clean message', () async {
      final service = SecondarySalesUploadOnBehalfService(
        getter: (_) async => http.Response('{}', 403),
      );

      expect(
        () => service.fetchStockistsForEmployee(55),
        throwsA(
          isA<SecondarySalesUploadOnBehalfException>().having(
            (e) => e.message,
            'message',
            'You are not authorized to upload on behalf of this employee.',
          ),
        ),
      );
    });

    test('422 validation errors are displayed from Laravel body', () async {
      final service = SecondarySalesUploadOnBehalfService(
        getter: (_) async => http.Response(
          jsonEncode({
            'message': 'The given data was invalid.',
            'errors': {
              'employee': ['Selected employee is invalid.'],
            },
          }),
          422,
        ),
      );

      expect(
        () => service.fetchStockistsForEmployee(1),
        throwsA(
          isA<SecondarySalesUploadOnBehalfException>().having(
            (e) => e.message,
            'message',
            contains('Selected employee is invalid.'),
          ),
        ),
      );
    });

    test('network/API failures are handled gracefully', () async {
      final service = SecondarySalesUploadOnBehalfService(
        getter: (_) async => http.Response('server boom', 500),
      );

      expect(
        () => service.fetchTeamMembers(),
        throwsA(
          isA<SecondarySalesUploadOnBehalfException>().having(
            (e) => e.message,
            'message',
            contains('Server error (500)'),
          ),
        ),
      );
    });

    test('parses verified Laravel data.team_members contract', () async {
      final payload = {
        'success': true,
        'can_upload_on_behalf': true,
        'viewer_employee_id': 9387,
        'employees': [
          {
            'employee_id': 1,
            'id': 1,
            'name': 'TOP LEVEL ONLY',
            'designation': 'MR',
            'team_name': 'SHOULD NOT WIN',
            'label': 'TOP LEVEL ONLY — MR — SHOULD NOT WIN',
            'is_self': false,
          },
        ],
        'data': {
          'can_upload_on_behalf': true,
          'viewer_employee_id': 9387,
          'team_members': [
            {
              'employee_id': 9392,
              'id': 9392,
              'name': 'AADHITHYAN S',
              'designation': 'MR',
              'team_code': '408',
              'team_name': 'CHENNAI',
              'label': 'AADHITHYAN S — MR — CHENNAI',
              'is_self': false,
            },
            {
              'employee_id': 9388,
              'id': 9388,
              'name': 'BHARATHIRAJA',
              'designation': 'MR',
              'team_code': '410',
              'team_name': 'TANJORE',
              'label': 'BHARATHIRAJA — MR — TANJORE',
              'is_self': false,
            },
          ],
          'employees': [
            {
              'employee_id': 2,
              'id': 2,
              'name': 'NESTED EMPLOYEES FALLBACK',
              'designation': 'MR',
            },
          ],
        },
      };
      final service = SecondarySalesUploadOnBehalfService(
        getter: (_) async => http.Response.bytes(
          utf8.encode(jsonEncode(payload)),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      final members = await service.fetchTeamMembers();
      expect(members, hasLength(2));
      expect(members.first.id, 9392);
      expect(members.first.displayLabel, 'AADHITHYAN S — MR — CHENNAI');
      expect(members.first.teamName, 'CHENNAI');
      expect(members.first.teamCode, '408');
      expect(members.first.isSelf, isFalse);
      expect(members.map((m) => m.name), isNot(contains('TOP LEVEL ONLY')));
    });

    test('falls back to data.employees then top-level employees', () async {
      final nestedEmployees = SecondarySalesUploadTeamMember.listFrom({
        'success': true,
        'data': {
          'employees': [
            {
              'employee_id': 55,
              'name': 'From Data Employees',
              'designation': 'RM',
              'team_name': 'ZONE A',
            },
          ],
        },
      });
      expect(nestedEmployees, hasLength(1));
      expect(nestedEmployees.first.id, 55);
      expect(
        nestedEmployees.first.displayLabel,
        'From Data Employees — RM — ZONE A',
      );

      final topLevel = SecondarySalesUploadTeamMember.listFrom({
        'success': true,
        'employees': [
          {
            'employee_id': 77,
            'name': 'Top Level',
            'designation': 'MR',
            'team_name': null,
            'label': null,
          },
        ],
      });
      expect(topLevel, hasLength(1));
      expect(topLevel.first.id, 77);
      expect(topLevel.first.displayLabel, 'Top Level — MR');
      expect(topLevel.first.displayLabel, isNot(contains('null')));
    });
  });

  group('upload fields on_behalf_of_employee_id', () {
    test('upload without on-behalf omits the field', () {
      final fields = buildSecondarySalesUploadFields(
        stockistId: 45,
        selectedMonth: DateTime(2026, 9),
      );
      expect(fields.containsKey('on_behalf_of_employee_id'), isFalse);
      expect(fields['stockist_id'], '45');
      expect(fields['statement_month'], '2026-09');
    });

    test('upload with on-behalf sends on_behalf_of_employee_id', () {
      final fields = buildSecondarySalesUploadFields(
        stockistId: 45,
        selectedMonth: DateTime(2026, 9),
        onBehalfOfEmployeeId: 1240,
      );
      expect(fields['on_behalf_of_employee_id'], '1240');
      expect(fields['stockist_id'], '45');
    });

    test('multi-page upload with on-behalf sends on_behalf_of_employee_id', () {
      final fields = SecondarySalesMultiPageUploadService.buildMultipartFields(
        stockistId: 3,
        month: '2026-09',
        clientUploadId: 'client-1',
        onBehalfOfEmployeeId: 1240,
      );
      expect(fields['is_multi_page'], 'true');
      expect(fields['on_behalf_of_employee_id'], '1240');
      expect(fields['client_upload_id'], 'client-1');
      expect(fields.containsKey('files[]'), isFalse);
    });

    test('multi-page upload without on-behalf omits the field', () {
      final fields = SecondarySalesMultiPageUploadService.buildMultipartFields(
        stockistId: 3,
        month: '2026-09',
        clientUploadId: 'client-1',
      );
      expect(fields.containsKey('on_behalf_of_employee_id'), isFalse);
      expect(fields['is_multi_page'], 'true');
    });

    test('zero or negative on-behalf id is omitted', () {
      final fields = buildSecondarySalesUploadFields(
        stockistId: 1,
        selectedMonth: DateTime(2026, 1),
        onBehalfOfEmployeeId: 0,
      );
      expect(fields.containsKey('on_behalf_of_employee_id'), isFalse);
    });
  });

  group('stockist search / filter for on-behalf lists', () {
    final stockists = [
      const SecondarySalesStockistInfo(
        id: 444,
        name: 'RICHA PHARMA',
        code: '714987',
        addressDisplay: 'Nawada, Bihar',
      ),
      const SecondarySalesStockistInfo(
        id: 445,
        name: 'RICHA PHARMA',
        code: '714988',
        addressDisplay: 'Patna, Bihar',
      ),
      const SecondarySalesStockistInfo(
        id: 500,
        name: 'ALPHA MEDICOS',
        code: 'A1',
      ),
    ];

    test('stockist search works and keeps same-name IDs separate', () {
      final filtered = filterAuthorizedStockists(stockists, 'RICHA');
      expect(filtered, hasLength(2));
      expect(filtered.map((s) => s.id), [444, 445]);
      expect(filtered[0].displayAddress, 'Nawada, Bihar');
      expect(filtered[1].displayAddress, 'Patna, Bihar');
    });

    test('search by code distinguishes same-name stockists', () {
      final filtered = filterAuthorizedStockists(stockists, '714988');
      expect(filtered, hasLength(1));
      expect(filtered.single.id, 445);
    });
  });

  group('employee search filter', () {
    test('employee search matches name, code, and designation', () {
      const members = [
        SecondarySalesUploadTeamMember(
          id: 1234,
          name: 'Rahul Sharma',
          code: '1234',
          designation: 'Medical Representative',
        ),
        SecondarySalesUploadTeamMember(
          id: 1240,
          name: 'Amit Kumar',
          code: '1240',
          designation: 'Medical Representative',
        ),
        SecondarySalesUploadTeamMember(
          id: 2000,
          name: 'Priya Nair',
          code: '2000',
          designation: 'Area Manager',
        ),
      ];

      List<SecondarySalesUploadTeamMember> filter(String q) {
        final query = q.trim().toLowerCase();
        if (query.isEmpty) return List.from(members);
        return members.where((m) {
          return m.name.toLowerCase().contains(query) ||
              (m.code ?? '').toLowerCase().contains(query) ||
              m.id.toString().contains(query) ||
              (m.designation ?? '').toLowerCase().contains(query);
        }).toList();
      }

      expect(filter('rahul').map((m) => m.id), [1234]);
      expect(filter('1240').map((m) => m.id), [1240]);
      expect(filter('area').map((m) => m.id), [2000]);
      expect(filter('').length, 3);
    });
  });

  group('changing employee clears previous stockist', () {
    testWidgets('selecting a new employee clears prior stockist selection',
        (tester) async {
      SecondarySalesUploadTeamMember? selectedEmployee;
      SecondarySalesStockistInfo? selectedStockist;
      var stockistFetchCount = 0;

      final service = SecondarySalesUploadOnBehalfService(
        getter: (uri) async {
          if (uri.toString().contains('/stockists')) {
            stockistFetchCount++;
            final employeeId = uri.pathSegments[uri.pathSegments.length - 2];
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': int.parse(employeeId) * 10,
                    'name': 'Stockist for $employeeId',
                    'code': 'C$employeeId',
                    'address_display': 'Address $employeeId',
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 10, 'name': 'Employee A', 'code': '10'},
                {'id': 20, 'name': 'Employee B', 'code': '20'},
              ],
            }),
            200,
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SecondarySalesOnBehalfSection(
                  service: service,
                  selectedEmployee: selectedEmployee,
                  selectedStockist: selectedStockist,
                  onEmployeeChanged: (member) {
                    setState(() {
                      selectedEmployee = member;
                      selectedStockist = null;
                    });
                  },
                  onStockistChanged: (stockist) {
                    setState(() => selectedStockist = stockist);
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Select Team Member'), findsOneWidget);

      await tester.tap(find.text('Select Team Member'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Employee A'));
      await tester.pumpAndSettle();

      expect(selectedEmployee?.id, 10);
      expect(selectedStockist, isNull);
      expect(find.text('Select Stockist'), findsOneWidget);

      await tester.tap(find.text('Select Stockist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stockist for 10'));
      await tester.pumpAndSettle();
      expect(selectedStockist?.id, 100);
      expect(find.text('Stockist for 10'), findsWidgets);

      // Change employee — stockist must clear.
      await tester.tap(find.text('Employee A').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Employee B'));
      await tester.pumpAndSettle();

      expect(selectedEmployee?.id, 20);
      expect(selectedStockist, isNull);
      expect(find.text('Select Stockist'), findsOneWidget);
      expect(find.text('Stockist for 10'), findsNothing);
      expect(stockistFetchCount, greaterThanOrEqualTo(2));
    });

    testWidgets('empty team members shows unavailable message', (tester) async {
      final service = SecondarySalesUploadOnBehalfService(
        getter: (_) async => http.Response(jsonEncode({'data': []}), 200),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecondarySalesOnBehalfSection(
              service: service,
              selectedEmployee: null,
              selectedStockist: null,
              onEmployeeChanged: (_) {},
              onStockistChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(
        find.text('Upload on behalf is not available for your account.'),
        findsOneWidget,
      );
      expect(find.text('Select Team Member'), findsNothing);
    });

    testWidgets('team member list is displayed in searchable sheet',
        (tester) async {
      final service = SecondarySalesUploadOnBehalfService(
        getter: (_) async => http.Response(
          jsonEncode({
            'data': [
              {
                'id': 1234,
                'name': 'Rahul Sharma',
                'code': '1234',
                'designation': 'Medical Representative',
              },
              {
                'id': 1240,
                'name': 'Amit Kumar',
                'code': '1240',
                'designation': 'Medical Representative',
              },
            ],
          }),
          200,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecondarySalesOnBehalfSection(
              service: service,
              selectedEmployee: null,
              selectedStockist: null,
              onEmployeeChanged: (_) {},
              onStockistChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Select Team Member'));
      await tester.pumpAndSettle();

      expect(
        find.text('Rahul Sharma — Medical Representative'),
        findsOneWidget,
      );
      expect(
        find.text('Amit Kumar — Medical Representative'),
        findsOneWidget,
      );
      expect(find.textContaining('Employee ID: 1234'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Amit');
      await tester.pumpAndSettle();
      expect(
        find.text('Amit Kumar — Medical Representative'),
        findsOneWidget,
      );
      expect(
        find.text('Rahul Sharma — Medical Representative'),
        findsNothing,
      );
    });
  });

  group('audit display from Laravel fields', () {
    test('statement detail parses Uploaded By and On Behalf Of', () {
      final detail = StatementDetail.fromJson({
        'id': 1,
        'status': 'completed',
        'uploaded_by': 'Manager Name',
        'on_behalf_of': 'Employee B',
        'source_file_name': 'stmt.pdf',
      });
      expect(detail.uploadedBy, 'Manager Name');
      expect(detail.onBehalfOf, 'Employee B');
    });

    test('batch parses On Behalf Of without fabricating values', () {
      final batch = Batch.fromJson({
        'id': 99,
        'user_id': 1,
        'hospital_id': 0,
        'stockist_id': 3,
        'total_files': 1,
        'successful_files': 1,
        'failed_files': 0,
        'cancelled_files': 0,
        'status': 'completed',
        'steps': {},
        'created_at': '2026-09-01T00:00:00Z',
        'updated_at': '2026-09-01T00:00:00Z',
        'user': {'name': 'Manager Name'},
        'on_behalf_of_employee': {'name': 'Employee B'},
      });
      expect(batch.userName, 'Manager Name');
      expect(batch.onBehalfOf, 'Employee B');
    });

    test('batch without on-behalf leaves field null', () {
      final batch = Batch.fromJson({
        'id': 1,
        'user_id': 1,
        'hospital_id': 0,
        'stockist_id': 1,
        'total_files': 1,
        'successful_files': 1,
        'failed_files': 0,
        'cancelled_files': 0,
        'status': 'completed',
        'steps': {},
        'created_at': '',
        'updated_at': '',
        'user': {'name': 'Self Upload'},
      });
      expect(batch.onBehalfOf, isNull);
      expect(batch.userName, 'Self Upload');
    });
  });

  group('API URLs', () {
    test('team-members and employee stockists URLs match Laravel contract', () {
      expect(
        API_SECONDARY_SALES_UPLOAD_TEAM_MEMBERS_URL,
        endsWith('secondary-sales/upload/team-members'),
      );
      expect(
        secondarySalesUploadTeamMemberStockistsUrl(1240),
        endsWith('secondary-sales/upload/team-members/1240/stockists'),
      );
    });
  });
}
