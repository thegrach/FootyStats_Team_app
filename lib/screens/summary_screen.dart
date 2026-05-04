import 'package:flutter/material.dart';
import '../globals.dart';

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
