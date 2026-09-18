import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_colors.dart';
import '../../features/events/models/user_model.dart';

/// Kullanıcılar için cinsiyete duyarlı klasik profil avatarı ve kartı.
/// Fotoğraf yüklemeyen kullanıcılara ASLA yapay zeka fotoğrafı gösterilmez;
/// cinsiyetine göre klasik kullanıcı logosu (Erkek: Mavi, Kadın: Pembe, Diğer: Mor) gösterilir.
class UserAvatar extends StatelessWidget {
  final UserModel? user;
  final String? imageUrl;
  final String? gender;
  final String? name;
  final double radius;
  final BoxBorder? border;
  final VoidCallback? onTap;
  final bool showOnlineIndicator;

  const UserAvatar({
    super.key,
    this.user,
    this.imageUrl,
    this.gender,
    this.name,
    this.radius = 24,
    this.border,
    this.onTap,
    this.showOnlineIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGender = user?.gender ?? gender;
    final isMale = UserModel.isMaleGender(effectiveGender);
    final isFemale = UserModel.isFemaleGender(effectiveGender);

    final rawUrl = (imageUrl != null && imageUrl!.isNotEmpty)
        ? imageUrl!
        : (user?.validAvatarUrl ?? '');
    final hasRealPhoto = UserModel.isValidPhotoUrl(rawUrl);

    final double diameter = radius * 2;

    Widget avatarContent;
    if (hasRealPhoto) {
      avatarContent = ClipOval(
        child: CachedNetworkImage(
          imageUrl: rawUrl,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          memCacheWidth: (diameter * 2.5).round(),
          memCacheHeight: (diameter * 2.5).round(),
          errorWidget: (context, url, error) => _buildGenderFallback(isMale, isFemale),
          placeholder: (context, url) => Container(
            color: const Color(0xFF1E2235),
            child: Center(
              child: SizedBox(
                width: radius * 0.7,
                height: radius * 0.7,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isMale ? const Color(0xFF3B82F6) : (isFemale ? const Color(0xFFEC4899) : AppColors.primary),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      avatarContent = _buildGenderFallback(isMale, isFemale);
    }

    Widget result = Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: border,
      ),
      child: avatarContent,
    );

    if (showOnlineIndicator && user != null && user!.isOnline && !user!.hideLastSeen) {
      result = Stack(
        clipBehavior: Clip.none,
        children: [
          result,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.55,
              height: radius * 0.55,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      result = GestureDetector(onTap: onTap, child: result);
    }

    return result;
  }

  Widget _buildGenderFallback(bool isMale, bool isFemale) {
    // Cinsiyetine göre renk paleti ve klasik kullanıcı ikonu
    final Gradient bgGradient = isMale
        ? const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : isFemale
            ? const LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFFBE185D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              );

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: bgGradient,
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: radius * 1.15,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Profil sayfalarında (UserProfileScreen, ProfileScreen, SwipeScreen)
/// fotoğraf yüklememiş kullanıcılar için gösterilen şık, cinsiyete özel Hero Kartı.
class UserHeroAvatarCard extends StatelessWidget {
  final String? gender;
  final String? name;
  final double height;

  const UserHeroAvatarCard({
    super.key,
    this.gender,
    this.name,
    this.height = 380,
  });

  @override
  Widget build(BuildContext context) {
    final isMale = UserModel.isMaleGender(gender);
    final isFemale = UserModel.isFemaleGender(gender);

    final bgColors = isMale
        ? [const Color(0xFF0B1120), const Color(0xFF131F37), const Color(0xFF090D18)]
        : isFemale
            ? [const Color(0xFF1A0A16), const Color(0xFF281123), const Color(0xFF11070F)]
            : [const Color(0xFF120E1C), const Color(0xFF1E1630), const Color(0xFF0C0913)];

    final badgeGradient = isMale
        ? const LinearGradient(
            colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : isFemale
            ? const LinearGradient(
                colors: [Color(0xFF9D174D), Color(0xFFEC4899)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              );

    final borderColor = isMale
        ? const Color(0xFF60A5FA).withValues(alpha: 0.6)
        : isFemale
            ? const Color(0xFFF472B6).withValues(alpha: 0.6)
            : const Color(0xFFA78BFA).withValues(alpha: 0.6);

    final shadowColor = isMale
        ? const Color(0xFF2563EB).withValues(alpha: 0.35)
        : isFemale
            ? const Color(0xFFEC4899).withValues(alpha: 0.35)
            : const Color(0xFF8B5CF6).withValues(alpha: 0.35);

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient soft radial glow
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 70,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
          // Center content
          Center(
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: badgeGradient,
                border: Border.all(color: borderColor, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.person_rounded,
                  size: 76,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
