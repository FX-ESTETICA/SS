import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/identity_models.dart';
import '../supabase_service.dart';

final identityRepositoryProvider = Provider<IdentityRepository>((ref) {
  final supabaseClient = ref.watch(supabaseProvider);
  return IdentityRepository(supabaseClient);
});

final identityControllerProvider =
    AsyncNotifierProvider<IdentityController, IdentityHub?>(
  IdentityController.new,
);

final activeIdentityProvider = Provider<UserIdentityRecord?>((ref) {
  return ref.watch(identityControllerProvider).asData?.value?.activeIdentity;
});

final sharedProfileProvider = Provider<UserProfileRecord?>((ref) {
  return ref.watch(identityControllerProvider).asData?.value?.profile;
});

class IdentityController extends AsyncNotifier<IdentityHub?> {
  StreamSubscription<AuthState>? _authSubscription;

  IdentityRepository get _repository => ref.read(identityRepositoryProvider);

  @override
  Future<IdentityHub?> build() async {
    _authSubscription ??= SupabaseService.onAuthStateChange.listen((authState) {
      scheduleMicrotask(() {
        final user = authState.session?.user;
        if (user == null) {
          state = const AsyncValue.data(null);
          return;
        }
        unawaited(refresh());
      });
    });
    ref.onDispose(() {
      _authSubscription?.cancel();
      _authSubscription = null;
    });

    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) {
      return null;
    }
    return _repository.loadIdentityHub();
  }

  Future<void> refresh() async {
    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) {
      state = const AsyncValue.data(null);
      return;
    }

    final previousValue = state.asData?.value;
    if (previousValue == null) {
      state = const AsyncValue.loading();
    }

    try {
      final hub = await _repository.loadIdentityHub();
      state = AsyncValue.data(hub);
    } catch (error, stackTrace) {
      if (previousValue != null) {
        state = AsyncValue.data(previousValue);
      } else {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> switchActiveIdentity(String identityId) async {
    final currentHub = state.asData?.value;
    if (currentHub == null) {
      final hub = await _repository.switchActiveIdentity(identityId);
      state = AsyncValue.data(hub);
      return;
    }

    final canSwitch = currentHub.identities.any(
      (identity) => identity.id == identityId && identity.isEnabled,
    );
    if (!canSwitch) {
      throw Exception('无效的身份切换请求');
    }
    if (currentHub.activeIdentityId == identityId) {
      return;
    }

    final optimisticHub = currentHub.copyWith(
      profile: currentHub.profile.copyWith(lastActiveIdentityId: identityId),
      activeIdentityId: identityId,
    );
    state = AsyncValue.data(optimisticHub);

    try {
      await _repository.persistActiveIdentity(identityId);
    } catch (error, stackTrace) {
      state = AsyncValue.data(currentHub);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> updateIdentityDisplayName({
    required String identityId,
    required String displayName,
  }) async {
    final hub = await _repository.updateIdentityDisplayName(
      identityId: identityId,
      displayName: displayName,
    );
    state = AsyncValue.data(hub);
  }

  Future<void> updateSharedAvatar(String avatarUrl) async {
    final hub = await _repository.updateSharedAvatar(avatarUrl);
    state = AsyncValue.data(hub);
  }

  Future<void> updateSharedStatus(String sharedStatus) async {
    final hub = await _repository.updateSharedStatus(sharedStatus);
    state = AsyncValue.data(hub);
  }
}

class IdentityRepository {
  IdentityRepository(this._client);

  final SupabaseClient _client;

  Future<IdentityHub> loadIdentityHub() async {
    final user = _requireCurrentUser();
    await _ensureBaseGraph(user);

    var profile = await _fetchProfile(user.id);
    var identities = await _fetchIdentities(user.id);
    if (profile == null || identities.isEmpty) {
      await _ensureBaseGraph(user);
      profile = await _fetchProfile(user.id);
      identities = await _fetchIdentities(user.id);
    }

    if (profile == null || identities.isEmpty) {
      throw Exception('身份初始化失败，请稍后重试');
    }

    final activeIdentity = _resolveActiveIdentity(
      profile: profile,
      identities: identities,
    );

    if (profile.lastActiveIdentityId != activeIdentity.id) {
      await _client
          .from('user_profiles')
          .update({'last_active_identity_id': activeIdentity.id}).eq(
        'user_id',
        user.id,
      );
      profile = profile.copyWith(lastActiveIdentityId: activeIdentity.id);
    }

    MerchantProfileRecord? merchantProfile;
    final businessIdentity = _firstIdentityByKind(
      identities,
      IdentityKind.business,
    );
    if (businessIdentity != null) {
      merchantProfile = await _fetchMerchantProfile(businessIdentity.id);
      if (merchantProfile == null) {
        await _createMerchantProfile(
          identityId: businessIdentity.id,
          merchantDisplayName: _merchantDisplayNameFor(
            businessIdentity: businessIdentity,
            lifeIdentity: _resolveLifeIdentity(identities),
          ),
        );
        merchantProfile = await _fetchMerchantProfile(businessIdentity.id);
      }
    }

    return IdentityHub(
      profile: profile,
      identities: identities,
      activeIdentityId: activeIdentity.id,
      businessMerchantProfile: merchantProfile,
    );
  }

  Future<IdentityHub> switchActiveIdentity(String identityId) async {
    final user = _requireCurrentUser();
    final identities = await _fetchIdentities(user.id);
    final canSwitch = identities.any((identity) => identity.id == identityId);
    if (!canSwitch) {
      throw Exception('无效的身份切换请求');
    }

    await _client
        .from('user_profiles')
        .update({'last_active_identity_id': identityId}).eq('user_id', user.id);
    return loadIdentityHub();
  }

  Future<void> persistActiveIdentity(String identityId) async {
    final user = _requireCurrentUser();
    final identity = await _fetchIdentity(identityId);
    if (identity == null || identity.userId != user.id || !identity.isEnabled) {
      throw Exception('无效的身份切换请求');
    }

    await _client
        .from('user_profiles')
        .update({'last_active_identity_id': identityId}).eq('user_id', user.id);
  }

  Future<IdentityHub> updateIdentityDisplayName({
    required String identityId,
    required String displayName,
  }) async {
    final user = _requireCurrentUser();
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      throw Exception('名称不能为空');
    }

    final identity = await _fetchIdentity(identityId);
    if (identity == null || identity.userId != user.id) {
      throw Exception('找不到要更新的身份');
    }

    await _client
        .from('user_identities')
        .update({'display_name': trimmedName}).eq('id', identityId);

    if (identity.kind == IdentityKind.life) {
      final metadata = Map<String, dynamic>.from(user.userMetadata ?? {});
      metadata['display_name'] = trimmedName;
      await SupabaseService.updateUserMetadata(metadata);
    } else {
      final merchantProfile = await _fetchMerchantProfile(identityId);
      if (merchantProfile != null &&
          merchantProfile.merchantDisplayName == identity.displayName) {
        await _client
            .from('merchant_profiles')
            .update({'merchant_display_name': trimmedName}).eq(
          'identity_id',
          identityId,
        );
      }
    }

    return loadIdentityHub();
  }

  Future<IdentityHub> updateSharedAvatar(String avatarUrl) async {
    final user = _requireCurrentUser();
    final normalized = avatarUrl.trim();
    if (normalized.isEmpty) {
      throw Exception('头像地址不能为空');
    }

    await _client
        .from('user_profiles')
        .update({'avatar_url': normalized}).eq('user_id', user.id);

    final metadata = Map<String, dynamic>.from(user.userMetadata ?? {});
    metadata['avatar_url'] = normalized;
    await SupabaseService.updateUserMetadata(metadata);

    return loadIdentityHub();
  }

  Future<IdentityHub> updateSharedStatus(String sharedStatus) async {
    final user = _requireCurrentUser();
    final trimmedStatus = sharedStatus.trim();
    if (trimmedStatus.isEmpty) {
      throw Exception('状态不能为空');
    }

    await _client
        .from('user_profiles')
        .update({'shared_status': trimmedStatus}).eq('user_id', user.id);

    return loadIdentityHub();
  }

  Future<void> _ensureBaseGraph(User user) async {
    await _ensureProfile(user);

    final lifeIdentity = await _ensureIdentity(
      user: user,
      kind: IdentityKind.life,
      displayName: _legacyDisplayNameFor(user),
      bio: '生活身份',
    );

    final businessIdentity = await _ensureIdentity(
      user: user,
      kind: IdentityKind.business,
      displayName: '${lifeIdentity.displayName} 智控',
      bio: '智控身份',
    );

    await _ensureMerchantProfile(
      identityId: businessIdentity.id,
      merchantDisplayName: _merchantDisplayNameFor(
        businessIdentity: businessIdentity,
        lifeIdentity: lifeIdentity,
      ),
    );

    final profile = await _fetchProfile(user.id);
    if (profile == null || profile.lastActiveIdentityId == null) {
      await _client.from('user_profiles').update({
        'last_active_identity_id': lifeIdentity.id,
      }).eq('user_id', user.id);
    }
  }

  Future<void> _ensureProfile(User user) async {
    final profile = await _fetchProfile(user.id);
    if (profile != null) {
      return;
    }

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    await _client.from('user_profiles').insert({
      'user_id': user.id,
      'avatar_url': _legacyAvatarUrlFor(metadata),
      'zodiac_sign': '双子座',
      'shared_status': '保持发光',
      'settings_json': <String, dynamic>{},
    });
  }

  Future<UserIdentityRecord> _ensureIdentity({
    required User user,
    required IdentityKind kind,
    required String displayName,
    required String bio,
  }) async {
    final existing = await _fetchIdentityByKind(user.id, kind);
    if (existing != null) {
      return existing;
    }

    await _client.from('user_identities').insert({
      'user_id': user.id,
      'identity_kind': kind.dbValue,
      'display_name': displayName,
      'bio': bio,
    });

    final created = await _fetchIdentityByKind(user.id, kind);
    if (created == null) {
      throw Exception('身份创建失败');
    }
    return created;
  }

  Future<void> _ensureMerchantProfile({
    required String identityId,
    required String merchantDisplayName,
  }) async {
    final existing = await _fetchMerchantProfile(identityId);
    if (existing != null) {
      return;
    }

    await _createMerchantProfile(
      identityId: identityId,
      merchantDisplayName: merchantDisplayName,
    );
  }

  Future<void> _createMerchantProfile({
    required String identityId,
    required String merchantDisplayName,
  }) async {
    await _client.from('merchant_profiles').insert({
      'identity_id': identityId,
      'merchant_display_name': merchantDisplayName,
      'merchant_status': 'draft',
      'verification_status': 'unverified',
      'onboarding_stage': 'identity_created',
    });
  }

  Future<UserProfileRecord?> _fetchProfile(String userId) async {
    final response = await _client
        .from('user_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (response == null) {
      return null;
    }
    return UserProfileRecord.fromJson(Map<String, dynamic>.from(response));
  }

  Future<List<UserIdentityRecord>> _fetchIdentities(String userId) async {
    final response = await _client
        .from('user_identities')
        .select()
        .eq('user_id', userId)
        .eq('is_enabled', true)
        .order('created_at', ascending: true);
    return response
        .map<UserIdentityRecord>(
          (row) => UserIdentityRecord.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<UserIdentityRecord?> _fetchIdentity(String identityId) async {
    final response = await _client
        .from('user_identities')
        .select()
        .eq('id', identityId)
        .maybeSingle();
    if (response == null) {
      return null;
    }
    return UserIdentityRecord.fromJson(Map<String, dynamic>.from(response));
  }

  Future<UserIdentityRecord?> _fetchIdentityByKind(
    String userId,
    IdentityKind kind,
  ) async {
    final response = await _client
        .from('user_identities')
        .select()
        .eq('user_id', userId)
        .eq('identity_kind', kind.dbValue)
        .maybeSingle();
    if (response == null) {
      return null;
    }
    return UserIdentityRecord.fromJson(Map<String, dynamic>.from(response));
  }

  Future<MerchantProfileRecord?> _fetchMerchantProfile(
    String identityId,
  ) async {
    final response = await _client
        .from('merchant_profiles')
        .select()
        .eq('identity_id', identityId)
        .maybeSingle();
    if (response == null) {
      return null;
    }
    return MerchantProfileRecord.fromJson(Map<String, dynamic>.from(response));
  }

  User _requireCurrentUser() {
    final user = SupabaseService.currentUser;
    if (user == null) {
      throw Exception('请先登录后再使用身份系统');
    }
    return user;
  }

  UserIdentityRecord _resolveActiveIdentity({
    required UserProfileRecord profile,
    required List<UserIdentityRecord> identities,
  }) {
    if (identities.isEmpty) {
      throw Exception('当前账户不存在可用身份');
    }

    if (profile.lastActiveIdentityId != null) {
      for (final identity in identities) {
        if (identity.id == profile.lastActiveIdentityId) {
          return identity;
        }
      }
    }

    final lifeIdentity = _firstIdentityByKind(identities, IdentityKind.life);
    return lifeIdentity ?? identities.first;
  }

  UserIdentityRecord _resolveLifeIdentity(List<UserIdentityRecord> identities) {
    return _firstIdentityByKind(identities, IdentityKind.life) ??
        identities.first;
  }

  UserIdentityRecord? _firstIdentityByKind(
    List<UserIdentityRecord> identities,
    IdentityKind kind,
  ) {
    for (final identity in identities) {
      if (identity.kind == kind) {
        return identity;
      }
    }
    return null;
  }

  String _legacyDisplayNameFor(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final rawDisplayName = metadata['display_name'];
    if (rawDisplayName is String && rawDisplayName.trim().isNotEmpty) {
      return rawDisplayName.trim();
    }

    final emailPrefix = user.email?.split('@').first.trim();
    if (emailPrefix != null && emailPrefix.isNotEmpty) {
      return emailPrefix;
    }

    return '生活用户';
  }

  String? _legacyAvatarUrlFor(Map<String, dynamic> metadata) {
    final rawAvatarUrl = metadata['avatar_url'];
    if (rawAvatarUrl is String && rawAvatarUrl.trim().isNotEmpty) {
      return rawAvatarUrl.trim();
    }
    return null;
  }

  String _merchantDisplayNameFor({
    required UserIdentityRecord businessIdentity,
    required UserIdentityRecord lifeIdentity,
  }) {
    final normalizedBusinessName = businessIdentity.displayName.trim();
    if (normalizedBusinessName.isNotEmpty &&
        normalizedBusinessName != '${lifeIdentity.displayName} 智控') {
      return normalizedBusinessName;
    }
    return lifeIdentity.displayName;
  }
}
