import 'dart:convert';

// ─── Doctor ───────────────────────────────────────────────────────────────────

class ClmDoctor {
  final int id;
  final String name;
  final String speciality;
  final String category; // A, B, C
  final String territory;
  final String area;
  final String mobile;
  final String? email;
  final String? hospital;
  final String? address;
  final int priority; // 1=high 2=med 3=low
  final List<int> assignedBrandIds;
  final DateTime? lastDetailedAt;
  final int totalSessions;
  bool isPlanned;
  // "MM-DD" strings for recurring reminders
  final String? birthday;
  final String? anniversary;
  final DateTime? nextCallDate;
  final int callFrequencyTarget; // visits/month target
  final double? latitude;
  final double? longitude;

  ClmDoctor({
    required this.id,
    required this.name,
    required this.speciality,
    required this.category,
    required this.territory,
    required this.area,
    required this.mobile,
    this.email,
    this.hospital,
    this.address,
    this.priority = 2,
    this.assignedBrandIds = const [],
    this.lastDetailedAt,
    this.totalSessions = 0,
    this.isPlanned = false,
    this.birthday,
    this.anniversary,
    this.nextCallDate,
    this.callFrequencyTarget = 2,
    this.latitude,
    this.longitude,
  });

  factory ClmDoctor.fromJson(Map<String, dynamic> j) => ClmDoctor(
        id: (j['id'] as num).toInt(),
        name: _titleCase(j['doctor_name'] ?? j['name'] ?? ''),
        speciality: j['speciality']?.toString() ?? '',
        category: j['category']?.toString() ?? 'C',
        territory: j['territory']?.toString() ?? '',
        area: j['area']?.toString() ?? '',
        mobile: j['mobile_no']?.toString() ?? j['mobile']?.toString() ?? '',
        email: j['email']?.toString(),
        hospital: j['hospital']?.toString(),
        address: j['address']?.toString(),
        priority: (j['priority'] as num?)?.toInt() ?? 2,
        assignedBrandIds: (j['brand_ids'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            [],
        lastDetailedAt: j['last_detailed_at'] != null
            ? DateTime.tryParse(j['last_detailed_at'].toString())
            : null,
        totalSessions: (j['total_sessions'] as num?)?.toInt() ?? 0,
        isPlanned: j['is_planned'] == 1 || j['is_planned'] == true,
        birthday: j['birthday']?.toString(),
        anniversary: j['anniversary']?.toString(),
        nextCallDate: j['next_call_date'] != null
            ? DateTime.tryParse(j['next_call_date'].toString())
            : null,
        callFrequencyTarget: (j['call_freq_target'] as num?)?.toInt() ?? 2,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
      );

  factory ClmDoctor.fromDb(Map<String, dynamic> r) => ClmDoctor(
        id: r['id'] as int,
        name: r['name'] as String,
        speciality: r['speciality']?.toString() ?? '',
        category: r['category']?.toString() ?? 'C',
        territory: r['territory']?.toString() ?? '',
        area: r['area']?.toString() ?? '',
        mobile: r['mobile']?.toString() ?? '',
        email: r['email']?.toString(),
        hospital: r['hospital']?.toString(),
        address: r['address']?.toString(),
        priority: r['priority'] as int? ?? 2,
        assignedBrandIds: r['brand_ids'] != null
            ? List<int>.from(json.decode(r['brand_ids'] as String))
            : [],
        lastDetailedAt: r['last_detailed_at'] != null
            ? DateTime.tryParse(r['last_detailed_at'] as String)
            : null,
        totalSessions: r['total_sessions'] as int? ?? 0,
        isPlanned: (r['is_planned'] as int? ?? 0) == 1,
        birthday: r['birthday']?.toString(),
        anniversary: r['anniversary']?.toString(),
        nextCallDate: r['next_call_date'] != null
            ? DateTime.tryParse(r['next_call_date'] as String)
            : null,
        callFrequencyTarget: r['call_freq_target'] as int? ?? 2,
        latitude: (r['latitude'] as num?)?.toDouble(),
        longitude: (r['longitude'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'name': name,
        'speciality': speciality,
        'category': category,
        'territory': territory,
        'area': area,
        'mobile': mobile,
        'email': email,
        'hospital': hospital,
        'address': address,
        'priority': priority,
        'brand_ids': json.encode(assignedBrandIds),
        'last_detailed_at': lastDetailedAt?.toIso8601String(),
        'total_sessions': totalSessions,
        'is_planned': isPlanned ? 1 : 0,
        'birthday': birthday,
        'anniversary': anniversary,
        'next_call_date': nextCallDate?.toIso8601String(),
        'call_freq_target': callFrequencyTarget,
        'latitude': latitude,
        'longitude': longitude,
      };

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length > 1) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get daysSinceLabel {
    if (lastDetailedAt == null) return 'Never visited';
    final days = DateTime.now().difference(lastDetailedAt!).inDays;
    if (days == 0) return 'Visited today';
    if (days == 1) return 'Visited yesterday';
    return 'Visited $days days ago';
  }

  /// Returns true if birthday/anniversary is within [withinDays] days.
  bool hasBirthdaySoon({int withinDays = 7}) =>
      _isDateSoon(birthday, withinDays: withinDays);
  bool hasAnniversarySoon({int withinDays = 7}) =>
      _isDateSoon(anniversary, withinDays: withinDays);

  bool _isDateSoon(String? mmdd, {required int withinDays}) {
    if (mmdd == null || !mmdd.contains('-')) return false;
    final parts = mmdd.split('-');
    if (parts.length != 2) return false;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    if (month == null || day == null) return false;
    final now = DateTime.now();
    final thisYear = DateTime(now.year, month, day);
    final nextYear = DateTime(now.year + 1, month, day);
    final target = thisYear.isBefore(now) ? nextYear : thisYear;
    return target.difference(now).inDays <= withinDays;
  }

  String? get birthdayLabel {
    if (birthday == null) return null;
    return _formatMmDd(birthday!);
  }

  String? get anniversaryLabel {
    if (anniversary == null) return null;
    return _formatMmDd(anniversary!);
  }

  static String _formatMmDd(String mmdd) {
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final parts = mmdd.split('-');
    if (parts.length != 2) return mmdd;
    final m = int.tryParse(parts[0]) ?? 0;
    final d = int.tryParse(parts[1]) ?? 0;
    if (m < 1 || m > 12) return mmdd;
    return '${months[m]} $d';
  }

  static String _titleCase(String? s) {
    if (s == null || s.isEmpty) return '';
    return s.split(' ').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }
}

// ─── Brand ────────────────────────────────────────────────────────────────────

class ClmBrand {
  final int id;
  final String name;
  final String therapyArea;
  final String description;
  final String? thumbnailUrl;
  String? thumbnailLocalPath;
  final int slideCount;
  bool isDownloaded;
  double downloadProgress; // 0.0 – 1.0
  final int sortOrder;

  ClmBrand({
    required this.id,
    required this.name,
    required this.therapyArea,
    this.description = '',
    this.thumbnailUrl,
    this.thumbnailLocalPath,
    this.slideCount = 0,
    this.isDownloaded = false,
    this.downloadProgress = 0,
    this.sortOrder = 0,
  });

  factory ClmBrand.fromJson(Map<String, dynamic> j) => ClmBrand(
        id: (j['id'] as num).toInt(),
        name: j['name']?.toString() ?? '',
        therapyArea: j['therapy_area']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        thumbnailUrl: j['thumbnail_url']?.toString(),
        slideCount: (j['slide_count'] as num?)?.toInt() ?? 0,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );

  factory ClmBrand.fromDb(Map<String, dynamic> r) => ClmBrand(
        id: r['id'] as int,
        name: r['name'] as String,
        therapyArea: r['therapy_area']?.toString() ?? '',
        description: r['description']?.toString() ?? '',
        thumbnailUrl: r['thumbnail_url']?.toString(),
        thumbnailLocalPath: r['thumbnail_local_path']?.toString(),
        slideCount: r['slide_count'] as int? ?? 0,
        isDownloaded: (r['is_downloaded'] as int? ?? 0) == 1,
        downloadProgress:
            (r['download_progress'] as num?)?.toDouble() ?? 0.0,
        sortOrder: r['sort_order'] as int? ?? 0,
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'name': name,
        'therapy_area': therapyArea,
        'description': description,
        'thumbnail_url': thumbnailUrl,
        'thumbnail_local_path': thumbnailLocalPath,
        'slide_count': slideCount,
        'is_downloaded': isDownloaded ? 1 : 0,
        'download_progress': downloadProgress,
        'sort_order': sortOrder,
      };
}

// ─── Slide ────────────────────────────────────────────────────────────────────

class ClmSlide {
  final int id;
  final int brandId;
  final String type; // image | video | html
  final String title;
  final int sequence;
  final String? remoteUrl;
  String? localPath;
  final int durationSecs; // for video; 0 = no limit
  final String checksum;
  bool isDownloaded;
  bool isStarred;
  final int fileSize; // bytes

  ClmSlide({
    required this.id,
    required this.brandId,
    required this.type,
    required this.title,
    required this.sequence,
    this.remoteUrl,
    this.localPath,
    this.durationSecs = 0,
    this.checksum = '',
    this.isDownloaded = false,
    this.isStarred = false,
    this.fileSize = 0,
  });

  factory ClmSlide.fromJson(Map<String, dynamic> j) => ClmSlide(
        id: (j['id'] as num).toInt(),
        brandId: (j['brand_id'] as num).toInt(),
        type: j['type']?.toString() ?? 'image',
        title: j['title']?.toString() ?? '',
        sequence: (j['sequence'] as num?)?.toInt() ?? 0,
        remoteUrl: j['url']?.toString() ?? j['remote_url']?.toString(),
        durationSecs: (j['duration'] as num?)?.toInt() ?? 0,
        checksum: j['checksum']?.toString() ?? '',
        fileSize: (j['file_size'] as num?)?.toInt() ?? 0,
      );

  factory ClmSlide.fromDb(Map<String, dynamic> r) => ClmSlide(
        id: r['id'] as int,
        brandId: r['brand_id'] as int,
        type: r['type'] as String? ?? 'image',
        title: r['title'] as String? ?? '',
        sequence: r['sequence'] as int? ?? 0,
        remoteUrl: r['remote_url']?.toString(),
        localPath: r['local_path']?.toString(),
        durationSecs: r['duration_secs'] as int? ?? 0,
        checksum: r['checksum'] as String? ?? '',
        isDownloaded: (r['is_downloaded'] as int? ?? 0) == 1,
        fileSize: r['file_size'] as int? ?? 0,
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'brand_id': brandId,
        'type': type,
        'title': title,
        'sequence': sequence,
        'remote_url': remoteUrl,
        'local_path': localPath,
        'duration_secs': durationSecs,
        'checksum': checksum,
        'is_downloaded': isDownloaded ? 1 : 0,
        'file_size': fileSize,
      };

  bool get canPlay => isDownloaded && localPath != null;
}

// ─── Cart Item ────────────────────────────────────────────────────────────────

class ClmCartItem {
  final ClmBrand brand;
  final List<ClmSlide> slides;
  int cartSequence;
  bool isExpanded;

  ClmCartItem({
    required this.brand,
    required this.slides,
    required this.cartSequence,
    this.isExpanded = true,
  });

  List<ClmSlide> get sortedSlides =>
      List.from(slides)..sort((a, b) => a.sequence.compareTo(b.sequence));
}

// ─── Session ──────────────────────────────────────────────────────────────────

class ClmSession {
  final String id; // uuid
  final int doctorId;
  final String doctorName;
  final String mrEmployeeCode;
  final DateTime startTime;
  DateTime? endTime;
  final List<int> brandIds;
  bool isSynced;
  final String? latitude;
  final String? longitude;
  final String deviceInfo;

  ClmSession({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.mrEmployeeCode,
    required this.startTime,
    this.endTime,
    this.brandIds = const [],
    this.isSynced = false,
    this.latitude,
    this.longitude,
    this.deviceInfo = '',
  });

  int get durationSeconds =>
      (endTime ?? DateTime.now()).difference(startTime).inSeconds;

  String get durationLabel {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m}m ${s}s';
  }

  factory ClmSession.fromDb(Map<String, dynamic> r) => ClmSession(
        id: r['id'] as String,
        doctorId: r['doctor_id'] as int,
        doctorName: r['doctor_name'] as String? ?? '',
        mrEmployeeCode: r['mr_employee_code'] as String? ?? '',
        startTime: DateTime.parse(r['start_time'] as String),
        endTime: r['end_time'] != null
            ? DateTime.tryParse(r['end_time'] as String)
            : null,
        brandIds: r['brand_ids'] != null
            ? List<int>.from(json.decode(r['brand_ids'] as String))
            : [],
        isSynced: (r['is_synced'] as int? ?? 0) == 1,
        latitude: r['latitude']?.toString(),
        longitude: r['longitude']?.toString(),
        deviceInfo: r['device_info']?.toString() ?? '',
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'doctor_id': doctorId,
        'doctor_name': doctorName,
        'mr_employee_code': mrEmployeeCode,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'brand_ids': json.encode(brandIds),
        'is_synced': isSynced ? 1 : 0,
        'latitude': latitude,
        'longitude': longitude,
        'device_info': deviceInfo,
      };

  Map<String, dynamic> toSyncJson() => {
        'session_id': id,
        'doctor_id': doctorId,
        'mr_employee_code': mrEmployeeCode,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'brand_ids': brandIds,
        'latitude': latitude,
        'longitude': longitude,
        'device_info': deviceInfo,
      };
}

// ─── Call Report ──────────────────────────────────────────────────────────────

enum DoctorReaction { positive, neutral, receptive, objection, notAvailable }

extension DoctorReactionX on DoctorReaction {
  String get key {
    switch (this) {
      case DoctorReaction.positive: return 'positive';
      case DoctorReaction.neutral: return 'neutral';
      case DoctorReaction.receptive: return 'receptive';
      case DoctorReaction.objection: return 'objection';
      case DoctorReaction.notAvailable: return 'not_available';
    }
  }

  String get label {
    switch (this) {
      case DoctorReaction.positive: return 'Positive';
      case DoctorReaction.neutral: return 'Neutral';
      case DoctorReaction.receptive: return 'Receptive';
      case DoctorReaction.objection: return 'Objection';
      case DoctorReaction.notAvailable: return 'Not Available';
    }
  }

  String get emoji {
    switch (this) {
      case DoctorReaction.positive: return '😊';
      case DoctorReaction.neutral: return '😐';
      case DoctorReaction.receptive: return '🤔';
      case DoctorReaction.objection: return '❌';
      case DoctorReaction.notAvailable: return '🚫';
    }
  }

  static DoctorReaction fromKey(String key) {
    switch (key) {
      case 'positive': return DoctorReaction.positive;
      case 'receptive': return DoctorReaction.receptive;
      case 'objection': return DoctorReaction.objection;
      case 'not_available': return DoctorReaction.notAvailable;
      default: return DoctorReaction.neutral;
    }
  }
}

class ClmCallReport {
  final String id;
  final String sessionId;
  final int doctorId;
  final DateTime createdAt;
  final List<int> brandsDiscussed;
  final DoctorReaction reaction;
  final String callNotes;
  final List<String> topicsDiscussed;
  final List<String> keyMessagesDelivered;
  final String nextCallPlan;
  final DateTime? nextCallDate;
  final int samplesGiven;
  final String competitorMentions;
  final String? voiceNotePath;
  final String? voiceNoteTranscript;
  bool isSynced;

  ClmCallReport({
    required this.id,
    required this.sessionId,
    required this.doctorId,
    required this.createdAt,
    this.brandsDiscussed = const [],
    this.reaction = DoctorReaction.neutral,
    this.callNotes = '',
    this.topicsDiscussed = const [],
    this.keyMessagesDelivered = const [],
    this.nextCallPlan = '',
    this.nextCallDate,
    this.samplesGiven = 0,
    this.competitorMentions = '',
    this.voiceNotePath,
    this.voiceNoteTranscript,
    this.isSynced = false,
  });

  factory ClmCallReport.fromDb(Map<String, dynamic> r) => ClmCallReport(
        id: r['id'] as String,
        sessionId: r['session_id'] as String,
        doctorId: r['doctor_id'] as int,
        createdAt: DateTime.parse(r['created_at'] as String),
        brandsDiscussed: r['brands_discussed'] != null
            ? List<int>.from(json.decode(r['brands_discussed'] as String))
            : [],
        reaction: DoctorReactionX.fromKey(r['reaction']?.toString() ?? 'neutral'),
        callNotes: r['call_notes']?.toString() ?? '',
        topicsDiscussed: r['topics_discussed'] != null
            ? List<String>.from(json.decode(r['topics_discussed'] as String))
            : [],
        keyMessagesDelivered: r['key_messages'] != null
            ? List<String>.from(json.decode(r['key_messages'] as String))
            : [],
        nextCallPlan: r['next_call_plan']?.toString() ?? '',
        nextCallDate: r['next_call_date'] != null
            ? DateTime.tryParse(r['next_call_date'] as String)
            : null,
        samplesGiven: r['samples_given'] as int? ?? 0,
        competitorMentions: r['competitor_mentions']?.toString() ?? '',
        voiceNotePath: r['voice_note_path']?.toString(),
        voiceNoteTranscript: r['voice_note_transcript']?.toString(),
        isSynced: (r['is_synced'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'session_id': sessionId,
        'doctor_id': doctorId,
        'created_at': createdAt.toIso8601String(),
        'brands_discussed': json.encode(brandsDiscussed),
        'reaction': reaction.key,
        'call_notes': callNotes,
        'topics_discussed': json.encode(topicsDiscussed),
        'key_messages': json.encode(keyMessagesDelivered),
        'next_call_plan': nextCallPlan,
        'next_call_date': nextCallDate?.toIso8601String(),
        'samples_given': samplesGiven,
        'competitor_mentions': competitorMentions,
        'voice_note_path': voiceNotePath,
        'voice_note_transcript': voiceNoteTranscript,
        'is_synced': isSynced ? 1 : 0,
      };

  Map<String, dynamic> toSyncJson() => {
        'id': id,
        'session_id': sessionId,
        'doctor_id': doctorId,
        'created_at': createdAt.toIso8601String(),
        'brands_discussed': brandsDiscussed,
        'reaction': reaction.key,
        'call_notes': callNotes,
        'topics_discussed': topicsDiscussed,
        'key_messages': keyMessagesDelivered,
        'next_call_date': nextCallDate?.toIso8601String(),
        'samples_given': samplesGiven,
        'competitor_mentions': competitorMentions,
      };
}

// ─── Visit Summary (read-model) ───────────────────────────────────────────────

class ClmVisitSummary {
  final String sessionId;
  final DateTime visitDate;
  final int durationMinutes;
  final List<String> brandNames;
  final DoctorReaction? reaction;
  final String? callNotes;
  final List<String> topicsDiscussed;
  final int slidesShown;

  const ClmVisitSummary({
    required this.sessionId,
    required this.visitDate,
    required this.durationMinutes,
    this.brandNames = const [],
    this.reaction,
    this.callNotes,
    this.topicsDiscussed = const [],
    this.slidesShown = 0,
  });
}

// ─── AI Insight Models ───────────────────────────────────────────────────────

enum AiHighlightType {
  birthday,
  anniversary,
  lastReaction,
  lastTopic,
  objection,
  productAffinity,
  overdueVisit,
  competitor,
  callFrequency,
}

class AiKeyHighlight {
  final AiHighlightType type;
  final String label;
  final String detail;
  final String emoji;

  const AiKeyHighlight({
    required this.type,
    required this.label,
    required this.detail,
    required this.emoji,
  });
}

class AiBrandRec {
  final ClmBrand brand;
  final int score; // 0–100
  final String reason;
  final List<ClmSlide> slides;
  bool isSelected;

  AiBrandRec({
    required this.brand,
    required this.score,
    required this.reason,
    required this.slides,
    this.isSelected = true,
  });
}

class AiDoctorInsight {
  final ClmDoctor doctor;
  final int engagementScore;
  final String engagementLevel; // High | Medium | Low | At Risk
  final String preCallSummary;
  final List<AiKeyHighlight> highlights;
  final List<AiBrandRec> brandRecs;
  final List<String> scriptTips;

  AiDoctorInsight({
    required this.doctor,
    required this.engagementScore,
    required this.engagementLevel,
    required this.preCallSummary,
    required this.highlights,
    required this.brandRecs,
    required this.scriptTips,
  });
}

// ─── Analytics Event ──────────────────────────────────────────────────────────

class ClmAnalyticsEvent {
  final int? dbId;
  final String sessionId;
  final int slideId;
  final int brandId;
  final String eventType; // view_start | view_end | tap | complete | skip | star | share
  final DateTime timestamp;
  final int durationSecs;
  bool isSynced;

  ClmAnalyticsEvent({
    this.dbId,
    required this.sessionId,
    required this.slideId,
    required this.brandId,
    required this.eventType,
    required this.timestamp,
    this.durationSecs = 0,
    this.isSynced = false,
  });

  factory ClmAnalyticsEvent.fromDb(Map<String, dynamic> r) =>
      ClmAnalyticsEvent(
        dbId: r['id'] as int?,
        sessionId: r['session_id'] as String,
        slideId: r['slide_id'] as int,
        brandId: r['brand_id'] as int,
        eventType: r['event_type'] as String,
        timestamp: DateTime.parse(r['timestamp'] as String),
        durationSecs: r['duration_secs'] as int? ?? 0,
        isSynced: (r['is_synced'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toDb() => {
        if (dbId != null) 'id': dbId,
        'session_id': sessionId,
        'slide_id': slideId,
        'brand_id': brandId,
        'event_type': eventType,
        'timestamp': timestamp.toIso8601String(),
        'duration_secs': durationSecs,
        'is_synced': isSynced ? 1 : 0,
      };

  Map<String, dynamic> toSyncJson() => {
        'session_id': sessionId,
        'slide_id': slideId,
        'brand_id': brandId,
        'event_type': eventType,
        'timestamp': timestamp.toIso8601String(),
        'duration_secs': durationSecs,
      };
}

// ─── Sync Status ──────────────────────────────────────────────────────────────

enum SyncState { idle, syncing, success, error }

class ClmSyncStatus {
  final SyncState state;
  final String message;
  final double progress; // 0.0 – 1.0
  final DateTime? lastSyncAt;
  final int pendingUploads;

  const ClmSyncStatus({
    this.state = SyncState.idle,
    this.message = '',
    this.progress = 0,
    this.lastSyncAt,
    this.pendingUploads = 0,
  });

  ClmSyncStatus copyWith({
    SyncState? state,
    String? message,
    double? progress,
    DateTime? lastSyncAt,
    int? pendingUploads,
  }) =>
      ClmSyncStatus(
        state: state ?? this.state,
        message: message ?? this.message,
        progress: progress ?? this.progress,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        pendingUploads: pendingUploads ?? this.pendingUploads,
      );
}

// ─── Doctor Location ──────────────────────────────────────────────────────────

class DoctorLocation {
  final int? id;
  final int doctorId;
  final String label;
  final double latitude;
  final double longitude;
  final DateTime capturedAt;

  DoctorLocation({
    this.id,
    required this.doctorId,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
  });

  factory DoctorLocation.fromDb(Map<String, dynamic> r) => DoctorLocation(
        id: r['id'] as int?,
        doctorId: r['doctor_id'] as int,
        label: r['label'] as String? ?? 'Location',
        latitude: (r['latitude'] as num).toDouble(),
        longitude: (r['longitude'] as num).toDouble(),
        capturedAt: DateTime.parse(r['captured_at'] as String),
      );

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'doctor_id': doctorId,
        'label': label,
        'latitude': latitude,
        'longitude': longitude,
        'captured_at': capturedAt.toIso8601String(),
      };

  DoctorLocation copyWith({String? label}) => DoctorLocation(
        id: id,
        doctorId: doctorId,
        label: label ?? this.label,
        latitude: latitude,
        longitude: longitude,
        capturedAt: capturedAt,
      );
}

// ─── Doctor Stats ─────────────────────────────────────────────────────────────

class ClmDoctorStats {
  final int doctorId;
  final int totalSessions;
  final int totalMinutes;
  final Map<int, int> brandSecondsMap; // brandId → total seconds
  final DateTime? lastSession;

  const ClmDoctorStats({
    required this.doctorId,
    this.totalSessions = 0,
    this.totalMinutes = 0,
    this.brandSecondsMap = const {},
    this.lastSession,
  });
}
