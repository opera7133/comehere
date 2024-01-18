import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import './google_map.dart';
import './group.dart';
import './profile.dart';

class HomePage extends StatefulWidget {
  final User? user;
  const HomePage({Key? key, this.user}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  _HomePageState();

  int _selectedIndex = 0;
  late User? user;

  // ホーム画面の中身
  List<Widget> _widgetOptions() => <Widget>[
        MapsPage(user: user),
        GroupPage(user: user),
        ProfilePage(user: user),
      ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    setState(() {
      user = widget.user;
    });
  }

  // ホーム画面の作成
  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = _widgetOptions();
    return Scaffold(
      body: Center(
        child: widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: NavigationBar(
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.map),
            label: 'マップ',
          ),
          NavigationDestination(
            icon: Icon(Icons.group),
            label: 'グループ',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'プロフィール',
          ),
        ],
        onDestinationSelected: _onItemTapped,
        selectedIndex: _selectedIndex,
      ),
    );
  }
}
