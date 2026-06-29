import 'dart:convert';
import 'package:flutter/material.dart';

// ─── Metric ───────────────────────────────────────────────────────────────────

class AiHubMetric {
  final String key;
  final String label;
  final String value;
  final String? unit;
  final String? trend;
  final String? trendValue;

  const AiHubMetric({
    required this.key,
    required this.label,
    required this.value,
    this.unit,
    this.trend,
    this.trendValue,
  });

  factory AiHubMetric.fromJson(String key, Map<String, dynamic> j) =>
      AiHubMetric(
        key:        key,
        label:      j['label']?.toString() ?? '',
        value:      j['value']?.toString() ?? '0',
        unit:       j['unit']?.toString(),
        trend:      j['trend']?.toString(),
        trendValue: j['trend_value']?.toString(),
      );

  String get displayValue => unit != null ? '$value$unit' : value;

  bool get trendUp   => trend == 'up';
  bool get trendDown => trend == 'down';
}

// ─── Insight ──────────────────────────────────────────────────────────────────

class AiHubInsight {
  final int id;
  final String module;
  final String tag;
  final String text;
  final String iconKey;
  final String colorHex;
  final int priority;

  const AiHubInsight({
    required this.id,
    required this.module,
    required this.tag,
    required this.text,
    required this.iconKey,
    required this.colorHex,
    required this.priority,
  });

  factory AiHubInsight.fromJson(Map<String, dynamic> j) => AiHubInsight(
        id:       int.tryParse(j['id'].toString()) ?? 0,
        module:   j['module']?.toString() ?? '',
        tag:      j['tag']?.toString() ?? '',
        text:     j['text']?.toString() ?? '',
        iconKey:  j['icon_key']?.toString() ?? 'auto_awesome',
        colorHex: j['color_hex']?.toString() ?? '#1565C0',
        priority: int.tryParse(j['priority']?.toString() ?? '5') ?? 5,
      );

  factory AiHubInsight.fromDb(Map<String, dynamic> r) => AiHubInsight(
        id:       r['id'] as int? ?? 0,
        module:   r['module']?.toString() ?? '',
        tag:      r['tag']?.toString() ?? '',
        text:     r['text']?.toString() ?? '',
        iconKey:  r['icon_key']?.toString() ?? 'auto_awesome',
        colorHex: r['color_hex']?.toString() ?? '#1565C0',
        priority: r['priority'] as int? ?? 5,
      );

  Map<String, dynamic> toDb() => {
        'id':       id,
        'module':   module,
        'tag':      tag,
        'text':     text,
        'icon_key': iconKey,
        'color_hex': colorHex,
        'priority': priority,
      };

