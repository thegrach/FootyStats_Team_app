import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:csv/csv.dart';


void main() {
  runApp(TeamStatsApp());
}

// Global timer state
Timer? globalTimer;
int globalElapsedSeconds = 0;
bool globalIsRunning = false;

// Global key to allow UI update in RecordingScreen
final GlobalKey<_RecordingScreenState> recordingScreenKey = GlobalKey<_RecordingScreenState>();

class StatEvent {
  final String category;
  final String team;
  final String quarter;
  final String timestamp;

  StatEvent({
    required this.category,
    required this.team,
    required this.quarter,
    required this.timestamp,
  });

  List<String> toCsvRow() {
    return [team, category, quarter, timestamp];
  }

  Map<String, dynamic> toJson() => {
    'category': category,
    'team': team,
    'quarter': quarter,
    'timestamp': timestamp,
  };

  factory StatEvent.fromJson(Map<String, dynamic> json) {
    return StatEvent(
      category: json['category'],
      team: json['team'],
      quarter: json['quarter'],
      timestamp: json['timestamp'],
    );
  }
}


List<StatEvent> eventLog = [];

String teamAName = 'Team A';
String teamBName = 'Team B';

final List<String> statCategories = [
  'Stoppage Clearances',
  'Centre Clearances',
  'Inside 50s',
  'Free Kicks',
  'Contested Possessions',
  'Uncontested Possessions',
  'Turnovers',
  'Marks',
  'Tackles',
];

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

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    RecordingScreen(key: recordingScreenKey),
    SummaryScreen(),
    SettingsScreen(),
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
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Record'),
          BottomNavigationBarItem(icon: Icon(Icons.summarize), label: 'Summary'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({Key? key}) : super(key: key);

  @override
  _RecordingScreenState createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  String selectedQuarter = 'Q1';
  final List<String> quarters = ['Q1', 'Q2', 'Q3', 'Q4'];
  Map<String, Map<String, int>> statCounts = {};
  Timer? _uiRefreshTimer;

  @override
  void initState() {
    super.initState();

    for (var category in statCategories) {
      statCounts[category] = {'A': 0, 'B': 0};
    }

    // Start UI refresh timer
    _uiRefreshTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Restart global timer if it was running
    if (globalIsRunning && globalTimer == null) {
      _startTimer();
    }
    _loadEventLogFromFile();
  }


  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (globalTimer != null && globalTimer!.isActive) return;

    globalIsRunning = true;
    globalTimer = Timer.periodic(Duration(seconds: 1), (_) {
      globalElapsedSeconds++;
    });
  }

  void _pauseTimer() {
    globalTimer?.cancel();
    globalIsRunning = false;
  }

  void _resetTimer() {
    globalTimer?.cancel();
    globalElapsedSeconds = 0;
    globalIsRunning = false;
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDiff(int value) => value >= 0 ? '+$value' : '$value';

  Color _getDiffColor(int value) {
    if (value > 0) return Colors.green;
    if (value < 0) return Colors.red;
    return Colors.black87;
  }

  int getLast5MinDifferential(String category) {
    final currentTime = globalElapsedSeconds;
    final fiveMinutesAgo = currentTime - 300;
    int teamACount = 0;
    int teamBCount = 0;

    for (var event in eventLog.reversed) {
      final parts = event.timestamp.split(':');
      final seconds = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      if (seconds < fiveMinutesAgo) break;
      if (event.category == category) {
        if (event.team == 'A') teamACount++;
        if (event.team == 'B') teamBCount++;
      }
    }

    return teamACount - teamBCount;
  }

  int getQuarterDifferential(String category) {
    int teamACount = 0;
    int teamBCount = 0;

    for (var event in eventLog) {
      if (event.quarter != selectedQuarter) continue;
      if (event.category == category) {
        if (event.team == 'A') teamACount++;
        if (event.team == 'B') teamBCount++;
      }
    }

    return teamACount - teamBCount;
  }

  Future<String> _getEventFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/match_data.json';
  }

  Future<void> _saveEventLogToFile() async {
    final file = File(await _getEventFilePath());
    final jsonList = eventLog.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  Future<bool> _requestStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    // Try for manage permission (Android 11+)
    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    // Fallback to regular storage permission (Android 10 and below)
    status = await Permission.storage.request();
    return status.isGranted;
  }


  Future<void> _loadEventLogFromFile() async {
    try {
      final file = File(await _getEventFilePath());
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        setState(() {
          eventLog = jsonList.map((e) => StatEvent.fromJson(e)).toList();
          for (var category in statCategories) {
            statCounts[category]!['A'] = eventLog.where((e) => e.category == category && e.team == 'A').length;
            statCounts[category]!['B'] = eventLog.where((e) => e.category == category && e.team == 'B').length;
          }
        });
      }
    } catch (e) {
      print("Error loading saved data: $e");
    }
  }

  Future<void> _clearEventLogFile() async {
    final file = File(await _getEventFilePath());
    if (await file.exists()) await file.delete();
    setState(() {
      eventLog.clear();
      for (var category in statCategories) {
        statCounts[category]!['A'] = 0;
        statCounts[category]!['B'] = 0;
      }
    });
  }


  Future<void> exportToCsv() async {
    // For Android 11+, use MANAGE_EXTERNAL_STORAGE
    if (Platform.isAndroid && await Permission.manageExternalStorage.isDenied) {
      // Request permission via system settings
      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage permission not granted')),
        );
        return;
      }
    }

    final downloadsDir = Directory('/storage/emulated/0/Download');
    final file = File('${downloadsDir.path}/team_stats_log.csv');

    List<List<String>> rows = [
      ['Team', 'Category', 'Quarter', 'Timestamp'],
      ...eventLog.map((e) => e.toCsvRow()),
    ];

    await file.writeAsString(const ListToCsvConverter().convert(rows));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported to Downloads: ${file.path}')),
    );
  }

  Future<void> exportQuarterlySummaryToCsv() async {
    if (!await _requestStoragePermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Storage permission not granted')),
      );
      return;
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Quarterly summary exported to Downloads: ${file.path}')),
    );
  }

  void _showTeamNameDialog() {
    final aController = TextEditingController(text: teamAName);
    final bController = TextEditingController(text: teamBName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Team Names'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: aController, decoration: InputDecoration(labelText: 'Team A Name')),
            TextField(controller: bController, decoration: InputDecoration(labelText: 'Team B Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                teamAName = aController.text.trim();
                teamBName = bController.text.trim();
              });
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Team Stats Recorder'),
        actions: [
          DropdownButton<String>(
            value: selectedQuarter,
            underline: SizedBox(),
            onChanged: (String? newValue) {
              setState(() {
                selectedQuarter = newValue!;
              });
            },
            items: ['Q1', 'Q2', 'Q3', 'Q4'].map((quarter) => DropdownMenuItem(value: quarter, child: Text(quarter))).toList(),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.file_download),
            tooltip: 'Export CSV',
            onSelected: (value) {
              if (value == 'full') {
                exportToCsv();
              } else if (value == 'summary') {
                exportQuarterlySummaryToCsv();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'full',
                child: Text('Export Full Event Log'),
              ),
              const PopupMenuItem<String>(
                value: 'summary',
                child: Text('Export Quarterly Summary'),
              ),
            ],
          ),

          IconButton(icon: Icon(Icons.edit), tooltip: 'Edit Team Names', onPressed: _showTeamNameDialog),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                Text('Time: ${_formatTime(globalElapsedSeconds)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Spacer(),
                IconButton(icon: Icon(Icons.play_arrow), onPressed: globalIsRunning ? null : _startTimer, tooltip: 'Start'),
                IconButton(icon: Icon(Icons.pause), onPressed: globalIsRunning ? _pauseTimer : null, tooltip: 'Pause'),
                IconButton(icon: Icon(Icons.stop), onPressed: _resetTimer, tooltip: 'Reset'),
                IconButton(
                  icon: Icon(Icons.refresh),
                  tooltip: 'New Game',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text("Start New Game?"),
                        content: Text("This will clear all stats and reset the timer."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () {
                              _clearEventLogFile();
                              _resetTimer();
                              Navigator.pop(context);
                            },
                            child: Text("Confirm"),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              ],
            ),
          ),
          Divider(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('Stat')),
                Expanded(child: Center(child: Text(teamAName, style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text(teamBName, style: TextStyle(fontWeight: FontWeight.bold)))),
              ],
            ),
          ),
          Divider(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: statCategories.length,
              itemBuilder: (context, index) {
                final category = statCategories[index];
                final teamACount = statCounts[category]!['A']!;
                final teamBCount = statCounts[category]!['B']!;
                final matchDiff = teamACount - teamBCount;
                final last5MinDiff = getLast5MinDifferential(category);
                final quarterDiff = getQuarterDifferential(category);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              category,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    statCounts[category]!['A'] = teamACount + 1;
                                    eventLog.add(StatEvent(
                                      category: category,
                                      team: 'A',
                                      quarter: selectedQuarter,
                                      timestamp: _formatTime(globalElapsedSeconds),
                                    ));
                                    _saveEventLogToFile(); // <- ADD THIS LINE

                                  });
                                },
                                style: ElevatedButton.styleFrom(minimumSize: Size(32, 32), padding: EdgeInsets.zero, shape: CircleBorder()),
                                child: Icon(Icons.add, size: 18),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    statCounts[category]!['B'] = teamBCount + 1;
                                    eventLog.add(StatEvent(
                                      category: category,
                                      team: 'B',
                                      quarter: selectedQuarter,
                                      timestamp: _formatTime(globalElapsedSeconds),
                                    ));
                                  });
                                },
                                style: ElevatedButton.styleFrom(minimumSize: Size(32, 32), padding: EdgeInsets.zero, shape: CircleBorder()),
                                child: Icon(Icons.add, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 6.0, top: 0),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 12, // ⬆️ Increased font size from 10 to 12
                              fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                            ),
                            children: [
                              TextSpan(
                                text: 'Last 5m: ',
                                style: TextStyle(color: Colors.black87),
                              ),
                              TextSpan(
                                text: _formatDiff(last5MinDiff),
                                style: TextStyle(color: _getDiffColor(last5MinDiff)),
                              ),
                              TextSpan(
                                text: '     Qtr: ', // ⬅️ extra spacing for even layout
                                style: TextStyle(color: Colors.black87),
                              ),
                              TextSpan(
                                text: _formatDiff(quarterDiff),
                                style: TextStyle(color: _getDiffColor(quarterDiff)),
                              ),
                              TextSpan(
                                text: '     Match: ',
                                style: TextStyle(color: Colors.black87),
                              ),
                              TextSpan(
                                text: _formatDiff(matchDiff),
                                style: TextStyle(color: _getDiffColor(matchDiff)),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Divider(height: 6),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryScreen extends StatefulWidget {
  @override
  _SummaryScreenState createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  String selectedQuarter = 'All';
  List<String> get quarters => ['All', 'Q1', 'Q2', 'Q3', 'Q4'];

  int getStatTotal(String category, String team, String quarter) {
    final isAll = quarter == 'All';
    return eventLog.where((event) => event.category == category && event.team == team && (isAll || event.quarter == quarter)).length;
  }

  Color _getDiffColor(int value) {
    if (value > 0) return Colors.green;
    if (value < 0) return Colors.red;
    return Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stat Summary'),
        actions: [
          DropdownButton<String>(
            value: selectedQuarter,
            underline: SizedBox(),
            onChanged: (String? newValue) {
              setState(() {
                selectedQuarter = newValue!;
              });
            },
            items: quarters.map((quarter) => DropdownMenuItem(value: quarter, child: Text(quarter))).toList(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(flex: 3, child: Text('Stat', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text(teamAName, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text(teamBName, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text('+/-', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            Divider(),
            ...statCategories.map((category) {
              final aTotal = getStatTotal(category, 'A', selectedQuarter);
              final bTotal = getStatTotal(category, 'B', selectedQuarter);
              final diff = aTotal - bTotal;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(category, overflow: TextOverflow.ellipsis)),
                    Expanded(child: Text('$aTotal', textAlign: TextAlign.center)),
                    Expanded(child: Text('$bTotal', textAlign: TextAlign.center)),
                    Expanded(
                      child: Text(
                        diff >= 0 ? '+$diff' : '$diff',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _getDiffColor(diff)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Settings screen (coming soon)',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
