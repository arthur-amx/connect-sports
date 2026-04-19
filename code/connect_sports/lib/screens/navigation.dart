import 'package:connect_sports/screens/home/home_screen.dart';
import 'package:connect_sports/screens/usuario/detalhes.dart';
import 'package:connect_sports/screens/eventos/evento.dart';
import 'package:flutter/material.dart';

class NavigationConnect extends StatefulWidget {
  const NavigationConnect({Key? key}) : super(key: key);

  @override
  _NavigationConnectScreenState createState() => _NavigationConnectScreenState();
}

class _NavigationConnectScreenState extends State<NavigationConnect> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    AthleteProfileScreen(),
    EventoScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget currentScreen;

    switch (_selectedIndex) {
      case 0:
        currentScreen = const HomeScreen();
        break;
      case 1:
        currentScreen = AthleteProfileScreen();
        break;
      case 2:
        currentScreen = EventoScreen();
        break;
      default:
        currentScreen = const HomeScreen();
    }

    return Scaffold(
      body: currentScreen, // Recria a tela com base no índice selecionado
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        unselectedItemColor: Colors.grey,
        selectedItemColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Eventos'),
        ],
        onTap: _onItemTapped,
      ),
    );
  }
}