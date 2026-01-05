import 'package:flutter/material.dart';
import 'flights_list_screen.dart';
import 'airports_screen.dart';
import 'announcements_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const FlightsListScreen(),
    const AirportsScreen(),
    const AnnouncementsScreen(),
    const ProfileScreen(),
  ];

  final List<BottomNavigationBarItem> _navItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.flight_takeoff),
      label: 'Рейсы',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.flight),
      label: 'Аэропорты',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.announcement),
      label: 'Объявления',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: 'Профиль',
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey[400],
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: _navItems,
        ),
      ),
    );
  }
}
