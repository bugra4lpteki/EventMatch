import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/user_model.dart';
import '../../profile/screens/user_profile_screen.dart';

class MatchDialog extends StatelessWidget {
  final UserModel matchedUser;
  final String? currentAvatarUrl;
  final VoidCallback onSendMessage;

  const MatchDialog({
    super.key,
    required this.matchedUser,
    this.currentAvatarUrl,
    required this.onSendMessage,
  });

  static Future<void> show(
    BuildContext context, {
    required UserModel matchedUser,
    String? currentAvatarUrl,
    required VoidCallback onSendMessage,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) => MatchDialog(
        matchedUser: matchedUser,
        currentAvatarUrl: currentAvatarUrl,
        onSendMessage: onSendMessage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAvatar = currentAvatarUrl ?? '';
    final matchAvatar = matchedUser.avatarUrl;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Heart/Sparkle Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.redAccent,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Tebrikler! 🎉",
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Eşleşme Sağlandı!",
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            // Avatars Overlapping Row (Tıklanınca profile gider)
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(user: matchedUser),
                  ),
                );
              },
              child: SizedBox(
                height: 100,
                width: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFF1E2235),
                          backgroundImage: userAvatar.startsWith('http')
                              ? NetworkImage(userAvatar)
                              : null,
                          child: !userAvatar.startsWith('http')
                              ? const Icon(Icons.person, color: Colors.white, size: 36)
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.pinkAccent,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFF1E2235),
                          backgroundImage: matchAvatar.startsWith('http')
                              ? NetworkImage(matchAvatar)
                              : null,
                          child: !matchAvatar.startsWith('http')
                              ? Text(
                                  matchedUser.name.isNotEmpty ? matchedUser.name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(user: matchedUser),
                  ),
                );
              },
              child: Text.rich(
                TextSpan(
                  text: "Sen ve ",
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                  children: [
                    TextSpan(
                      text: matchedUser.name,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const TextSpan(text: " birbirinizi beğendiniz!"),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onSendMessage();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 4,
                ),
                icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                label: const Text(
                  "Sohbet Et",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(user: matchedUser),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                icon: Icon(Icons.person_outline_rounded, color: AppColors.primary),
                label: Text(
                  "Profili Görüntüle",
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Keşfetmeye Devam Et",
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
