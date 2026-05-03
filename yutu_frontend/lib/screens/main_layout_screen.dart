import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'home_screen.dart';
import 'profile_screen.dart';
import 'activity_screen.dart'; 
import 'inbox_screen.dart'; 
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    
    _loadSavedTab();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token != null) {
        Provider.of<ChatProvider>(context, listen: false).connectWebSocket(token);
      }
    });
  }

// used for: when after reload opens saved screen
  Future<void> _loadSavedTab() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('saved_tab_index') ?? 0;
    if (mounted) {
      setState(() {
        _currentIndex = savedIndex;
      });
    }
  }
  

  @override
  Widget build(BuildContext context) {
    context.locale;
    final isAuthenticated = Provider.of<AuthProvider>(context).isAuthenticated;

    final List<Widget> screens = isAuthenticated
        ? [HomeScreen(), InboxScreen(), ActivityScreen(), ProfileScreen()]
        : [HomeScreen(), ProfileScreen()];

    final List<BottomNavigationBarItem> navItems = isAuthenticated
        ? [
            BottomNavigationBarItem(icon: const Icon(Icons.home_filled), label: 'feed_tab'.tr()),
            BottomNavigationBarItem(icon: const Icon(Icons.chat_bubble_outline), activeIcon: const Icon(Icons.chat_bubble), label: 'inbox_tab'.tr()),
            BottomNavigationBarItem(icon: const Icon(Icons.receipt_long_outlined), activeIcon: const Icon(Icons.receipt_long), label: 'activity_tab'.tr()),
            BottomNavigationBarItem(icon: const Icon(Icons.person_outline), activeIcon: const Icon(Icons.person), label: 'profile_tab'.tr()),
          ]
        : [
            BottomNavigationBarItem(icon: const Icon(Icons.home_filled), label: 'feed_tab'.tr()),
            BottomNavigationBarItem(icon: const Icon(Icons.person_outline), activeIcon: const Icon(Icons.person), label: 'profile_tab'.tr()),
          ];

    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
          ]
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) async {
            setState(() {
              _currentIndex = index;
            });
            // ---  SAVE THE TAB INDEX WHEN CLICKED ---
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('saved_tab_index', index);
            // ------------------------------------------
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.deepPurple,
          unselectedItemColor: Colors.grey.shade400,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          elevation: 0,
          items: navItems,
        ),
      ),
    );
  }
}