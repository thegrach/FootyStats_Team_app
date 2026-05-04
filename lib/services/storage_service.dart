import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:csv/csv.dart';
import '../models/stat_event.dart';
import '../globals.dart';

class StorageService {
  static Future<String> getEventFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/match_data.json';
  }

  static Future<void> saveEventLogToFile() async {
    final file = File(await getEventFilePath());
    final jsonList = eventLog.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  static Future<bool> requestStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    // Try for manage permission (Android 11+)
    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    // Fallback to regular storage permission (Android 10 and below)
    status = await Permission.storage.request();
    return status.isGranted;
  }

  static Future<List<StatEvent>> loadEventLogFromFile() async {
    try {
      final file = File(await getEventFilePath());
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        return jsonList.map((e) => StatEvent.fromJson(e)).toList();
      }
    } catch (e) {
      print("Error loading saved data: $e");
    }
    return [];
  }

  static Future<void> clearEventLogFile() async {
    final file = File(await getEventFilePath());
    if (await file.exists()) await file.delete();
  }

  static Future<String> getCategoriesFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/categories.json';
  }

  static Future<void> saveCategories(List<String> categories) async {
    final file = File(await getCategoriesFilePath());
    await file.writeAsString(jsonEncode(categories));
  }

  static Future<List<String>?> loadCategories() async {
    try {
      final file = File(await getCategoriesFilePath());
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        return jsonList.cast<String>();
      }
    } catch (e) {
      print("Error loading categories: $e");
    }
    return null;
  }

  static Future<String?> exportToCsv() async {
    if (Platform.isAndroid && await Permission.manageExternalStorage.isDenied) {
      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        return 'Storage permission not granted';
      }
    }

    final downloadsDir = Directory('/storage/emulated/0/Download');
    final file = File('${downloadsDir.path}/team_stats_log.csv');

    List<List<String>> rows = [
      ['Team', 'Category', 'Quarter', 'Match Time', 'Real Time'],
      ...eventLog.map((e) => e.toCsvRow()),
    ];

    await file.writeAsString(const ListToCsvConverter().convert(rows));
    return 'Exported to Downloads: ${file.path}';
  }

  static Future<String?> exportQuarterlySummaryToCsv() async {
    if (!await requestStoragePermission()) {
      return 'Storage permission not granted';
    }

    List<List<String>> rows = [];

    rows.add([
      'Stat',
      '$teamAName Q1', '$teamAName Q2', '$teamAName Q3', '$teamAName Q4', '$teamAName Total',
      '$teamBName Q1', '$teamBName Q2', '$teamBName Q3', '$teamBName Q4', '$teamBName Total',
      'Differential'
    ]);

    for (var category in statCategories) {
      List<int> aQuarter = [0, 0, 0, 0];
      List<int> bQuarter = [0, 0, 0, 0];

      for (var event in eventLog) {
        if (event.category != category) continue;
        int index = ['Q1', 'Q2', 'Q3', 'Q4'].indexOf(event.quarter);
        if (index == -1) continue;

        if (event.team == 'A') aQuarter[index]++;
        if (event.team == 'B') bQuarter[index]++;
      }

      int aTotal = aQuarter.reduce((a, b) => a + b);
      int bTotal = bQuarter.reduce((a, b) => a + b);
      int diff = aTotal - bTotal;

      rows.add([
        category,
        '${aQuarter[0]}', '${aQuarter[1]}', '${aQuarter[2]}', '${aQuarter[3]}', '$aTotal',
        '${bQuarter[0]}', '${bQuarter[1]}', '${bQuarter[2]}', '${bQuarter[3]}', '$bTotal',
        diff >= 0 ? '+$diff' : '$diff'
      ]);
    }

    final downloadsDir = Directory('/storage/emulated/0/Download');
    final file = File('${downloadsDir.path}/quarterly_summary.csv');
    await file.writeAsString(const ListToCsvConverter().convert(rows));

    return 'Quarterly summary exported to Downloads: ${file.path}';
  }
}
