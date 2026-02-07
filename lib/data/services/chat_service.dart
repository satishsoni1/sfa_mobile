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
          // Check if the line contains data
          if (line.startsWith('data:')) {
            final jsonString = line
                .substring(5)
                .trim(); // Remove 'data:' prefix

            // Skip empty data or keep-alive messages
            if (jsonString.isEmpty) continue;

            try {
              final Map<String, dynamic> data = jsonDecode(jsonString);

              // Extract the actual content text
              if (data.containsKey('content') && data['content'] != null) {
                yield data['content'].toString();
              }

              // Handle stream completion signal if your API sends it
              if (data.containsKey('message') &&
                  data['message'] == 'Stream completed') {
                break;
              }
            } catch (e) {
              // Ignore parsing errors for non-JSON lines (like simple keep-alives)
              print("Error parsing line: $e");
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
