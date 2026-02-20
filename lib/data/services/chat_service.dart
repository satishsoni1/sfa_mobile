import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  static const String _baseUrl = 'https://py-patgpt.globalspace.in/ask';

  Stream<String> streamResponse(String query) async* {
    final uri = Uri.parse('$_baseUrl?question=${Uri.encodeComponent(query)}');
    final client = http.Client(); // Instantiate client
    final request = http.Request('GET', uri);

    request.headers.addAll({
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
    });

    try {
      final response = await client.send(request);

      if (response.statusCode == 200) {
        final stream = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        await for (final line in stream) {
          if (line.trim().startsWith(':')) continue;

          if (line.startsWith('data:')) {
            final jsonString = line.substring(5).trim();
            if (jsonString.isEmpty) continue;

            try {
              final Map<String, dynamic> data = jsonDecode(jsonString);

              if (data.containsKey('content') && data['content'] != null) {
                yield data['content'].toString();
              }

              if (data.containsKey('message') &&
                  data['message'] == 'Stream completed') {
                break;
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
    } finally {
      // CRITICAL: Always close the client to free up network resources
      client.close();
    }
  }
}
