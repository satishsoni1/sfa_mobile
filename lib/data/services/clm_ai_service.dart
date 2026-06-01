import '../models/clm_models.dart';

/// Deterministic local AI engine for pre-call doctor analysis.
/// No network calls – runs entirely from local SQLite data.
class ClmAiService {
  static ClmAiService? _instance;
  ClmAiService._();
  factory ClmAiService() => _instance ??= ClmAiService._();

  // ─── Public Entry Point ───────────────────────────────────────────────────

  AiDoctorInsight analyze({
    required ClmDoctor doctor,
    required List<ClmVisitSummary> history,
    required List<ClmCallReport> reports,
    required List<ClmBrand> brands,
    required Map<int, List<ClmSlide>> slidesPerBrand,
  }) {
    final score = _engagementScore(doctor, history, reports);
    final level = _engagementLevel(score);
    final highlights = _buildHighlights(doctor, history, reports);
    final recs = _rankBrands(doctor, history, reports, brands, slidesPerBrand);
    final tips = _buildScriptTips(doctor, highlights, recs);
    final summary = _buildSummary(doctor, score, level, history, recs);

    return AiDoctorInsight(
      doctor: doctor,
      engagementScore: score,
      engagementLevel: level,
      preCallSummary: summary,
      highlights: highlights,
      brandRecs: recs,
      scriptTips: tips,
    );
  }

  // ─── Engagement Score ─────────────────────────────────────────────────────

  int _engagementScore(
    ClmDoctor doctor,
    List<ClmVisitSummary> history,
    List<ClmCallReport> reports,
  ) {
    int score = 45;

    // Recency bonus (0–30)
    if (doctor.lastDetailedAt != null) {
      final days = DateTime.now().difference(doctor.lastDetailedAt!).inDays;
      if (days <= 7) score += 30;
      else if (days <= 14) score += 20;
      else if (days <= 30) score += 10;
      else if (days <= 60) score -= 5;
      else score -= 15;
    } else {
      score -= 20;
    }

    // Session frequency bonus (up to +15)
    final sessions = history.length;
    score += (sessions * 3).clamp(0, 15);

    // Last reaction bonus
    if (reports.isNotEmpty) {
      final last = reports.first;
      switch (last.reaction) {
        case DoctorReaction.positive:
          score += 20;
          break;
        case DoctorReaction.receptive:
          score += 12;
          break;
        case DoctorReaction.neutral:
          score += 3;
          break;
        case DoctorReaction.objection:
          score -= 8;
          break;
        case DoctorReaction.notAvailable:
          score -= 12;
          break;
      }
    }

    // Category bonus
    switch (doctor.category.toUpperCase()) {
      case 'A':
        score += 8;
        break;
      case 'B':
        break;
      default:
        score -= 5;
    }

    // Priority bonus
    if (doctor.priority == 1) score += 5;

    return score.clamp(0, 100);
  }

  String _engagementLevel(int score) {
    if (score >= 80) return 'High';
    if (score >= 60) return 'Medium';
    if (score >= 40) return 'Low';
    return 'At Risk';
  }

  // ─── Key Highlights ───────────────────────────────────────────────────────

