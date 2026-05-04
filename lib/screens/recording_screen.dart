import 'dart:async';
import 'package:flutter/material.dart';
import '../globals.dart';
import '../models/stat_event.dart';
import '../services/storage_service.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({Key? key}) : super(key: key);

  @override
  RecordingScreenState createState() => RecordingScreenState();
}

class RecordingScreenState extends State<RecordingScreen> {
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
    globalIsRunning = true;
    lastStartTime = DateTime.now();
    if (mounted) setState(() {});
  }

  void _pauseTimer() {
    if (lastStartTime != null) {
      totalElapsedSecondsBeforeLastStart += DateTime.now().difference(lastStartTime!).inSeconds;
      lastStartTime = null;
    }
    globalIsRunning = false;
    if (mounted) setState(() {});
  }

  void _resetTimer() {
    totalElapsedSecondsBeforeLastStart = 0;
    lastStartTime = null;
    globalIsRunning = false;
    if (mounted) setState(() {});
  }

  void refreshCategories() {
    setState(() {
      for (var category in statCategories) {
        if (!statCounts.containsKey(category)) {
          statCounts[category] = {'A': 0, 'B': 0};
        }
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getEventTimestamp() {
    int eventSeconds = globalElapsedSeconds - 2;
    if (eventSeconds < 0) eventSeconds = 0;
    return _formatTime(eventSeconds);
  }

  String _getRealTimestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
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

  Future<void> _loadEventLogFromFile() async {
    final loadedEvents = await StorageService.loadEventLogFromFile();
    if (loadedEvents.isNotEmpty) {
      setState(() {
        eventLog = loadedEvents;
        for (var category in statCategories) {
          statCounts[category]!['A'] = eventLog.where((e) => e.category == category && e.team == 'A').length;
          statCounts[category]!['B'] = eventLog.where((e) => e.category == category && e.team == 'B').length;
        }
      });
    }
  }

  Future<void> _clearEventLogFile() async {
    await StorageService.clearEventLogFile();
    setState(() {
      eventLog.clear();
      for (var category in statCategories) {
        statCounts[category]!['A'] = 0;
        statCounts[category]!['B'] = 0;
      }
    });
  }

  Future<void> exportToCsv() async {
    String? message = await StorageService.exportToCsv();
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> exportQuarterlySummaryToCsv() async {
    String? message = await StorageService.exportQuarterlySummaryToCsv();
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
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
            onChanged: globalIsRunning ? null : (String? newValue) {
              setState(() {
                selectedQuarter = newValue!;
                _resetTimer();
              });
            },
            items: quarters.map((quarter) => DropdownMenuItem(value: quarter, child: Text(quarter))).toList(),
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
                                      timestamp: _getEventTimestamp(),
                                      realTime: _getRealTimestamp(),
                                    ));
                                    StorageService.saveEventLogToFile();
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
                                      timestamp: _getEventTimestamp(),
                                      realTime: _getRealTimestamp(),
                                    ));
                                    StorageService.saveEventLogToFile();
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
                              fontSize: 12,
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
                                text: '     Qtr: ',
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
