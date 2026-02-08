import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  // Your API URL
  static const String _baseUrl = 'https://py-patgpt.globalspace.in/ask';

  Stream<String> streamResponse(String query) async* {
    try {
      final uri = Uri.parse('$_baseUrl?question=${Uri.encodeComponent(query)}');

      final client = http.Client();
      final request = http.Request('GET', uri);

      request.headers.addAll({
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
      });

      final response = await client.send(request);

      if (response.statusCode == 200) {
        // 1. Decode bytes to text
        // 2. Split text into separate lines
        final stream = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        await for (final line in stream) {
          // 1. Ignore "ping" lines which start with ": ping"
          if (line.trim().startsWith(':')) continue;

          // 2. Process data lines
          if (line.startsWith('data:')) {
            final jsonString = line.substring(5).trim();
            if (jsonString.isEmpty) continue;

            try {
              final Map<String, dynamic> data = jsonDecode(jsonString);

              // 3. Extract content
              if (data.containsKey('content') && data['content'] != null) {
                yield data['content'].toString();
              }

              // 4. Handle Close Event
              if (data.containsKey('message') &&
                  data['message'] == 'Stream completed') {
                break; // Stop listening
              }
            } catch (e) {
              // Ignore parse errors for keep-alive packets
            }
          }
        }
      } else {
        yield "Error: Server responded with status ${response.statusCode}";
      }
    } catch (e) {
      yield "Error: Connection failed ($e)";
    }
  }
}
