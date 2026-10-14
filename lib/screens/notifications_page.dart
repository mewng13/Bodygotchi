import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../theme.dart';

/// Notifications feed, backed by [AppState.notifications]. Opening the page
/// marks everything read (clears the red dot on the button).
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppStateScope.of(context).markAllNotificationsRead();
    });
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'reward':
        return Icons.monetization_on;
      case 'streak':
        return Icons.local_fire_department;
      case 'workout':
        return Icons.fitness_center;
      case 'like':
        return Icons.favorite;
      case 'level':
        return Icons.emoji_events;
      default:
        return Icons.notifications;
    }
  }

  String _ago(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final items = state.notifications;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('알림', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: items.isEmpty
          ? const Center(
              child: Text('아직 알림이 없어요.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final n = items[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppColors.cardDecoration(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.orangeSoft,
                        child: Icon(_iconFor(n.kind),
                            // Coin rewards use the same gold coin color as the
                            // main page's coin counter.
                            color: n.kind == 'reward'
                                ? const Color(0xFFF5B301)
                                : AppColors.orange,
                            size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(n.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14)),
                                ),
                                Text(_ago(n.dateIso),
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(n.body,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    height: 1.35)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