  List<AiKeyHighlight> _buildHighlights(
    ClmDoctor doctor,
    List<ClmVisitSummary> history,
    List<ClmCallReport> reports,
  ) {
    final highlights = <AiKeyHighlight>[];

    // Birthday
    if (doctor.birthday != null && doctor.hasBirthdaySoon(withinDays: 14)) {
      final days = _daysUntilMmDd(doctor.birthday!);
      highlights.add(AiKeyHighlight(
        type: AiHighlightType.birthday,
        label: days == 0
            ? 'Birthday Today!'
            : days == 1
                ? 'Birthday Tomorrow'
                : 'Birthday in ${days}d',
        detail: 'Use as a relationship touchpoint. Wish personally.',
        emoji: '🎂',
      ));
    }

    // Anniversary
    if (doctor.anniversary != null && doctor.hasAnniversarySoon(withinDays: 14)) {
      final days = _daysUntilMmDd(doctor.anniversary!);
      highlights.add(AiKeyHighlight(
        type: AiHighlightType.anniversary,
        label: days == 0
            ? 'Anniversary Today!'
            : days == 1
                ? 'Anniversary Tomorrow'
                : 'Anniversary in ${days}d',
        detail: 'Personal milestone – great conversation opener.',
        emoji: '💍',
      ));
    }

    // Last reaction
    if (reports.isNotEmpty) {
      final last = reports.first;
      highlights.add(AiKeyHighlight(
        type: AiHighlightType.lastReaction,
        label: 'Last: ${last.reaction.label}',
        detail: last.callNotes.isNotEmpty
            ? last.callNotes
            : 'Reaction from ${_daysAgo(last.createdAt)} days ago.',
        emoji: last.reaction.emoji,
      ));
    }

    // Last topics (up to 2)
    if (history.isNotEmpty) {
      for (final topic in history.first.topicsDiscussed.take(2)) {
        highlights.add(AiKeyHighlight(
          type: AiHighlightType.lastTopic,
          label: topic,
          detail: 'Discussed ${_daysAgo(history.first.visitDate)}d ago – follow up.',
          emoji: '💬',
        ));
      }
    }

    // Common objection
    final objections = reports
        .where((r) => r.reaction == DoctorReaction.objection)
        .expand((r) => r.topicsDiscussed)
        .toList();
    if (objections.isNotEmpty) {
      final top = _mostFrequent(objections);
      highlights.add(AiKeyHighlight(
        type: AiHighlightType.objection,
        label: 'Objection: $top',
        detail: 'Raised in ${objections.where((o) => o == top).length} visits. Prepare rebuttal.',
        emoji: '⚠️',
      ));
    }

    // Competitor mention
    final comps = reports.where((r) => r.competitorMentions.isNotEmpty).toList();
    if (comps.isNotEmpty) {
      highlights.add(AiKeyHighlight(
        type: AiHighlightType.competitor,
        label: 'Competitor: ${comps.first.competitorMentions}',
        detail: 'Mentioned in ${comps.length} recent visits. Address comparatively.',
        emoji: '🔀',
      ));
    }

    // Product affinity from history
    if (history.isNotEmpty) {
      final allBrandNames = history.expand((h) => h.brandNames).toList();
      if (allBrandNames.isNotEmpty) {
        final top = _mostFrequent(allBrandNames);
        highlights.add(AiKeyHighlight(
          type: AiHighlightType.productAffinity,
          label: 'Affinity: $top',
          detail: 'Presented in ${allBrandNames.where((b) => b == top).length} sessions. Lead with this.',
          emoji: '💊',
        ));
      }
    }

    // Overdue visit
    if (doctor.lastDetailedAt != null) {
      final days = DateTime.now().difference(doctor.lastDetailedAt!).inDays;
      if (days > 30) {
        highlights.add(AiKeyHighlight(
          type: AiHighlightType.overdueVisit,
          label: 'Overdue by ${days - 30}d',
          detail: 'Last visit $days days ago. Acknowledge gap, re-establish rapport.',
          emoji: '📅',
        ));
      }
    } else {
      highlights.add(AiKeyHighlight(
        type: AiHighlightType.overdueVisit,
        label: 'First Visit',
        detail: 'No previous CLM session. Focus on introduction and rapport.',
        emoji: '🆕',
      ));
    }

    // Call frequency vs target
    if (doctor.callFrequencyTarget > 0) {
      final thisMonthVisits = history
          .where((h) =>
              h.visitDate.month == DateTime.now().month &&
              h.visitDate.year == DateTime.now().year)
          .length;
      if (thisMonthVisits < doctor.callFrequencyTarget) {
        highlights.add(AiKeyHighlight(
          type: AiHighlightType.callFrequency,
          label: '$thisMonthVisits/${doctor.callFrequencyTarget} visits/mo',
          detail: '${doctor.callFrequencyTarget - thisMonthVisits} more visits needed to hit target.',
          emoji: '🎯',
        ));
      }
    }

    return highlights;
  }

  // ─── Brand Ranking ────────────────────────────────────────────────────────

