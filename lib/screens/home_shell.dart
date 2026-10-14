import 'package:flutter/material.dart';

import '../theme.dart';
import 'chatbot_page.dart';
import 'diet_page.dart';
import 'discussion_page.dart';
import 'league_page.dart';
import 'main_page.dart';

/// Root shell hosting the five bottom-navigation sections. The main page sits
/// in the centre slot (index 2), Clash-Royale style. Switching tabs slides the
/// pages horizontally, and the pages can also be swiped directly.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const int _initialIndex = 2; // Start on the main page (centre).

  final PageController _controller =
      PageController(initialPage: _initialIndex);
  int _index = _initialIndex;

  final _pages = const [
    DietPage(),
    DiscussionPage(),
    MainPage(),
    LeaguePage(),
    ChatbotPage(),
  ];

  void _goTo(int i) {
    // Update the highlighted tab immediately so the icon reacts instantly,
    // then run a short slide. Jumping adjacent pages first keeps the slide
    // distance (and duration) short even when tapping a far-away tab.
    setState(() => _index = i);
    if ((_controller.page ?? _index).round() != i) {
      final from = (_controller.page ?? _index).round();
      if ((from - i).abs() > 1) {
        _controller.jumpToPage(i > from ? i - 1 : i + 1);
      }
    }
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _controller,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (i) => setState(() => _index = i),
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            indicatorColor: AppColors.orangeSoft,
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _goTo,
            height: 68,
            labelBehavior:
                NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.restaurant_menu_outlined,
                    color: AppColors.textSecondary),
                selectedIcon:
                    Icon(Icons.restaurant_menu, color: AppColors.orange),
                label: '식단',
              ),
              NavigationDestination(
                icon: Icon(Icons.forum_outlined,
                    color: AppColors.textSecondary),
                selectedIcon: Icon(Icons.forum, color: AppColors.orange),
                label: '게시판',
              ),
              NavigationDestination(
                icon: Icon(Icons.home_outlined,
                    color: AppColors.textSecondary),
                selectedIcon: Icon(Icons.home, color: AppColors.orange),
                label: '홈',
              ),
              NavigationDestination(
                icon: Icon(Icons.emoji_events_outlined,
                    color: AppColors.textSecondary),
                selectedIcon:
                    Icon(Icons.emoji_events, color: AppColors.orange),
                label: '리그',
              ),
              NavigationDestination(
                icon: Icon(Icons.smart_toy_outlined,
                    color: AppColors.textSecondary),
                selectedIcon: Icon(Icons.smart_toy, color: AppColors.orange),
                label: 'AI 코치',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
