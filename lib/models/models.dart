/// Shared data models for NexusShield, mirroring the backend's Pydantic
/// response shapes (see backend/app/schemas.py and routers).

class RedFlag {
  final String flag;
  final String detail;
  RedFlag({required this.flag, required this.detail});

  factory RedFlag.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return RedFlag(flag: json['flag'] ?? '', detail: json['detail'] ?? '');
    }
    return RedFlag(flag: json.toString(), detail: '');
  }
}

class AnalysisResult {
  final int riskScore;
  final String scamType;
  final String category;
  final String summary;
  final List<RedFlag> redFlags;
  final String advice;
  final bool matchedKnownScam;

  AnalysisResult({
    required this.riskScore,
    required this.scamType,
    required this.category,
    required this.summary,
    required this.redFlags,
    required this.advice,
    this.matchedKnownScam = false,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      riskScore: json['risk_score'] ?? 0,
      scamType: json['scam_type'] ?? 'Unknown',
      category: json['category'] ?? json['scam_type'] ?? 'Unknown',
      summary: json['summary'] ?? '',
      redFlags: (json['red_flags'] as List? ?? []).map((f) => RedFlag.fromJson(f)).toList(),
      advice: json['advice'] ?? '',
      matchedKnownScam: json['matched_known_scam'] ?? false,
    );
  }
}

class UserProfile {
  final String id;
  final String email;
  final String name;
  final String photoUrl;
  final String authProvider;
  final bool isEmailVerified;
  final bool isAdmin;
  final String language;
  final String theme;
  final bool notifPushEnabled;
  final bool notifThreatAlerts;
  final bool notifWeeklySummary;
  final bool securityBiometricLock;
  final bool securityAutoScanClipboard;
  final String? organizationId;

  UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.photoUrl,
    required this.authProvider,
    required this.isEmailVerified,
    required this.isAdmin,
    required this.language,
    required this.theme,
    required this.notifPushEnabled,
    required this.notifThreatAlerts,
    required this.notifWeeklySummary,
    required this.securityBiometricLock,
    required this.securityAutoScanClipboard,
    this.organizationId,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final notif = json['notification_settings'] ?? {};
    final sec = json['security_settings'] ?? {};
    return UserProfile(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      photoUrl: json['photo_url'] ?? '',
      authProvider: json['auth_provider'] ?? 'password',
      isEmailVerified: json['is_email_verified'] ?? false,
      isAdmin: json['is_admin'] ?? false,
      language: json['language'] ?? 'en',
      theme: json['theme'] ?? 'dark',
      notifPushEnabled: notif['push_enabled'] ?? true,
      notifThreatAlerts: notif['threat_alerts'] ?? true,
      notifWeeklySummary: notif['weekly_summary'] ?? true,
      securityBiometricLock: sec['biometric_lock'] ?? false,
      securityAutoScanClipboard: sec['auto_scan_clipboard'] ?? true,
      organizationId: json['organization_id'],
    );
  }
}

class HistoryItem {
  final String id;
  final String scanType;
  final String inputPreview;
  final int riskScore;
  final String scamType;
  final String category;
  final String summary;
  final List<RedFlag> redFlags;
  final String advice;
  final bool matchedKnownScam;
  final DateTime createdAt;

