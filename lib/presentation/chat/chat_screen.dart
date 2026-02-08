import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../../data/services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();

  // Voice & TTS
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  bool _isSpeaking = false;
  late AnimationController _micPulseController;

  // Chat State
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  bool _stopRequested = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initTts();

    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      lowerBound: 0.8,
      upperBound: 1.2,
    )..repeat(reverse: true);
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
    _micPulseController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  // --- SMART TEXT PROCESSING ---
  String _processTextForSpeech(String markdown) {
    final tableRegex = RegExp(r'\|.*\|');

    String cleanText = markdown;

    if (tableRegex.hasMatch(markdown)) {
      cleanText = cleanText.replaceAll(tableRegex, '');
      cleanText += " . I have displayed the detailed data in the table below.";
    }

    cleanText = cleanText.replaceAll(RegExp(r'[#*`_]'), '');

    cleanText = cleanText.replaceAll(RegExp(r'\n+'), '\n');

    return cleanText;
  }

  // --- VOICE LOGIC ---
  void _listen() async {
    HapticFeedback.selectionClick();
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
      if (_controller.text.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), _sendMessage);
      }
    }
  }

  // --- TTS LOGIC ---
  void _speak(String text) async {
    _stopSpeaking();

    String spokenText = _processTextForSpeech(text);

    if (mounted) setState(() => _isSpeaking = true);
    await _flutterTts.speak(spokenText);
  }

  void _stopSpeaking() async {
    await _flutterTts.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  // --- CHAT LOGIC ---
  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _stopSpeaking();

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isTyping = true;
      _stopRequested = false;
    });

    _controller.clear();
    _scrollToBottom();

    setState(() {
      _messages.add({'role': 'ai', 'content': ''});
    });

    String fullResponse = "";

    try {
      await for (final chunk in _chatService.streamResponse(text)) {
        if (!mounted) return;
        if (_stopRequested) break;

        fullResponse += chunk;

        setState(() {
          final lastIndex = _messages.length - 1;
          _messages[lastIndex]['content'] = fullResponse;
        });
        _scrollToBottom();
      }

      if (!_stopRequested && mounted) {
        _speak(fullResponse);
      }
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  void _stopGeneration() {
    HapticFeedback.mediumImpact();
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
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: Image.network(
                "https://www.transparenttextures.com/patterns/cubes.png",
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),

          Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 400),
                            builder: (context, double val, child) {
                              return Opacity(
                                opacity: val,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - val)),
                                  child: child,
                                ),
                              );
                            },
                            child: _buildMessageBubble(
                              msg['content']!,
                              msg['role'] == 'user',
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),

          Positioned(bottom: 0, left: 0, right: 0, child: _buildInputArea()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: Colors.black12,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.black87,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4A148C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Color(0xFF4A148C),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "PatGPT",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  if (_isTyping || _isSpeaking)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _isTyping ? Colors.green : Colors.blue,
                      ),
                    )
                  else
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    _isTyping
                        ? "Generating..."
                        : (_isSpeaking ? "Speaking..." : "Online"),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
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
        if (_isTyping || _isSpeaking)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: _stopGeneration,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stop_rounded, color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      "STOP",
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onLongPress: _listen,
            onTap: _listen,
            child: ScaleTransition(
              scale: _isListening
                  ? _micPulseController
                  : const AlwaysStoppedAnimation(1.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: _isListening ? Colors.redAccent : Colors.grey[100],
                  shape: BoxShape.circle,
                  boxShadow: _isListening
                      ? [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none_rounded,
                  color: _isListening ? Colors.white : Colors.black54,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FB),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: _isListening
                      ? "Listening..."
                      : "Ask me anything...",
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => _isTyping ? null : _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),

          InkWell(
            onTap: _isTyping ? null : _sendMessage,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: _isTyping ? Colors.grey[300] : const Color(0xFF4A148C),
                shape: BoxShape.circle,
                boxShadow: _isTyping
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFF4A148C).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Icon(
                Icons.send_rounded,
                color: _isTyping ? Colors.grey[600] : Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF4A148C) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                boxShadow: isUser
                    ? [
                        BoxShadow(
                          color: const Color(0xFF4A148C).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: isUser
                  ? Text(
                      text,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14.5,
                        height: 1.4,
                      ),
                    )
                  : MarkdownBody(
                      data: text,
                      selectable: true,
                      builders: {'table': TableElementBuilder()},
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.poppins(
                          fontSize: 14.5,
                          color: Colors.black87,
                          height: 1.6,
                        ),
                        h1: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                        h2: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4A148C),
                        ),
                        strong: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                        ),
                        code: GoogleFonts.firaCode(
                          fontSize: 13,
                          backgroundColor: const Color(0xFFF3F4F6),
                          color: const Color(0xFFD63384),
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
            ),
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => _speak(text),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.volume_up_rounded,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Play",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(
              Icons.graphic_eq,
              size: 48,
              color: Color(0xFF4A148C),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "How can I help you today?",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Try asking about sales, coverage,\nor your daily plan.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// --- TABLE ELEMENT BUILDER ---
class TableElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final headerStyle = GoogleFonts.poppins(
      fontWeight: FontWeight.bold,
      color: Colors.black87,
      fontSize: 12,
    );
    final cellStyle = GoogleFonts.poppins(color: Colors.black87, fontSize: 12);
    final borderSide = BorderSide(color: Colors.grey.shade200, width: 1);

    List<DataColumn> columns = [];
    List<DataRow> rows = [];

    if (element.children != null) {
      for (var child in element.children!) {
        if (child is md.Element) {
          if (child.tag == 'thead') {
            if (child.children != null) {
              for (var row in child.children!) {
                if (row is md.Element && row.tag == 'tr') {
                  if (row.children != null) {
                    for (var cell in row.children!) {
                      if (cell is md.Element && cell.tag == 'th') {
                        columns.add(
                          DataColumn(
                            label: Expanded(
                              child: Text(
                                cell.textContent,
                                style: headerStyle,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  }
                }
              }
            }
          }
          if (child.tag == 'tbody' && child.children != null) {
            for (var row in child.children!) {
              if (row is md.Element &&
                  row.tag == 'tr' &&
                  row.children != null) {
                List<DataCell> cells = [];
                for (var cell in row.children!) {
                  if (cell is md.Element && cell.tag == 'td') {
                    cells.add(
                      DataCell(Text(cell.textContent, style: cellStyle)),
                    );
                  }
                }
                if (cells.isNotEmpty) rows.add(DataRow(cells: cells));
              }
            }
          }
        }
      }
    }

    if (columns.isEmpty && rows.isEmpty) return null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(const Color(0xFFF9FAFB)),
            dataRowColor: MaterialStateProperty.all(Colors.white),
            border: TableBorder(
              horizontalInside: borderSide,
              verticalInside: borderSide,
            ),
            columnSpacing: 24,
            columns: columns,
            rows: rows,
          ),
        ),
      ),
    );
  }
}
