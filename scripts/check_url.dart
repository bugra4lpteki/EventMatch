import 'package:http/http.dart' as http;

void main() async {
  final client = http.Client();
  final response = await client.send(http.Request('GET', Uri.parse('https://biletinial.com/tr-tr/muzik/levent-yuksel'))..followRedirects = false);
  print('STATUS: ${response.statusCode}');
  print('LOCATION: ${response.headers['location']}');
}