  HistoryItem({
    required this.id,
    required this.scanType,
    required this.inputPreview,
    required this.riskScore,
    required this.scamType,
    required this.category,
    required this.summary,
    required this.redFlags,
    required this.advice,
    required this.matchedKnownScam,
    required this.createdAt,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'],
      scanType: json['scan_type'] ?? '',
      inputPreview: json['input_preview'] ?? '',
      riskScore: json['risk_score'] ?? 0,
      scamType: json['scam_type'] ?? '',
      category: json['category'] ?? '',
      summary: json['summary'] ?? '',
      redFlags: (json['red_flags'] as List? ?? []).map((f) => RedFlag.fromJson(f)).toList(),
      advice: json['advice'] ?? '',
      matchedKnownScam: json['matched_known_scam'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class ThreatFeedItem {
  final String id;
  final String title;
  final String description;
  final String region;
  final String category;
  final String severity;
  final String source;
  final DateTime publishedAt;

  ThreatFeedItem({
    required this.id, required this.title, required this.description,
    required this.region, required this.category, required this.severity,
    required this.source, required this.publishedAt,
  });

  factory ThreatFeedItem.fromJson(Map<String, dynamic> json) {
    return ThreatFeedItem(
      id: json['id'], title: json['title'], description: json['description'] ?? '',
      region: json['region'] ?? '', category: json['category'] ?? '',
      severity: json['severity'] ?? 'medium', source: json['source'] ?? '',
      publishedAt: DateTime.parse(json['published_at']),
    );
  }
}

class NewsItem {
  final String id;
  final String title;
  final String summary;
  final String source;
  final String url;
  final String category;
  final DateTime publishedAt;

  NewsItem({
    required this.id, required this.title, required this.summary,
    required this.source, required this.url, required this.category,
    required this.publishedAt,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'], title: json['title'], summary: json['summary'] ?? '',
      source: json['source'] ?? '', url: json['url'] ?? '', category: json['category'] ?? '',
      publishedAt: DateTime.parse(json['published_at']),
    );
  }
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String kind;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id, required this.title, required this.body,
    required this.kind, required this.isRead, required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'], title: json['title'], body: json['body'] ?? '',
      kind: json['kind'] ?? 'alert', isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class ScamReport {
  final String id;
  final String website;
  final String phoneNumber;
  final String upiId;
  final String description;
  final String category;
  final String status;
  final DateTime createdAt;

  ScamReport({
    required this.id, required this.website, required this.phoneNumber,
    required this.upiId, required this.description, required this.category,
    required this.status, required this.createdAt,
  });

  factory ScamReport.fromJson(Map<String, dynamic> json) {
    return ScamReport(
      id: json['id'], website: json['website'] ?? '', phoneNumber: json['phone_number'] ?? '',
      upiId: json['upi_id'] ?? '', description: json['description'] ?? '',
      category: json['category'] ?? '', status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class FamilyMember {
  final String id;
  final String memberLabel;
  final String? memberEmail;
  final bool alertsEnabled;
  final int minRiskToAlert;

  FamilyMember({
    required this.id, required this.memberLabel, this.memberEmail,
    required this.alertsEnabled, required this.minRiskToAlert,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'], memberLabel: json['member_label'] ?? '',
      memberEmail: json['member_email'], alertsEnabled: json['alerts_enabled'] ?? true,
      minRiskToAlert: json['min_risk_to_alert'] ?? 70,
    );
  }
}

// ── Counterfeit Currency Detection ──────────────────────────────────────────
class CurrencyAnalysisResult {
  final bool likelyGenuine;
  final int confidencePercent;
  final List<String> reasons;

  CurrencyAnalysisResult({
    required this.likelyGenuine,
    required this.confidencePercent,
    required this.reasons,
  });

  factory CurrencyAnalysisResult.fromJson(Map<String, dynamic> json) {
    return CurrencyAnalysisResult(
      likelyGenuine: json['likely_genuine'] == true,
      confidencePercent: (json['confidence_percent'] is int)
          ? json['confidence_percent']
          : int.tryParse('${json['confidence_percent']}') ?? 0,
      reasons: (json['reasons'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

// ── Geospatial Crime Intelligence ───────────────────────────────────────────
class ScamHotspot {
  final double latitude;
  final double longitude;
  final String city;
  final int reportCount;
  final String topCategory;
  final Map<String, dynamic> categoryBreakdown;

  ScamHotspot({
    required this.latitude, required this.longitude, required this.city,
    required this.reportCount, required this.topCategory, required this.categoryBreakdown,
  });

  factory ScamHotspot.fromJson(Map<String, dynamic> json) {
    return ScamHotspot(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      city: json['city'] ?? 'Unknown',
      reportCount: json['report_count'] ?? 0,
      topCategory: json['top_category'] ?? 'Uncategorized',
      categoryBreakdown: Map<String, dynamic>.from(json['category_breakdown'] ?? {}),
    );
  }
}

// ── Fraud Network Intelligence ──────────────────────────────────────────────
class FraudNetworkNode {
  final String id;
  final String type;
  final String typeLabel;
  final String value;
  final int linkedReportCount;

  FraudNetworkNode({
    required this.id, required this.type, required this.typeLabel,
    required this.value, required this.linkedReportCount,
  });

  factory FraudNetworkNode.fromJson(Map<String, dynamic> json) {
    return FraudNetworkNode(
      id: json['id'], type: json['type'] ?? '', typeLabel: json['type_label'] ?? '',
      value: json['value'] ?? '', linkedReportCount: json['linked_report_count'] ?? 0,
    );
  }
}

class FraudNetworkEdge {
  final String source;
  final String target;
  final String category;

  FraudNetworkEdge({required this.source, required this.target, required this.category});

  factory FraudNetworkEdge.fromJson(Map<String, dynamic> json) {
    return FraudNetworkEdge(
      source: json['source'], target: json['target'], category: json['category'] ?? '',
    );
  }
}

class FraudNetworkGraph {
  final String query;
  final List<FraudNetworkNode> nodes;
  final List<FraudNetworkEdge> edges;
  final int reportCount;

  FraudNetworkGraph({
    required this.query, required this.nodes, required this.edges, required this.reportCount,
  });

  factory FraudNetworkGraph.fromJson(Map<String, dynamic> json) {
    return FraudNetworkGraph(
      query: json['query'] ?? '',
      nodes: (json['nodes'] as List? ?? []).map((n) => FraudNetworkNode.fromJson(n)).toList(),
      edges: (json['edges'] as List? ?? []).map((e) => FraudNetworkEdge.fromJson(e)).toList(),
      reportCount: json['report_count'] ?? 0,
    );
  }
}
