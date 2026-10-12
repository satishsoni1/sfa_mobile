import 'package:flutter/foundation.dart';

/// Team member returned by GET /secondary-sales/upload/team-members.
/// Laravel is the source of truth — field names are parsed flexibly.
class SecondarySalesUploadTeamMember {
  const SecondarySalesUploadTeamMember({
    required this.id,
    required this.name,
    this.code,
    this.designation,
    this.teamCode,
    this.teamName,
    this.label,
    this.isSelf = false,
  });

  final int id;
  final String name;
  final String? code;
  final String? designation;
  final String? teamCode;
  final String? teamName;
  /// Prefer Laravel-provided display label when present.
  final String? label;
  final bool isSelf;

  /// Primary line shown in selectors.
  /// Prefers API `label`, else builds: Name — Designation — Team Name
  /// (omitting null/empty parts; never fabricates a team name).
  String get displayLabel {
    final fromApi = label?.trim();
    if (fromApi != null && fromApi.isNotEmpty) return fromApi;

    final parts = <String>[];
    final n = name.trim();
    if (n.isNotEmpty) parts.add(n);
    final d = designation?.trim();
    if (d != null && d.isNotEmpty) parts.add(d);
    final t = teamName?.trim();
    if (t != null && t.isNotEmpty) parts.add(t);
    if (parts.isEmpty) return 'Employee $id';
    return parts.join(' — ');
  }

  String get subtitle {
    final parts = <String>[];
    if (code != null && code!.trim().isNotEmpty) {
      parts.add('Employee ID: ${code!.trim()}');
    } else {
      parts.add('Employee ID: $id');
    }
    if (designation != null && designation!.trim().isNotEmpty) {
      parts.add(designation!.trim());
    }
    if (teamName != null && teamName!.trim().isNotEmpty) {
      parts.add(teamName!.trim());
    } else if (teamCode != null && teamCode!.trim().isNotEmpty) {
      parts.add('Team: ${teamCode!.trim()}');
    }
    if (isSelf) parts.add('Myself');
    return parts.join(' · ');
  }

  factory SecondarySalesUploadTeamMember.fromJson(Map<String, dynamic> json) {
    // Prefer employee_id when both exist (Laravel contract).
    final id = _asInt(
          json['employee_id'] ??
              json['id'] ??
              json['emp_id'] ??
              json['user_id'],
        ) ??
        0;

    final name = (json['name'] ??
            json['employee_name'] ??
            json['full_name'] ??
            json['display_name'] ??
            'Employee')
        .toString()
        .trim();

    final designation = _asNullableString(
      json['designation'] ??
          json['designation_name'] ??
          json['role'] ??
          json['position'],
    );

    final teamName = _asNullableString(
      json['team_name'] ?? json['teamName'] ?? json['team'],
    );
    final teamCode = _asNullableString(
      json['team_code'] ?? json['teamCode'],
    );

    final label = _asNullableString(json['label'] ?? json['display_label']);

    final code = _asNullableString(
      json['code'] ??
          json['employee_code'] ??
          json['emp_code'] ??
          json['employee_id'] ??
          json['id'],
    );

    return SecondarySalesUploadTeamMember(
      id: id,
      name: name.isEmpty ? 'Employee' : name,
      code: code,
      designation: designation,
      teamCode: teamCode,
      teamName: teamName,
      label: label,
      isSelf: _asBool(json['is_self'] ?? json['isSelf']),
    );
  }

