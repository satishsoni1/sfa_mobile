import 'dart:convert';
import 'package:flutter/material.dart';

// ─── Material Type ────────────────────────────────────────────────────────────

enum DataBankMaterialType { pdf, video, image, link }

extension DataBankMaterialTypeX on DataBankMaterialType {
  String get key {
    switch (this) {
      case DataBankMaterialType.pdf: return 'pdf';
      case DataBankMaterialType.video: return 'video';
      case DataBankMaterialType.image: return 'image';
      case DataBankMaterialType.link: return 'link';
    }
  }

  String get label {
    switch (this) {
      case DataBankMaterialType.pdf: return 'PDF';
      case DataBankMaterialType.video: return 'Video';
      case DataBankMaterialType.image: return 'Image';
      case DataBankMaterialType.link: return 'Link';
    }
  }

  IconData get icon {
    switch (this) {
      case DataBankMaterialType.pdf: return Icons.picture_as_pdf_outlined;
      case DataBankMaterialType.video: return Icons.play_circle_outline_rounded;
      case DataBankMaterialType.image: return Icons.image_outlined;
      case DataBankMaterialType.link: return Icons.open_in_browser_outlined;
    }
  }

  Color get color {
    switch (this) {
      case DataBankMaterialType.pdf: return const Color(0xFFD32F2F);
      case DataBankMaterialType.video: return const Color(0xFF1565C0);
      case DataBankMaterialType.image: return const Color(0xFF2E7D32);
      case DataBankMaterialType.link: return const Color(0xFFE65100);
    }
  }

  static DataBankMaterialType fromKey(String k) => DataBankMaterialType.values
      .firstWhere((v) => v.key == k, orElse: () => DataBankMaterialType.pdf);
}

// ─── Category ─────────────────────────────────────────────────────────────────

class DataBankCategory {
  final String id;
  final String name;
  final String description;
  final String iconKey;
  final String colorHex;
  int materialCount;
  int mandatoryCount;

  DataBankCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.iconKey,
    required this.colorHex,
    this.materialCount = 0,
    this.mandatoryCount = 0,
  });

  Color get color {
    try {
      return Color(int.parse('0xFF${colorHex.replaceFirst('#', '')}'));
    } catch (_) {
      return const Color(0xFF4A148C);
    }
  }

  IconData get icon {
    switch (iconKey) {
      case 'medication': return Icons.medication_outlined;
      case 'science': return Icons.science_outlined;
      case 'verified': return Icons.verified_outlined;
      case 'psychology': return Icons.psychology_outlined;
      case 'campaign': return Icons.campaign_outlined;
      case 'map': return Icons.map_outlined;
      case 'school': return Icons.school_outlined;
      case 'analytics': return Icons.analytics_outlined;
      default: return Icons.folder_outlined;
    }
  }

  factory DataBankCategory.fromDb(Map<String, dynamic> r) => DataBankCategory(
        id: r['id'] as String,
        name: r['name'] as String,
        description: r['description']?.toString() ?? '',
        iconKey: r['icon_key']?.toString() ?? 'folder',
        colorHex: r['color_hex']?.toString() ?? '#4A148C',
        materialCount: r['material_count'] as int? ?? 0,
        mandatoryCount: r['mandatory_count'] as int? ?? 0,
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'name': name,
        'description': description,
        'icon_key': iconKey,
        'color_hex': colorHex,
      };
}

// ─── Material ─────────────────────────────────────────────────────────────────

class DataBankMaterial {
  final String id;
  final String categoryId;
  final String title;
  final String description;
  final DataBankMaterialType type;
  final String? thumbnailUrl;
  final String sourceUrl;
  final int fileSizeKb;
  final int? durationSeconds;
  bool isDownloaded;
  String? localPath;
  final DateTime publishedAt;
  final List<String> tags;
  final bool isMandatory;
  final bool isFeatured;
  int viewCount;
  int completionCount;
  bool isBookmarked;

  // Per-user engagement (joined from view_logs for current user)
  int userDurationSeconds;
  bool userCompleted;
  DateTime? userLastViewedAt;

  DataBankMaterial({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.type,
    this.thumbnailUrl,
    required this.sourceUrl,
    this.fileSizeKb = 0,
    this.durationSeconds,
    this.isDownloaded = false,
    this.localPath,
    required this.publishedAt,
    this.tags = const [],
    this.isMandatory = false,
    this.isFeatured = false,
    this.viewCount = 0,
    this.completionCount = 0,
    this.isBookmarked = false,
    this.userDurationSeconds = 0,
    this.userCompleted = false,
    this.userLastViewedAt,
  });

  bool get isNew => DateTime.now().difference(publishedAt).inDays <= 7;

  String get fileSizeLabel {
    if (fileSizeKb == 0) return '';
    if (fileSizeKb < 1024) return '$fileSizeKb KB';
    return '${(fileSizeKb / 1024).toStringAsFixed(1)} MB';
  }

  String? get durationLabel {
    if (durationSeconds == null || durationSeconds == 0) return null;
    final m = durationSeconds! ~/ 60;
    final s = durationSeconds! % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  double get userProgressFraction {
    if (userCompleted) return 1.0;
    if (durationSeconds == null || durationSeconds == 0) return 0;
    return (userDurationSeconds / durationSeconds!).clamp(0.0, 1.0);
  }

  factory DataBankMaterial.fromDb(Map<String, dynamic> r) => DataBankMaterial(
        id: r['id'] as String,
        categoryId: r['category_id'] as String,
        title: r['title'] as String,
        description: r['description']?.toString() ?? '',
        type: DataBankMaterialTypeX.fromKey(r['type']?.toString() ?? 'pdf'),
        thumbnailUrl: r['thumbnail_url']?.toString(),
        sourceUrl: r['source_url']?.toString() ?? '',
        fileSizeKb: r['file_size_kb'] as int? ?? 0,
        durationSeconds: r['duration_seconds'] as int?,
        isDownloaded: (r['is_downloaded'] as int? ?? 0) == 1,
        localPath: r['local_path']?.toString(),
        publishedAt: DateTime.parse(r['published_at'] as String),
        tags: r['tags'] != null
            ? List<String>.from(json.decode(r['tags'] as String))
            : [],
        isMandatory: (r['is_mandatory'] as int? ?? 0) == 1,
        isFeatured: (r['is_featured'] as int? ?? 0) == 1,
        viewCount: r['view_count'] as int? ?? 0,
        completionCount: r['completion_count'] as int? ?? 0,
        isBookmarked: (r['is_bookmarked'] as int? ?? 0) == 1,
        userDurationSeconds: r['user_duration'] as int? ?? 0,
        userCompleted: (r['user_completed'] as int? ?? 0) == 1,
        userLastViewedAt: r['user_last_viewed'] != null
            ? DateTime.tryParse(r['user_last_viewed'] as String)
            : null,
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'category_id': categoryId,
        'title': title,
        'description': description,
        'type': type.key,
        'thumbnail_url': thumbnailUrl,
        'source_url': sourceUrl,
        'file_size_kb': fileSizeKb,
        'duration_seconds': durationSeconds,
        'is_downloaded': isDownloaded ? 1 : 0,
        'local_path': localPath,
        'published_at': publishedAt.toIso8601String(),
        'tags': json.encode(tags),
        'is_mandatory': isMandatory ? 1 : 0,
        'is_featured': isFeatured ? 1 : 0,
        'view_count': viewCount,
        'completion_count': completionCount,
        'is_bookmarked': isBookmarked ? 1 : 0,
      };
}

// ─── View Log ─────────────────────────────────────────────────────────────────

class DataBankViewLog {
  final String id;
  final String materialId;
  final String employeeCode;
  final DateTime startedAt;
  DateTime? endedAt;
  int durationSeconds;
  bool completed;

  DataBankViewLog({
    required this.id,
    required this.materialId,
    required this.employeeCode,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.completed = false,
  });

  factory DataBankViewLog.fromDb(Map<String, dynamic> r) => DataBankViewLog(
        id: r['id'] as String,
        materialId: r['material_id'] as String,
        employeeCode: r['employee_code']?.toString() ?? '',
        startedAt: DateTime.parse(r['started_at'] as String),
        endedAt: r['ended_at'] != null
            ? DateTime.tryParse(r['ended_at'] as String)
            : null,
        durationSeconds: r['duration_seconds'] as int? ?? 0,
        completed: (r['completed'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'material_id': materialId,
        'employee_code': employeeCode,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'duration_seconds': durationSeconds,
        'completed': completed ? 1 : 0,
      };
}

// ─── Analytics Summary ────────────────────────────────────────────────────────

class DataBankUserStats {
  final int totalViewed;
  final int totalCompleted;
  final int mandatoryPending;
  final int bookmarked;
  final int totalViewTimeMinutes;

  const DataBankUserStats({
    this.totalViewed = 0,
    this.totalCompleted = 0,
    this.mandatoryPending = 0,
    this.bookmarked = 0,
    this.totalViewTimeMinutes = 0,
  });
}
