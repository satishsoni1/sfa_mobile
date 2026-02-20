import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

// ==========================================
// CHAT SERVICE (With Memory Leak Fix)
// ==========================================
class ChatService {
  static const String _baseUrl = 'https://py-patgpt.globalspace.in/ask';

  Stream<String> streamResponse(String query) async* {
    final uri = Uri.parse('$_baseUrl?question=${Uri.encodeComponent(query)}');
    final client = http.Client();
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
      // CRITICAL FIX: Close the client to prevent connection/memory leaks
      client.close();
    }
  }
}

// ==========================================
// CHAT SCREEN UI
// ==========================================
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final FocusNode _focusNode = FocusNode();

  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  bool _isSpeaking = false;
  late AnimationController _micPulseController;
  late AnimationController _typingIndicatorController;
  late AnimationController _fadeController;

  static final List<Map<String, String>> _sessionHistory = [];

  bool _isTyping = false;
  bool _stopRequested = false;
  bool _showScrollToBottom = false;

  final Color _primaryColor = const Color(0xFF6200EA);
  final Color _secondaryColor = const Color(0xFF9D4EDD);
  final Color _accentColor = const Color(0xFF00BFA5);

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initTts();

    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      lowerBound: 0.85,
      upperBound: 1.15,
    )..repeat(reverse: true);

    _typingIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final showButton = _scrollController.offset > 200;
      if (showButton != _showScrollToBottom) {
        setState(() => _showScrollToBottom = showButton);
      }
    }
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-IN");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);

    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _micPulseController.dispose();
    _typingIndicatorController.dispose();
    _fadeController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  String _processTextForSpeech(String markdown) {
    String cleanText = markdown;
    final tableRegex = RegExp(r'^\|.*\|$', multiLine: true);
    if (tableRegex.hasMatch(markdown)) {
      cleanText = cleanText.replaceAll(tableRegex, '');
      cleanText += ". I have displayed the detailed data in the table below.";
    }
    cleanText = cleanText.replaceAll(RegExp(r'[#*`_~]'), '');
    return cleanText;
  }

  void _speak(String text) async {
    if (_isSpeaking) {
      _stopSpeaking();
      return;
    }
    String spokenText = _processTextForSpeech(text);
    if (mounted) setState(() => _isSpeaking = true);
    await _flutterTts.speak(spokenText);
  }

  void _stopSpeaking() async {
    await _flutterTts.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  void _listen() async {
    HapticFeedback.mediumImpact();
    if (!_isListening) {
      bool available = await _speech.initialize(
        onError: (val) => setState(() => _isListening = false),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _controller.text = val.recognizedWords;
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _sendMessage({String? quickPrompt}) async {
    final text = quickPrompt ?? _controller.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _stopSpeaking();
    _focusNode.unfocus();

    setState(() {
      _sessionHistory.add({'role': 'user', 'content': text});
      _isTyping = true;
      _stopRequested = false;
    });

    _controller.clear();
    _scrollToBottom();

    setState(() {
      _sessionHistory.add({'role': 'ai', 'content': ''});
    });

    String fullResponse = "";

    try {
      await for (final chunk in _chatService.streamResponse(text)) {
        // CRITICAL FIX: Break out of the loop cleanly if stopped or unmounted
        if (!mounted || _stopRequested) break;

        fullResponse += chunk;

        setState(() {
          _sessionHistory.last['content'] = fullResponse;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sessionHistory.last['content'] =
              fullResponse +
              "\n\n⚠️ *Connection interrupted. Please try again.*";
        });
      }
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  void _stopGeneration() {
    HapticFeedback.heavyImpact();
    setState(() {
      _stopRequested = true;
      _isTyping = false;
    });
    _stopSpeaking();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              "Copied to clipboard!",
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ],
        ),
        backgroundColor: _accentColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _clearChat() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Clear Chat",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to clear the entire conversation?",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _sessionHistory.clear());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Clear",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Color(0xFFF5F7FA)],
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: _sessionHistory.isEmpty
                    ? _buildWelcomeState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _sessionHistory.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _sessionHistory.length && _isTyping) {
                            return _buildTypingIndicator();
                          }
                          final msg = _sessionHistory[index];
                          return _buildBubbleContent(
                            msg['content']!,
                            msg['role'] == 'user',
                            index,
                          );
                        },
                      ),
              ),
            ],
          ),
          if (_showScrollToBottom)
            Positioned(
              bottom: 140,
              right: 20,
              child: FloatingActionButton.small(
                onPressed: _scrollToBottom,
                backgroundColor: Colors.white,
                elevation: 4,
                child: Icon(Icons.keyboard_arrow_down, color: _primaryColor),
              ),
            ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildInputSection()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black87,
            size: 16,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "PATGPT Pro",
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isTyping ? Colors.amber : _accentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isTyping ? Colors.amber : _accentColor)
                              .withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isTyping ? "Analyzing..." : "Ready to help",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (_sessionHistory.isNotEmpty)
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.grey[700]),
            onPressed: _clearChat,
            tooltip: "Clear chat",
          ),
        if (_isTyping)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _stopGeneration,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: Text(
                "Stop",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                backgroundColor: Colors.red.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildInputSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_sessionHistory.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildQuickChip("Sales Analysis", Icons.trending_up),
                    _buildQuickChip("Performance Report", Icons.analytics),
                    _buildQuickChip("Team Overview", Icons.people),
                    _buildQuickChip("Goals & Targets", Icons.flag),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: _buildGlassInputBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _sendMessage(quickPrompt: label),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _primaryColor.withOpacity(0.1),
                _secondaryColor.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _primaryColor.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: _primaryColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(4),
            child: GestureDetector(
              onTap: _listen,
              child: ScaleTransition(
                scale: _isListening
                    ? _micPulseController
                    : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: _isListening
                        ? const LinearGradient(
                            colors: [Colors.red, Colors.redAccent],
                          )
                        : LinearGradient(
                            colors: [
                              Colors.grey.shade200,
                              Colors.grey.shade300,
                            ],
                          ),
                    shape: BoxShape.circle,
                    boxShadow: _isListening
                        ? [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none_outlined,
                    color: _isListening ? Colors.white : Colors.grey.shade600,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: GoogleFonts.poppins(fontSize: 15, height: 1.4),
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: "Ask me anything...",
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _isTyping ? null : _sendMessage(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _controller.text.isEmpty
                      ? [Colors.grey.shade300, Colors.grey.shade400]
                      : [_primaryColor, _secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: _controller.text.isNotEmpty
                    ? [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: _isTyping || _controller.text.isEmpty
                    ? null
                    : () => _sendMessage(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor, _secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.psychology_outlined,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              "Hello, Manager!",
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "I'm your AI assistant, ready to help with\nanalytics, reports, and insights",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.6,
              ),
            ),
            const SizedBox(height: 40),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildFeatureCard(
                  Icons.bar_chart_rounded,
                  "Analytics",
                  "Deep insights",
                  Colors.blue,
                ),
                _buildFeatureCard(
                  Icons.assignment_rounded,
                  "Reports",
                  "Quick summaries",
                  Colors.green,
                ),
                _buildFeatureCard(
                  Icons.lightbulb_rounded,
                  "Smart AI",
                  "Instant answers",
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Container(
      width: 105,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                20,
              ).copyWith(bottomLeft: Radius.zero),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _typingIndicatorController,
                  builder: (context, child) {
                    final delay = index * 0.2;
                    final value =
                        (_typingIndicatorController.value + delay) % 1.0;
                    final opacity =
                        (0.3 + (0.7 * (1 - (value - 0.5).abs() * 2))).clamp(
                          0.3,
                          1.0,
                        );

                    return Container(
                      margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(opacity),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleContent(String text, bool isUser, int index) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width * (isUser ? 0.75 : 0.85),
              ),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        colors: [_primaryColor, _secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : Colors.white,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: isUser ? Radius.zero : const Radius.circular(20),
                  bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? _primaryColor.withOpacity(0.25)
                        : Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: isUser
                  ? Text(
                      text,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : MarkdownBody(
                      data: text.isEmpty ? "..." : text,
                      selectable: true,
                      extensionSet: md.ExtensionSet.gitHubFlavored,
                      builders: {'table': CustomTableBuilder()},
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.6,
                        ),
                        h1: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        h2: GoogleFonts.poppins(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        h3: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        code: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          backgroundColor: Colors.grey.shade100,
                          color: _primaryColor,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        blockquote: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
            ),
            if (!isUser && text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 20, top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionBtn(
                      Icons.content_copy_rounded,
                      "Copy",
                      () => _copyToClipboard(text),
                      Colors.grey.shade600,
                    ),
                    const SizedBox(width: 16),
                    _buildActionBtn(
                      _isSpeaking ? Icons.stop_circle : Icons.volume_up_rounded,
                      _isSpeaking ? "Stop" : "Listen",
                      () => _speak(text),
                      _isSpeaking ? Colors.red : Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            if (isUser) const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(
    IconData icon,
    String label,
    VoidCallback onTap,
    Color color,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// UPGRADED CUSTOM TABLE BUILDER
// ==========================================
class CustomTableBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.children == null || element.children!.isEmpty) return null;

    List<List<String>> headerRows = [];
    List<List<String>> bodyRows = [];

    // 1. Parse Markdown AST into Rows and Columns
    for (var child in element.children!) {
      if (child is md.Element) {
        if (child.tag == 'thead') {
          for (var row in child.children ?? []) {
            if (row is md.Element && row.tag == 'tr') {
              List<String> cells = [];
              for (var cell in row.children ?? []) {
                if (cell is md.Element &&
                    (cell.tag == 'th' || cell.tag == 'td')) {
                  cells.add(cell.textContent.trim());
                }
              }
              if (cells.isNotEmpty) headerRows.add(cells);
            }
          }
        } else if (child.tag == 'tbody') {
          for (var row in child.children ?? []) {
            if (row is md.Element && row.tag == 'tr') {
              List<String> cells = [];
              for (var cell in row.children ?? []) {
                if (cell is md.Element &&
                    (cell.tag == 'td' || cell.tag == 'th')) {
                  cells.add(cell.textContent.trim());
                }
              }
              if (cells.isNotEmpty) bodyRows.add(cells);
            }
          }
        }
      }
    }

    if (headerRows.isEmpty && bodyRows.isEmpty) return null;

    List<String> headers = headerRows.isNotEmpty
        ? headerRows.first
        : List.generate(
            bodyRows.isNotEmpty ? bodyRows.first.length : 0,
            (i) => 'Col ${i + 1}',
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: DataTable(
                  headingRowHeight: 48,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight:
                      double.infinity, // Allows cells to expand vertically
                  columnSpacing: 24,
                  horizontalMargin: 16,
                  headingRowColor: MaterialStateProperty.all(
                    const Color(0xFFF1F3F5),
                  ),

                  // Zebra striping for better readability
                  dataRowColor: MaterialStateProperty.resolveWith((states) {
                    return null;
                  }),

                  columns: headers.map((header) {
                    return DataColumn(
                      label: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          header,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: const Color(0xFF6200EA),
                          ),
                        ),
                      ),
                    );
                  }).toList(),

                  rows: bodyRows.asMap().entries.map((entry) {
                    int index = entry.key;
                    List<String> row = entry.value;

                    while (row.length < headers.length) {
                      row.add('');
                    }
                    if (row.length > headers.length) {
                      row = row.sublist(0, headers.length);
                    }

                    return DataRow(
                      color: MaterialStateProperty.all(
                        index.isEven ? Colors.white : Colors.grey.shade50,
                      ),
                      cells: row.map((cell) {
                        return DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            constraints: BoxConstraints(
                              minWidth: 80,
                              maxWidth: constraints.maxWidth * 0.7,
                            ),
                            child: SelectableText(
                              cell,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