  /// Defensive list parser for the Laravel upload-on-behalf contract.
  ///
  /// Preferred extraction order (verified API):
  /// 1. `data.team_members`
  /// 2. `data.employees`
  /// 3. top-level `employees`
  /// plus a few legacy wrappers for backward compatibility.
  static List<SecondarySalesUploadTeamMember> listFrom(dynamic raw) {
    final rows = _extractRows(raw);
    // ignore: avoid_print
    print('[SS_ON_BEHALF_TRACE] listFrom extracted-row-count=${rows.length}');
    final out = <SecondarySalesUploadTeamMember>[];
    final seen = <int>{};
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is! Map) {
        // ignore: avoid_print
        print(
          '[SS_ON_BEHALF_TRACE] skip non-map row index=$i type=${row.runtimeType}',
        );
        continue;
      }
      try {
        final member = SecondarySalesUploadTeamMember.fromJson(
          Map<String, dynamic>.from(row),
        );
        if (member.id <= 0) {
          // ignore: avoid_print
          print('[SS_ON_BEHALF_TRACE] skip invalid id row index=$i');
          continue;
        }
        if (!seen.add(member.id)) continue;
        out.add(member);
      } catch (e) {
        // Skip malformed rows; do not fail the whole list.
        // ignore: avoid_print
        print('[SS_ON_BEHALF_TRACE] bad employee row index=$i error=$e');
        continue;
      }
    }
    // ignore: avoid_print
    print('[SS_ON_BEHALF_TRACE] listFrom model-count=${out.length}');
    return out;
  }

  static List<dynamic> _extractRows(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) return List<dynamic>.from(raw);
    if (raw is! Map) return const [];

    final map = Map<String, dynamic>.from(raw);
    final data = map['data'];

    // 1) Preferred: data.team_members  2) data.employees
    if (data is Map) {
      final nested = Map<String, dynamic>.from(data);
      final teamMembers = nested['team_members'];
      if (teamMembers is List) {
        debugPrint('[SS_ON_BEHALF] source=data.team_members');
        return List<dynamic>.from(teamMembers);
      }
      final nestedEmployees = nested['employees'];
      if (nestedEmployees is List) {
        debugPrint('[SS_ON_BEHALF] source=data.employees');
        return List<dynamic>.from(nestedEmployees);
      }
      // Legacy paginator / aliases under data.
      for (final key in const ['members', 'items', 'results', 'data', 'list']) {
        final value = nested[key];
        if (value is List) {
          debugPrint('[SS_ON_BEHALF] source=data.$key');
          return List<dynamic>.from(value);
        }
      }
      // Keyed employee map only when every value is a row object
      // (never treat metadata maps with bools/lists as employee rows).
      if (nested.isNotEmpty &&
          !nested.containsKey('can_upload_on_behalf') &&
          !nested.containsKey('viewer_employee_id') &&
          nested.values.every((v) => v is Map)) {
        debugPrint('[SS_ON_BEHALF] source=data.keyedMap');
        return nested.values.toList();
      }
    } else if (data is List) {
      // Legacy: { data: [ ...employees ] }
      debugPrint('[SS_ON_BEHALF] source=data(list)');
      return List<dynamic>.from(data);
    }

    // 3) Top-level employees (backward compatible)
    final topEmployees = map['employees'];
    if (topEmployees is List) {
      debugPrint('[SS_ON_BEHALF] source=employees(top)');
      return List<dynamic>.from(topEmployees);
    }

    for (final key in const [
      'team_members',
      'members',
      'users',
      'items',
      'results',
      'list',
    ]) {
      final value = map[key];
      if (value is List) {
        debugPrint('[SS_ON_BEHALF] source=$key(top)');
        return List<dynamic>.from(value);
      }
    }

    return const [];
  }
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}

String? _asNullableString(dynamic v) {
  if (v == null) return null;
  // Avoid treating a nested Map/List as a "team name".
  if (v is Map || v is List) {
    if (v is Map) {
      final name = v['name'] ?? v['team_name'] ?? v['label'];
      if (name != null) {
        final s = name.toString().trim();
        return s.isEmpty ? null : s;
      }
    }
    return null;
  }
  final s = v.toString().trim();
  if (s.isEmpty || s.toLowerCase() == 'null') return null;
  return s;
}

bool _asBool(dynamic v) {
  if (v == true || v == 1 || v == '1') return true;
  if (v is String) {
    final s = v.toLowerCase().trim();
    return s == 'true' || s == 'yes';
  }
  return false;
}
