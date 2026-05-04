class StatEvent {
  final String category;
  final String team;
  final String quarter;
  final String timestamp;
  final String? realTime;

  StatEvent({
    required this.category,
    required this.team,
    required this.quarter,
    required this.timestamp,
    this.realTime,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'team': team,
        'quarter': quarter,
        'timestamp': timestamp,
        'realTime': realTime,
      };

  factory StatEvent.fromJson(Map<String, dynamic> json) => StatEvent(
        category: json['category'],
        team: json['team'],
        quarter: json['quarter'],
        timestamp: json['timestamp'],
        realTime: json['realTime'],
      );

  List<String> toCsvRow() => [team, category, quarter, timestamp, realTime ?? ''];
}
