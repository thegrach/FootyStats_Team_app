# FootyStats Team App Analysis

## Overview
This is a Flutter application designed to record team-based AFL (Australian Football League) stats in real-time. It tracks various performance metrics for two competing teams (Team A and Team B) across four quarters.

## Project Structure
- **Framework:** Flutter (Dart)
- **Main Codebase:** `lib/main.dart` (Monolithic structure, ~700 lines)
- **Key Dependencies:** 
  - `csv`: For exporting match data.
  - `permission_handler`: For managing storage permissions on Android.
  - `path_provider`: For accessing local file storage to save match state.

## Core Features
1. **Real-Time Recording (`RecordingScreen`):**
   - Global timer to track match time.
   - Buttons to increment stats for 9 categories: Stoppage Clearances, Centre Clearances, Inside 50s, Free Kicks, Contested Possessions, Uncontested Possessions, Turnovers, Marks, Tackles.
   - Real-time display of differentials (Last 5 mins, Quarter, Match).
   - Allows renaming of "Team A" and "Team B".
2. **Match Summary (`SummaryScreen`):**
   - Displays aggregated stats.
   - Can filter by specific quarters (Q1, Q2, Q3, Q4) or view the entire match.
3. **Data Persistence & Export:**
   - Automatically saves events to `match_data.json` in the app's document directory.
   - Supports exporting full event logs and quarterly summaries to a CSV file in the Android `Downloads` directory.

## Architecture & State Management
- **State Management:** Uses basic `setState` and global variables (`globalTimer`, `eventLog`, `globalIsRunning`).
- **Data Model:** `StatEvent` class represents a single recorded statistic (category, team, quarter, timestamp).
- **UI Updates:** A `Timer.periodic` triggers `setState` every second in the `RecordingScreen` to keep the UI timer and differentials updated.

## Potential Areas for Improvement (For Future Reference)
1. **Refactoring:** The `main.dart` file is monolithic. It should be split into separate files (e.g., `models/`, `screens/`, `widgets/`, `services/`).
2. **State Management:** Moving away from global variables to a structured state management solution like `Provider`, `Riverpod`, or `Bloc` would make the app more scalable and testable.
3. **Hardcoded Paths:** CSV export currently uses a hardcoded path `/storage/emulated/0/Download`, which is Android-specific and might fail on certain devices or platforms (iOS, Web, Desktop). This should ideally use `path_provider` or `file_saver`.
4. **Settings Screen (Category Customization):** Implement the placeholder `SettingsScreen` to allow users to add, remove, or modify the statistical categories being recorded.
5. **Timer Logic & Video Sync:** The current timer relies on a 1-second periodic tick. Upgrading to a timestamp-based approach (calculating `DateTime.now().difference(startTime)`) will improve accuracy. This is critical because a planned feature is to export an action-time log to synchronize stats with video recordings (e.g., jumping to the exact video timestamp when a tackle occurred).
