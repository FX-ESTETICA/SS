import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String kDefaultProfileAvatarUrl =
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=250&q=80';

String resolveCurrentUserAvatarUrl({String? sharedAvatarUrl}) {
  if (sharedAvatarUrl != null && sharedAvatarUrl.trim().isNotEmpty) {
    return sharedAvatarUrl.trim();
  }

  final metadata = SupabaseService.currentUser?.userMetadata ?? {};
  final rawAvatarUrl = metadata['avatar_url'];
  if (rawAvatarUrl is String && rawAvatarUrl.trim().isNotEmpty) {
    return rawAvatarUrl.trim();
  }
  return kDefaultProfileAvatarUrl;
}

class CurrentUserAvatar extends ConsumerWidget {
  final double size;
  final VoidCallback? onTap;
  final IconData fallbackIcon;
  final double fallbackIconSize;
  final Color fallbackIconColor;
  final Color backgroundColor;
  final List<BoxShadow>? boxShadow;

  const CurrentUserAvatar({
    super.key,
    required this.size,
    this.onTap,
    this.fallbackIcon = Icons.person_outline,
    this.fallbackIconSize = 18,
    this.fallbackIconColor = Colors.white,
    this.backgroundColor = Colors.black,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityHub = ref.watch(identityControllerProvider).asData?.value;
    final sharedAvatarUrl = identityHub?.profile.avatarUrl;
    final avatar = SizedBox(
      width: size,
      height: size,
      child: StreamBuilder(
        stream: SupabaseService.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final isLoggedIn = SupabaseService.currentSession != null;
          final avatarUrl = isLoggedIn
              ? resolveCurrentUserAvatarUrl(sharedAvatarUrl: sharedAvatarUrl)
              : null;

          return DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor,
              boxShadow: boxShadow,
            ),
            child: ClipOval(
              child: avatarUrl == null
                  ? Center(
                      child: Icon(
                        fallbackIcon,
                        color: fallbackIconColor,
                        size: fallbackIconSize,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Center(
                        child: Icon(
                          fallbackIcon,
                          color: fallbackIconColor,
                          size: fallbackIconSize,
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );

    if (onTap == null) {
      return avatar;
    }

    return GestureDetector(
      onTap: onTap,
      child: avatar,
    );
  }
}
