import 'dart:convert';
import 'package:http/http.dart' as http;

class ThingSpeakData {
  final int flame;
  final int night;
  final int motion;
  final int sound;
  final int gas;
  final int score;
  final int ldr;
  final DateTime timestamp;

  ThingSpeakData({
    required this.flame,
    required this.night,
    required this.motion,
    required this.sound,
    required this.gas,
    required this.score,
    required this.ldr,
    required this.timestamp,
  });

  factory ThingSpeakData.fromJson(Map<String, dynamic> json) {
    return ThingSpeakData(
      flame: int.tryParse(json['field1'] ?? '0') ?? 0,
      night: int.tryParse(json['field2'] ?? '0') ?? 0,
      motion: int.tryParse(json['field3'] ?? '0') ?? 0,
      sound: int.tryParse(json['field4'] ?? '0') ?? 0,
      gas: int.tryParse(json['field5'] ?? '0') ?? 0,
      score: int.tryParse(json['field6'] ?? '0') ?? 0,
      ldr: int.tryParse(json['field7'] ?? '0') ?? 0,
      timestamp: DateTime.parse(json['created_at']),
    );
  }
}

class ThingSpeakService {
  static const String channelId = "3385114";
  static const String readKey = "251S5RGIDR1V2SFH";

  Future<ThingSpeakData?> fetchLatestData() async {
    final url = Uri.parse(
        'https://api.thingspeak.com/channels/$channelId/feeds.json?api_key=$readKey&results=1');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['feeds'] != null && data['feeds'].isNotEmpty) {
          return ThingSpeakData.fromJson(data['feeds'][0]);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching ThingSpeak data: $e');
      return null;
    }
  }

  Future<List<ThingSpeakData>> fetchHistory({int results = 100}) async {
    final url = Uri.parse(
        'https://api.thingspeak.com/channels/$channelId/feeds.json?api_key=$readKey&results=$results');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['feeds'] != null) {
          return (data['feeds'] as List)
              .map((feed) => ThingSpeakData.fromJson(feed))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching ThingSpeak history: $e');
      return [];
    }
  }
}
