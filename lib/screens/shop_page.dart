import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../services/auth_service.dart';
import '../services/local_db.dart';
import '../theme.dart';

/// The coin used across the app (matches the main-page coin counter).
const _coinColor = Color(0xFFF5B301);
Widget _coin(double size) =>
    Icon(Icons.monetization_on, color: _coinColor, size: size);

class _ShopItem {
  const _ShopItem(this.emoji, this.name, this.desc, this.price,
      {this.available = false});
  final String emoji;
  final String name;
  final String desc;
  final int price;
  final bool available;
}

/// Coin shop. Only the streak-recovery ticket is available for now; the rest
/// are "상품 준비중" (coming soon).
class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  static const int ticketPrice = 200;

  static const List<_ShopItem> _items = [
    _ShopItem('🎟️', '연속기록 지키기 티켓', '깨진 연속 기록을 하루 되살려줘요', ticketPrice,
        available: true),
    _ShopItem('🔥', '불꽃 이펙트', '상품 준비중', 300),
    _ShopItem('👟', '러닝화 스킨', '상품 준비중', 250),
    _ShopItem('🎽', '유니폼 세트', '상품 준비중', 400),
    _ShopItem('🏅', '골드 메달 배지', '상품 준비중', 500),
    _ShopItem('🌈', '무지개 배경', '상품 준비중', 350),
  ];

  void _buyTicket(BuildContext context, AppState state) {
    final ok = state.buyStreakTicket(ticketPrice);
    if (ok) {
      final user = AuthService.instance.currentUser;
      if (user != null) {
        LocalDb.instance.saveProfile(user.id, state.toPersistedMap());
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? '연속기록 지키기 티켓을 구매했어요! 🎟️ (보유 ${state.streakTickets}장)'
            : '코인이 부족해요.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('상점', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _coin(18),
                  const SizedBox(width: 6),
                  Text('${state.coins}',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final it = _items[i];
          return _ItemRow(
            item: it,
            owned: it.available ? state.streakTickets : 0,
            affordable: state.coins >= it.price,
            onBuy: it.available ? () => _buyTicket(context, state) : null,
          );
        },
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.owned,
    required this.affordable,
    required this.onBuy,
  });
  final _ShopItem item;
  final int owned;
  final bool affordable;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final available = item.available;
    return Opacity(
      opacity: available ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppColors.cardDecoration(),
        child: Row(
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(item.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                      if (available && owned > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.orangeSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('보유 $owned',
                              style: const TextStyle(
                                  color: AppColors.orangeDark,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(item.desc,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (available)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      affordable ? AppColors.orange : AppColors.track,
                  foregroundColor:
                      affordable ? Colors.white : AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onBuy,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _coin(15),
                    const SizedBox(width: 4),
                    Text('${item.price}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.track,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('준비중',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
