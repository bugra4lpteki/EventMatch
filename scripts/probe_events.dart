import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://pqtpogebnfubrqowlnkq.supabase.co/rest/v1/events?limit=1');
  final res = await http.get(url, headers: {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBxdHBvZ2VibmZ1YnJxb3dsbmtxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwNjM4NjMsImV4cCI6MjEwMDYzOTg2M30.jHzTJadRqvmrlGGjkFZ9qNUKNi_2CatfBGUxCZ_cn6o',
  });
  print('STATUS: ${res.statusCode}');
  print('BODY: ${res.body}');
}
