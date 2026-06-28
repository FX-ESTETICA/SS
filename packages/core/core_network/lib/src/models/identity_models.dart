enum IdentityKind {
  life('life', '生活'),
  business('business', '智控');

  const IdentityKind(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static IdentityKind fromDbValue(String raw) {
    return IdentityKind.values.firstWhere(
      (kind) => kind.dbValue == raw,
      orElse: () => IdentityKind.life,
    );
  }
}

class UserProfileRecord {
  const UserProfileRecord({
    required this.userId,
    required this.avatarUrl,
    required this.zodiacSign,
    required this.sharedStatus,
    required this.settingsJson,
    required this.lastActiveIdentityId,
  });

  final String userId;
  final String? avatarUrl;
  final String zodiacSign;
  final String sharedStatus;
  final Map<String, dynamic> settingsJson;
  final String? lastActiveIdentityId;

  factory UserProfileRecord.fromJson(Map<String, dynamic> json) {
    return UserProfileRecord(
      userId: json['user_id'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      zodiacSign: json['zodiac_sign'] as String? ?? '双子座',
      sharedStatus: json['shared_status'] as String? ?? '保持发光',
      settingsJson: Map<String, dynamic>.from(
        json['settings_json'] as Map? ?? const <String, dynamic>{},
      ),
      lastActiveIdentityId: json['last_active_identity_id'] as String?,
    );
  }

  UserProfileRecord copyWith({
    String? userId,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    String? zodiacSign,
    String? sharedStatus,
    Map<String, dynamic>? settingsJson,
    String? lastActiveIdentityId,
    bool clearLastActiveIdentityId = false,
  }) {
    return UserProfileRecord(
      userId: userId ?? this.userId,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      zodiacSign: zodiacSign ?? this.zodiacSign,
      sharedStatus: sharedStatus ?? this.sharedStatus,
      settingsJson: settingsJson ?? this.settingsJson,
      lastActiveIdentityId: clearLastActiveIdentityId
          ? null
          : (lastActiveIdentityId ?? this.lastActiveIdentityId),
    );
  }
}

class UserIdentityRecord {
  const UserIdentityRecord({
    required this.id,
    required this.userId,
    required this.kind,
    required this.displayName,
    required this.publicId,
    required this.bio,
    required this.isEnabled,
  });

  final String id;
  final String userId;
  final IdentityKind kind;
  final String displayName;
  final String publicId;
  final String bio;
  final bool isEnabled;

  factory UserIdentityRecord.fromJson(Map<String, dynamic> json) {
    return UserIdentityRecord(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      kind: IdentityKind.fromDbValue(
        json['identity_kind'] as String? ?? IdentityKind.life.dbValue,
      ),
      displayName: json['display_name'] as String? ?? '',
      publicId: json['public_id'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      isEnabled: json['is_enabled'] as bool? ?? true,
    );
  }

  UserIdentityRecord copyWith({
    String? id,
    String? userId,
    IdentityKind? kind,
    String? displayName,
    String? publicId,
    String? bio,
    bool? isEnabled,
  }) {
    return UserIdentityRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      kind: kind ?? this.kind,
      displayName: displayName ?? this.displayName,
      publicId: publicId ?? this.publicId,
      bio: bio ?? this.bio,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

class MerchantProfileRecord {
  const MerchantProfileRecord({
    required this.id,
    required this.identityId,
    required this.merchantDisplayName,
    required this.merchantStatus,
    required this.verificationStatus,
    required this.onboardingStage,
  });

  final String id;
  final String identityId;
  final String merchantDisplayName;
  final String merchantStatus;
  final String verificationStatus;
  final String onboardingStage;

  factory MerchantProfileRecord.fromJson(Map<String, dynamic> json) {
    return MerchantProfileRecord(
      id: json['id'] as String? ?? '',
      identityId: json['identity_id'] as String? ?? '',
      merchantDisplayName: json['merchant_display_name'] as String? ?? '',
      merchantStatus: json['merchant_status'] as String? ?? 'draft',
      verificationStatus:
          json['verification_status'] as String? ?? 'unverified',
      onboardingStage:
          json['onboarding_stage'] as String? ?? 'identity_created',
    );
  }
}

class IdentityHub {
  const IdentityHub({
    required this.profile,
    required this.identities,
    required this.activeIdentityId,
    required this.businessMerchantProfile,
  });

  final UserProfileRecord profile;
  final List<UserIdentityRecord> identities;
  final String activeIdentityId;
  final MerchantProfileRecord? businessMerchantProfile;

  UserIdentityRecord get activeIdentity => identities.firstWhere(
        (identity) => identity.id == activeIdentityId,
        orElse: () => identities.first,
      );

  UserIdentityRecord get lifeIdentity => identities.firstWhere(
        (identity) => identity.kind == IdentityKind.life,
        orElse: () => identities.first,
      );

  UserIdentityRecord? get businessIdentity {
    for (final identity in identities) {
      if (identity.kind == IdentityKind.business) {
        return identity;
      }
    }
    return null;
  }

  bool get isBusinessActive => activeIdentity.kind == IdentityKind.business;

  IdentityHub copyWith({
    UserProfileRecord? profile,
    List<UserIdentityRecord>? identities,
    String? activeIdentityId,
    MerchantProfileRecord? businessMerchantProfile,
    bool keepMerchantProfile = true,
  }) {
    return IdentityHub(
      profile: profile ?? this.profile,
      identities: identities ?? this.identities,
      activeIdentityId: activeIdentityId ?? this.activeIdentityId,
      businessMerchantProfile: keepMerchantProfile
          ? (businessMerchantProfile ?? this.businessMerchantProfile)
          : businessMerchantProfile,
    );
  }
}
