import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../services/mock_match_service.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Eşleşme İstekleri', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<MockMatchService>(
        builder: (context, matchService, child) {
          final requests = matchService.incomingRequests;
          if (requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: AppColors.surface),
                  SizedBox(height: 16),
                  Text(
                    "Şu an bekleyen istek yok.",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.surface,
                      radius: 30,
                      child: ClipOval(
                        child: req.fromUser.avatarUrl.startsWith('http')
                          ? Image.network(
                              req.fromUser.avatarUrl,
                              width: 60, height: 60, fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: AppColors.primary),
                            )
                          : Image.asset(
                              req.fromUser.avatarUrl,
                              width: 60, height: 60, fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: AppColors.primary),
                            ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req.fromUser.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 18)),
                          const SizedBox(height: 4),
                          const Text("Seninle tanışmak istiyor!", style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary),
                          onPressed: () {
                            matchService.rejectRequest(req.id);
                          },
                        ),
                        ElevatedButton(
                          onPressed: () {
                            matchService.acceptRequest(req.id);
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: AppColors.surface,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                title: const Text('Eşleşme Sağlandı! 🎉', textAlign: TextAlign.center, style: TextStyle(color: AppColors.primary)),
                                content: Text('${req.fromUser.name} ile eşleştin. Şimdi mesajlaşma vakti!', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary)),
                                actions: [
                                  Center(
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                      child: const Text('Kapat', style: TextStyle(color: Colors.white)),
                                    ),
                                  )
                                ],
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text("Kabul Et", style: TextStyle(color: Colors.white)),
                        )
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
