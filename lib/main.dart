import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'services/storage_service.dart';
import 'globals.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final loadedCategories = await StorageService.loadCategories();
  if (loadedCategories != null && loadedCategories.isNotEmpty) {
    statCategories = loadedCategories;
  }
  runApp(TeamStatsApp());
}

class TeamStatsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FootyStats Team',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MainScreen(),
    );
  }
}
