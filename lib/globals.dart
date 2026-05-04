import 'dart:async';
import 'package:flutter/material.dart';
import 'models/stat_event.dart';

// Global timer state
Timer? globalTimer;
int globalElapsedSeconds = 0;
bool globalIsRunning = false;

// Global key to allow UI update in RecordingScreen
final GlobalKey recordingScreenKey = GlobalKey();

List<StatEvent> eventLog = [];

String teamAName = 'Team A';
String teamBName = 'Team B';

List<String> statCategories = [
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
