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