  Color get color {
    try {
      return Color(int.parse('0xFF${colorHex.replaceFirst('#', '')}'));
    } catch (_) {
      return const Color(0xFF1565C0);
    }
  }

  IconData get icon {
    switch (iconKey) {
      case 'trending_up':    return Icons.trending_up;
      case 'warning_amber':  return Icons.warning_amber;
      case 'warning':        return Icons.warning;
      case 'article':        return Icons.article_outlined;
      case 'emoji_events':   return Icons.emoji_events_outlined;
      case 'auto_awesome':   return Icons.auto_awesome;
      case 'thumb_up':       return Icons.thumb_up_outlined;
      case 'school':         return Icons.school_outlined;
      default:               return Icons.auto_awesome;
    }
  }
}

// ─── Doctor Score ─────────────────────────────────────────────────────────────

class AiDoctorScore {
  final int doctorId;
  final String doctorName;
  final String speciality;
  final int engagementScore;
  final String engagementLevel;
  final String engagementColorHex;
  final int conversionScore;
  final String conversionLevel;
  final String? conversionProduct;
  final int daysSinceVisit;
  final bool isFlagged;
  final String? flagReason;

  const AiDoctorScore({
    required this.doctorId,
    required this.doctorName,
    required this.speciality,
    required this.engagementScore,
    required this.engagementLevel,
    required this.engagementColorHex,
    required this.conversionScore,
    required this.conversionLevel,
    this.conversionProduct,
    this.daysSinceVisit = 0,
    this.isFlagged = false,
    this.flagReason,
  });

  factory AiDoctorScore.fromJson(Map<String, dynamic> j) => AiDoctorScore(
        doctorId:            int.tryParse(j['doctor_id'].toString()) ?? 0,
        doctorName:          j['doctor_name']?.toString() ?? '',
        speciality:          j['speciality']?.toString() ?? '',
        engagementScore:     int.tryParse(j['engagement_score']?.toString() ?? '0') ?? 0,
        engagementLevel:     j['engagement_level']?.toString() ?? 'Medium',
        engagementColorHex:  j['engagement_color_hex']?.toString() ?? '#E65100',
        conversionScore:     int.tryParse(j['conversion_score']?.toString() ?? '0') ?? 0,
        conversionLevel:     j['conversion_level']?.toString() ?? 'Medium',
        conversionProduct:   j['conversion_product']?.toString(),
        daysSinceVisit:      int.tryParse(j['days_since_visit']?.toString() ?? '0') ?? 0,
        isFlagged:           j['is_flagged'] == true || j['is_flagged'] == 1,
        flagReason:          j['flag_reason']?.toString(),
      );

  factory AiDoctorScore.fromDb(Map<String, dynamic> r) => AiDoctorScore(
        doctorId:            r['doctor_id'] as int? ?? 0,
        doctorName:          r['doctor_name']?.toString() ?? '',
        speciality:          r['speciality']?.toString() ?? '',
        engagementScore:     r['engagement_score'] as int? ?? 0,
        engagementLevel:     r['engagement_level']?.toString() ?? 'Medium',
        engagementColorHex:  r['engagement_color_hex']?.toString() ?? '#E65100',
        conversionScore:     r['conversion_score'] as int? ?? 0,
        conversionLevel:     r['conversion_level']?.toString() ?? 'Medium',
        conversionProduct:   r['conversion_product']?.toString(),
        daysSinceVisit:      r['days_since_visit'] as int? ?? 0,
        isFlagged:           (r['is_flagged'] as int? ?? 0) == 1,
        flagReason:          r['flag_reason']?.toString(),
      );

  Map<String, dynamic> toDb() => {
        'doctor_id':            doctorId,
        'doctor_name':          doctorName,
        'speciality':           speciality,
        'engagement_score':     engagementScore,
        'engagement_level':     engagementLevel,
        'engagement_color_hex': engagementColorHex,
        'conversion_score':     conversionScore,
        'conversion_level':     conversionLevel,
        'conversion_product':   conversionProduct,
        'days_since_visit':     daysSinceVisit,
        'is_flagged':           isFlagged ? 1 : 0,
        'flag_reason':          flagReason,
      };

  Color get engagementColor {
    try {
      return Color(int.parse('0xFF${engagementColorHex.replaceFirst('#', '')}'));
    } catch (_) {
      return const Color(0xFFE65100);
    }
  }

  String get initials {
    final parts = doctorName.replaceAll('Dr.', '').trim().split(' ');
    return parts.where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join();
  }
}

// ─── Playbook ─────────────────────────────────────────────────────────────────

class AiPlaybook {
  final int id;
  final int doctorId;
  final String doctorName;
  final String brandName;
  final String strategy;
  final List<String> topics;
  final String priority;

  const AiPlaybook({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.brandName,
    required this.strategy,
    required this.topics,
    required this.priority,
  });

  factory AiPlaybook.fromJson(Map<String, dynamic> j) => AiPlaybook(
        id:         int.tryParse(j['id'].toString()) ?? 0,
        doctorId:   int.tryParse(j['doctor_id'].toString()) ?? 0,
        doctorName: j['doctor_name']?.toString() ?? '',
        brandName:  j['brand_name']?.toString() ?? '',
        strategy:   j['strategy']?.toString() ?? '',
        topics:     (j['topics'] is List)
            ? List<String>.from(j['topics'])
            : List<String>.from(json.decode(j['topics']?.toString() ?? '[]')),
        priority:   j['priority']?.toString() ?? 'normal',
      );

  factory AiPlaybook.fromDb(Map<String, dynamic> r) => AiPlaybook(
        id:         r['id'] as int? ?? 0,
        doctorId:   r['doctor_id'] as int? ?? 0,
        doctorName: r['doctor_name']?.toString() ?? '',
        brandName:  r['brand_name']?.toString() ?? '',
        strategy:   r['strategy']?.toString() ?? '',
        topics:     r['topics'] != null
            ? List<String>.from(json.decode(r['topics'] as String))
            : [],
        priority:   r['priority']?.toString() ?? 'normal',
      );

  Map<String, dynamic> toDb() => {
        'id':          id,
        'doctor_id':   doctorId,
        'doctor_name': doctorName,
        'brand_name':  brandName,
        'strategy':    strategy,
        'topics':      json.encode(topics),
        'priority':    priority,
      };
}

// ─── Scheduling ───────────────────────────────────────────────────────────────

class AiSchedule {
  final int doctorId;
  final String doctorName;
  final String suggestedDay;
  final String reason;
  final String iconKey;
  final String colorHex;

  const AiSchedule({
    required this.doctorId,
    required this.doctorName,
    required this.suggestedDay,
    required this.reason,
    required this.iconKey,
    required this.colorHex,
  });

  factory AiSchedule.fromJson(Map<String, dynamic> j) => AiSchedule(
        doctorId:     int.tryParse(j['doctor_id'].toString()) ?? 0,
        doctorName:   j['doctor_name']?.toString() ?? '',
        suggestedDay: j['suggested_day']?.toString() ?? '',
        reason:       j['reason']?.toString() ?? '',
        iconKey:      j['icon_key']?.toString() ?? 'schedule',
        colorHex:     j['color_hex']?.toString() ?? '#1565C0',
      );

  factory AiSchedule.fromDb(Map<String, dynamic> r) => AiSchedule(
        doctorId:     r['doctor_id'] as int? ?? 0,
        doctorName:   r['doctor_name']?.toString() ?? '',
        suggestedDay: r['suggested_day']?.toString() ?? '',
        reason:       r['reason']?.toString() ?? '',
        iconKey:      r['icon_key']?.toString() ?? 'schedule',
        colorHex:     r['color_hex']?.toString() ?? '#1565C0',
      );

  Map<String, dynamic> toDb() => {
        'doctor_id':    doctorId,
        'doctor_name':  doctorName,
        'suggested_day': suggestedDay,
        'reason':       reason,
        'icon_key':     iconKey,
        'color_hex':    colorHex,
      };

  Color get color {
    try {
      return Color(int.parse('0xFF${colorHex.replaceFirst('#', '')}'));
    } catch (_) {
      return const Color(0xFF1565C0);
    }
  }

  IconData get icon {
    switch (iconKey) {
      case 'star':          return Icons.star_rounded;
      case 'schedule':      return Icons.schedule;
      case 'event':         return Icons.event;
      case 'check_circle':  return Icons.check_circle;
      case 'warning':       return Icons.warning_amber;
      default:              return Icons.schedule;
    }
  }
}

// ─── Product Performance ──────────────────────────────────────────────────────

class AiProductPerformance {
  final int id;
  final String productName;
  final String therapyArea;
  final String targetSpecialities;
  final int fitScore;
  final String growthValue;
  final bool growthPositive;
  final int totalVisits;
  final int totalConversions;
  final String? topRegion;
  final List<Map<String, dynamic>> monthlyTrend;

  const AiProductPerformance({
    required this.id,
    required this.productName,
    required this.therapyArea,
    required this.targetSpecialities,
    required this.fitScore,
    required this.growthValue,
    required this.growthPositive,
    required this.totalVisits,
    required this.totalConversions,
    this.topRegion,
    this.monthlyTrend = const [],
  });

  factory AiProductPerformance.fromJson(Map<String, dynamic> j) =>
      AiProductPerformance(
        id:                  int.tryParse(j['id'].toString()) ?? 0,
        productName:         j['product_name']?.toString() ?? '',
        therapyArea:         j['therapy_area']?.toString() ?? '',
        targetSpecialities:  j['target_specialities']?.toString() ?? '',
        fitScore:            int.tryParse(j['fit_score']?.toString() ?? '0') ?? 0,
        growthValue:         j['growth_value']?.toString() ?? '0%',
        growthPositive:      j['growth_positive'] == true || j['growth_positive'] == 1,
        totalVisits:         int.tryParse(j['total_visits']?.toString() ?? '0') ?? 0,
        totalConversions:    int.tryParse(j['total_conversions']?.toString() ?? '0') ?? 0,
        topRegion:           j['top_region']?.toString(),
        monthlyTrend:        (j['monthly_trend'] is List)
            ? List<Map<String, dynamic>>.from(j['monthly_trend'])
            : [],
      );

  factory AiProductPerformance.fromDb(Map<String, dynamic> r) =>
      AiProductPerformance(
        id:                  r['id'] as int? ?? 0,
        productName:         r['product_name']?.toString() ?? '',
        therapyArea:         r['therapy_area']?.toString() ?? '',
        targetSpecialities:  r['target_specialities']?.toString() ?? '',
        fitScore:            r['fit_score'] as int? ?? 0,
        growthValue:         r['growth_value']?.toString() ?? '0%',
        growthPositive:      (r['growth_positive'] as int? ?? 0) == 1,
        totalVisits:         r['total_visits'] as int? ?? 0,
        totalConversions:    r['total_conversions'] as int? ?? 0,
        topRegion:           r['top_region']?.toString(),
        monthlyTrend:        r['monthly_trend'] != null
            ? List<Map<String, dynamic>>.from(
                json.decode(r['monthly_trend'] as String))
            : [],
      );

  Map<String, dynamic> toDb() => {
        'id':                 id,
        'product_name':       productName,
        'therapy_area':       therapyArea,
        'target_specialities': targetSpecialities,
        'fit_score':          fitScore,
        'growth_value':       growthValue,
        'growth_positive':    growthPositive ? 1 : 0,
        'total_visits':       totalVisits,
        'total_conversions':  totalConversions,
        'top_region':         topRegion,
        'monthly_trend':      json.encode(monthlyTrend),
      };

  int get conversionRate => totalVisits > 0
      ? ((totalConversions / totalVisits) * 100).round()
      : 0;

  Color get scoreColor {
    if (fitScore >= 80) return const Color(0xFF1B5E20);
    if (fitScore >= 65) return const Color(0xFFE65100);
    return const Color(0xFFB71C1C);
  }
}

// ─── Doctor Segment ───────────────────────────────────────────────────────────

class AiDoctorSegment {
  final String speciality;
  final int doctorCount;
  final String topProduct;
  final String colorHex;

  const AiDoctorSegment({
    required this.speciality,
    required this.doctorCount,
    required this.topProduct,
    required this.colorHex,
  });

  factory AiDoctorSegment.fromJson(Map<String, dynamic> j) => AiDoctorSegment(
        speciality:   j['speciality']?.toString() ?? '',
        doctorCount:  int.tryParse(j['doctor_count']?.toString() ?? '0') ?? 0,
        topProduct:   j['top_product']?.toString() ?? '',
        colorHex:     j['color_hex']?.toString() ?? '#1565C0',
      );

  factory AiDoctorSegment.fromDb(Map<String, dynamic> r) => AiDoctorSegment(
        speciality:  r['speciality']?.toString() ?? '',
        doctorCount: r['doctor_count'] as int? ?? 0,
        topProduct:  r['top_product']?.toString() ?? '',
        colorHex:    r['color_hex']?.toString() ?? '#1565C0',
      );

  Map<String, dynamic> toDb() => {
        'speciality':   speciality,
        'doctor_count': doctorCount,
        'top_product':  topProduct,
        'color_hex':    colorHex,
      };

  Color get color {
    try {
      return Color(int.parse('0xFF${colorHex.replaceFirst('#', '')}'));
    } catch (_) {
      return const Color(0xFF1565C0);
    }
  }
}

// ─── Employee Performance ─────────────────────────────────────────────────────

class AiEmployeePerformance {
  final int id;
  final String employeeCode;
  final String employeeName;
  final String region;
  final int performanceScore;
  final String targetAchievement;
  final bool targetMet;
  final int totalVisits;
  final int totalSessions;
  final String rankLabel;
  final String rankColorHex;
  final bool coachingFlag;

  const AiEmployeePerformance({
    required this.id,
    required this.employeeCode,
    required this.employeeName,
    required this.region,
    required this.performanceScore,
    required this.targetAchievement,
    required this.targetMet,
    required this.totalVisits,
    required this.totalSessions,
    required this.rankLabel,
    required this.rankColorHex,
    required this.coachingFlag,
  });

  factory AiEmployeePerformance.fromJson(Map<String, dynamic> j) =>
      AiEmployeePerformance(
        id:                 int.tryParse(j['id'].toString()) ?? 0,
        employeeCode:       j['employee_code']?.toString() ?? '',
        employeeName:       j['employee_name']?.toString() ?? '',
        region:             j['region']?.toString() ?? '',
        performanceScore:   int.tryParse(j['performance_score']?.toString() ?? '0') ?? 0,
        targetAchievement:  j['target_achievement']?.toString() ?? '0%',
        targetMet:          j['target_met'] == true || j['target_met'] == 1,
        totalVisits:        int.tryParse(j['total_visits']?.toString() ?? '0') ?? 0,
        totalSessions:      int.tryParse(j['total_sessions']?.toString() ?? '0') ?? 0,
        rankLabel:          j['rank_label']?.toString() ?? 'On Track',
        rankColorHex:       j['rank_color_hex']?.toString() ?? '#E65100',
        coachingFlag:       j['coaching_flag'] == true || j['coaching_flag'] == 1,
      );

  factory AiEmployeePerformance.fromDb(Map<String, dynamic> r) =>
      AiEmployeePerformance(
        id:                 r['id'] as int? ?? 0,
        employeeCode:       r['employee_code']?.toString() ?? '',
        employeeName:       r['employee_name']?.toString() ?? '',
        region:             r['region']?.toString() ?? '',
        performanceScore:   r['performance_score'] as int? ?? 0,
        targetAchievement:  r['target_achievement']?.toString() ?? '0%',
        targetMet:          (r['target_met'] as int? ?? 0) == 1,
        totalVisits:        r['total_visits'] as int? ?? 0,
        totalSessions:      r['total_sessions'] as int? ?? 0,
        rankLabel:          r['rank_label']?.toString() ?? 'On Track',
        rankColorHex:       r['rank_color_hex']?.toString() ?? '#E65100',
        coachingFlag:       (r['coaching_flag'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toDb() => {
        'id':                  id,
        'employee_code':       employeeCode,
        'employee_name':       employeeName,
        'region':              region,
        'performance_score':   performanceScore,
        'target_achievement':  targetAchievement,
        'target_met':          targetMet ? 1 : 0,
        'total_visits':        totalVisits,
        'total_sessions':      totalSessions,
        'rank_label':          rankLabel,
        'rank_color_hex':      rankColorHex,
        'coaching_flag':       coachingFlag ? 1 : 0,
      };

  Color get rankColor {
    try {
      return Color(int.parse('0xFF${rankColorHex.replaceFirst('#', '')}'));
    } catch (_) {
      return const Color(0xFFE65100);
    }
  }

  String get initials => employeeName.trim().split(' ')
      .where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join();
}

// ─── Sales Assistant Data Bundle ──────────────────────────────────────────────

class AiSalesAssistantData {
  final List<AiDoctorScore> doctorScores;
  final List<AiPlaybook> playbooks;
  final List<AiSchedule> scheduling;
  final List<AiDoctorSegment> segments;
  final List<AiProductPerformance> productFit;
  final AiHubInsight? observation;

  const AiSalesAssistantData({
    this.doctorScores  = const [],
    this.playbooks     = const [],
    this.scheduling    = const [],
    this.segments      = const [],
    this.productFit    = const [],
    this.observation,
  });
}

// ─── Product Performance Data Bundle ─────────────────────────────────────────

class AiProductData {
  final List<AiProductPerformance> products;
  final int totalVisits;
  final int totalConversions;
  final double conversionRate;
  final String? topProduct;
  final AiHubInsight? observation;

  const AiProductData({
    this.products        = const [],
    this.totalVisits     = 0,
    this.totalConversions= 0,
    this.conversionRate  = 0,
    this.topProduct,
    this.observation,
  });
}

// ─── Doctor Review Data Bundle ────────────────────────────────────────────────

class AiDoctorReviewData {
  final List<AiDoctorScore> doctors;
  final int flaggedCount;
  final int highCount;
  final int atRiskCount;
  final double avgEngagement;
  final AiHubInsight? observation;

  const AiDoctorReviewData({
    this.doctors       = const [],
    this.flaggedCount  = 0,
    this.highCount     = 0,
    this.atRiskCount   = 0,
    this.avgEngagement = 0,
    this.observation,
  });
}

// ─── Employee Data Bundle ─────────────────────────────────────────────────────

class AiEmployeeData {
  final List<AiEmployeePerformance> employees;
  final int coachingNeeded;
  final int topPerformers;
  final double avgScore;
  final int targetMet;
  final int total;
  final List<Map<String, dynamic>> regions;
  final AiHubInsight? observation;

  const AiEmployeeData({
    this.employees      = const [],
    this.coachingNeeded = 0,
    this.topPerformers  = 0,
    this.avgScore       = 0,
    this.targetMet      = 0,
    this.total          = 0,
    this.regions        = const [],
    this.observation,
  });
}
