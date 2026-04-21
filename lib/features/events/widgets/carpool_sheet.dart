import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../models/carpool_model.dart';
import '../models/event_model.dart';
import '../services/mock_event_service.dart';

class CarpoolSheet extends StatefulWidget {
  final EventModel event;
  const CarpoolSheet({super.key, required this.event});

  @override
  State<CarpoolSheet> createState() => _CarpoolSheetState();
}

class _CarpoolSheetState extends State<CarpoolSheet> {
  final TextEditingController _noteController = TextEditingController();
  CarpoolType _selectedType = CarpoolType.offer;
  int _capacity = 3;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Birlikte Git (Ulaşım)',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Toggle Buttons
          Row(
            children: [
              _buildToggleButton('Arabamla Gidiyorum', CarpoolType.offer),
              const SizedBox(width: 12),
              _buildToggleButton('Beni de Al', CarpoolType.request),
            ],
          ),
          const SizedBox(height: 24),
          // List of Carpools
          Expanded(
            child: Consumer<MockEventService>(
              builder: (context, eventService, child) {
                final carpools = eventService.getCarpoolsForEvent(widget.event.id);
                if (carpools.isEmpty) {
                  return Center(
                    child: Text(
                      'Henüz ulaşım paylaşımı yok.\nİlk paylaşımı sen yap!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: carpools.length,
                  itemBuilder: (context, index) {
                    return _buildCarpoolCard(carpools[index], eventService);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Add Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _showAddCarpoolDialog,
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              label: const Text('PAYLAŞIM OLUŞTUR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, CarpoolType type) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.2) : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarpoolCard(CarpoolModel carpool, MockEventService eventService) {
    final isOffer = carpool.type == CarpoolType.offer;
    final isFull = isOffer && carpool.availableSeats == 0;
    final isJoined = carpool.participants.any((u) => u.id == eventService.currentUser.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(carpool.creator.avatarUrl),
            radius: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      carpool.creator.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOffer ? Colors.blue.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isOffer ? 'ARAÇ' : 'YOLCU',
                        style: TextStyle(
                          color: isOffer ? Colors.blue : Colors.orange,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  carpool.note ?? '',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                if (isOffer) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.event_seat, size: 14, color: isFull ? Colors.red : Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        '${carpool.availableSeats} boş koltuk',
                        style: TextStyle(
                          color: isFull ? Colors.red : Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isOffer && carpool.creator.id != eventService.currentUser.id)
            ElevatedButton(
              onPressed: (isFull || isJoined) ? null : () => eventService.joinCarpool(widget.event.id, carpool.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: isJoined ? Colors.green : AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isJoined ? 'KATILDIN' : 'KATIL'),
            ),
        ],
      ),
    );
  }

  void _showAddCarpoolDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Ulaşım Paylaşımı Oluştur', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nereden kalkacaksınız? (örn: Kadıköy)',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_selectedType == CarpoolType.offer) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Kapasite:', style: TextStyle(color: AppColors.textPrimary)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white),
                        onPressed: () => setState(() => _capacity = (_capacity > 1) ? _capacity - 1 : 1),
                      ),
                      Text('$_capacity', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () => setState(() => _capacity = _capacity + 1),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İPTAL', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final eventService = context.read<MockEventService>();
              final newCarpool = CarpoolModel(
                id: DateTime.now().toString(),
                eventId: widget.event.id,
                creator: eventService.currentUser,
                type: _selectedType,
                note: _noteController.text,
                capacity: _selectedType == CarpoolType.offer ? _capacity : 0,
              );
              eventService.addCarpool(newCarpool);
              _noteController.clear();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('YAYINLA'),
          ),
        ],
      ),
    );
  }
}