  List<AiBrandRec> _rankBrands(
    ClmDoctor doctor,
    List<ClmVisitSummary> history,
    List<ClmCallReport> reports,
    List<ClmBrand> brands,
    Map<int, List<ClmSlide>> slidesPerBrand,
  ) {
    // Only brands assigned to this doctor (or all if none assigned)
    final candidateBrands = doctor.assignedBrandIds.isEmpty
        ? brands
        : brands.where((b) => doctor.assignedBrandIds.contains(b.id)).toList();

    // Frequency map: how many sessions each brand appeared in
    final brandFreq = <String, int>{};
    for (final visit in history) {
      for (final name in visit.brandNames) {
        brandFreq[name] = (brandFreq[name] ?? 0) + 1;
      }
    }

    // Positive reaction brand map
    final positiveReactionBrands = reports
        .where((r) =>
            r.reaction == DoctorReaction.positive ||
            r.reaction == DoctorReaction.receptive)
        .expand((r) => r.brandsDiscussed)
        .toSet();

    // Speciality→therapy area match map
    final speciality = doctor.speciality.toLowerCase();

    final recs = candidateBrands.map((brand) {
      int score = 40;

      // Frequency bonus: +12 per discussion, max +36
      final freq = brandFreq[brand.name] ?? 0;
      score += (freq * 12).clamp(0, 36);

      // Positive reaction with this brand
      if (positiveReactionBrands.contains(brand.id)) score += 18;

      // Therapy area ↔ speciality match
      final ta = brand.therapyArea.toLowerCase();
      if (_therapyMatchesSpeciality(ta, speciality)) score += 15;

      // Category A doctors get full brand coverage
      if (doctor.category.toUpperCase() == 'A') score += 8;

      // Downloaded/available brands get a small push
      if (brand.isDownloaded) score += 5;

      score = score.clamp(0, 100);

      final reason = _brandReason(brand, freq, positiveReactionBrands.contains(brand.id), speciality);

      return AiBrandRec(
        brand: brand,
        score: score,
        reason: reason,
        slides: slidesPerBrand[brand.id] ?? [],
        isSelected: score >= 45, // auto-select only high-relevance brands
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // Always auto-select top 2
    for (int i = 0; i < recs.length && i < 2; i++) {
      recs[i].isSelected = true;
    }

    return recs;
  }

  bool _therapyMatchesSpeciality(String therapyArea, String speciality) {
    const map = {
      'cardiology': ['cardiologist', 'cardiac', 'heart'],
      'neurology': ['neurologist', 'neuro'],
      'diabetology': ['diabetologist', 'diabet', 'endocrinolog'],
      'oncology': ['oncologist', 'oncology', 'cancer'],
      'pulmonology': ['pulmonolog', 'respiratory', 'lungs'],
      'gynecology': ['gynecolog', 'obstetr'],
    };
    for (final entry in map.entries) {
      if (therapyArea.contains(entry.key)) {
        for (final kw in entry.value) {
          if (speciality.contains(kw)) return true;
        }
      }
    }
    return false;
  }

  String _brandReason(
      ClmBrand brand, int freq, bool hadPositive, String speciality) {
    if (freq > 0 && hadPositive) {
      return 'Presented $freq time${freq > 1 ? 's' : ''} with positive doctor response.';
    }
    if (freq > 0) {
      return 'Previously discussed in $freq CLM session${freq > 1 ? 's' : ''}.';
    }
    if (_therapyMatchesSpeciality(brand.therapyArea.toLowerCase(), speciality)) {
      return 'Strong speciality match with ${brand.therapyArea} therapy area.';
    }
    return 'Assigned product – introduce on this visit.';
  }

  // ─── Script Tips ─────────────────────────────────────────────────────────

  List<String> _buildScriptTips(
    ClmDoctor doctor,
    List<AiKeyHighlight> highlights,
    List<AiBrandRec> recs,
  ) {
    final tips = <String>[];

    // Birthday / anniversary opener
    final bday =
        highlights.where((h) => h.type == AiHighlightType.birthday).firstOrNull;
    final anni = highlights
        .where((h) => h.type == AiHighlightType.anniversary)
        .firstOrNull;
    if (bday != null) {
      tips.add('"${bday.label} Dr. ${_firstName(doctor.name)} – wishing you a wonderful day ahead!"');
    } else if (anni != null) {
      tips.add('"Congratulations on your anniversary Dr. ${_firstName(doctor.name)}!"');
    }

    // Top brand opener
    if (recs.isNotEmpty) {
      final top = recs.first;
      tips.add('"I\'d like to share the latest data on ${top.brand.name}, which I know is relevant to your practice."');
    }

    // Last topic follow-up
    final lastTopic =
        highlights.where((h) => h.type == AiHighlightType.lastTopic).firstOrNull;
    if (lastTopic != null) {
      tips.add('"Last time we discussed ${lastTopic.label} – I\'ve brought updated information on that."');
    }

    // Affinity
    final affinity = highlights
        .where((h) => h.type == AiHighlightType.productAffinity)
        .firstOrNull;
    if (affinity != null) {
      tips.add('"You\'ve shown great interest in ${affinity.label.replaceFirst('Affinity: ', '')} – here are 2 new patient cases."');
    }

    // Objection rebuttal prep
    final obj =
        highlights.where((h) => h.type == AiHighlightType.objection).firstOrNull;
    if (obj != null) {
      tips.add('"Regarding your concern about ${obj.label.replaceFirst('Objection: ', '')} – I have a cost-outcome analysis that addresses this directly."');
    }

    // Competitor
    final comp =
        highlights.where((h) => h.type == AiHighlightType.competitor).firstOrNull;
    if (comp != null) {
      tips.add('"Let me walk you through a head-to-head comparison with ${comp.label.replaceFirst('Competitor: ', '')} that shows superior outcomes."');
    }

    // Overdue reconnect
    final overdue = highlights
        .where((h) => h.type == AiHighlightType.overdueVisit)
        .firstOrNull;
    if (overdue != null && overdue.label.startsWith('Overdue')) {
      tips.add('"It\'s been a while since we met – I wanted to personally update you on what\'s new with our portfolio."');
    }

    // Close
    tips.add('"Based on what we\'ve shared today, which product would you feel most comfortable prescribing to your next relevant patient?"');

    return tips;
  }

  // ─── Summary Text ─────────────────────────────────────────────────────────

  String _buildSummary(
    ClmDoctor doctor,
    int score,
    String level,
    List<ClmVisitSummary> history,
    List<AiBrandRec> recs,
  ) {
    final parts = <String>[];

    parts.add('$level engagement doctor (${score}%).');

    if (doctor.lastDetailedAt != null) {
      final days = DateTime.now().difference(doctor.lastDetailedAt!).inDays;
      if (days == 0) {
        parts.add('Visited today earlier.');
      } else if (days <= 7) {
        parts.add('Last visited $days day${days > 1 ? 's' : ''} ago.');
      } else {
        parts.add('Last visited $days days ago.');
      }
    } else {
      parts.add('No prior CLM visit – this is a fresh call.');
    }

    if (history.isNotEmpty && history.first.reaction != null) {
      parts.add('Previous reaction: ${history.first.reaction!.emoji} ${history.first.reaction!.label}.');
    }

    if (doctor.hasBirthdaySoon(withinDays: 7)) {
      parts.add('Birthday approaching – excellent opportunity to build rapport.');
    }

    if (recs.isNotEmpty) {
      final top = recs.where((r) => r.isSelected).take(2).map((r) => r.brand.name).join(' & ');
      if (top.isNotEmpty) parts.add('AI recommends leading with $top.');
    }

    return parts.join(' ');
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  int _daysUntilMmDd(String mmdd) {
    final parts = mmdd.split('-');
    if (parts.length != 2) return 999;
    final m = int.tryParse(parts[0]);
    final d = int.tryParse(parts[1]);
    if (m == null || d == null) return 999;
    final now = DateTime.now();
    var target = DateTime(now.year, m, d);
    if (target.isBefore(DateTime(now.year, now.month, now.day))) {
      target = DateTime(now.year + 1, m, d);
    }
    return target.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  int _daysAgo(DateTime dt) =>
      DateTime.now().difference(dt).inDays;

  String _mostFrequent(List<String> items) {
    final freq = <String, int>{};
    for (final item in items) {
      freq[item] = (freq[item] ?? 0) + 1;
    }
    return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _firstName(String fullName) {
    final parts = fullName.trim().split(' ');
    return parts.length > 1 ? parts[1] : parts[0];
  }
}
