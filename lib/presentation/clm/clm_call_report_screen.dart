import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/clm_models.dart';
import '../../providers/clm_provider.dart';
import '../../providers/dcr_provider.dart';
import '../dcr/dcr_doctor_visit_screen.dart';

class ClmCallReportScreen extends StatefulWidget {
  final ClmDoctor doctor;
  final ClmSession session;
  final List<ClmBrand> brands;

  const ClmCallReportScreen({
    super.key,
    required this.doctor,
    required this.session,
    required this.brands,
  });

  @override
  State<ClmCallReportScreen> createState() => _ClmCallReportScreenState();
}

class _ClmCallReportScreenState extends State<ClmCallReportScreen>
    with TickerProviderStateMixin {
  static const _purple = Color(0xFF4A148C);

  DoctorReaction _reaction = DoctorReaction.neutral;
  final _notesCtrl = TextEditingController();
  final _competitorCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();

  final Set<int> _brandsDiscussed = {};
  final Set<String> _keyMessages = {};
  final List<String> _topics = [];
  DateTime? _nextCallDate;
  int _samplesGiven = 0;
  bool _saving = false;

  // ─── Voice Note ───────────────────────────────────────────────────────────────
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _stt = SpeechToText();

  bool _recording = false;
  bool _hasRecording = false;
  bool _playing = false;
  bool _transcribing = false;
  String? _voiceNotePath;
  String _transcript = '';
  int _recordSeconds = 0;
  Timer? _recordTimer;

  late AnimationController _micPulseCtrl;

  // ─── Predefined key messages ──────────────────────────────────────────────────
  static const Map<String, List<String>> _brandMessages = {
    'CardioMax': ['24h BP control', 'No cough (unlike ACEi)', 'Renoprotective', 'CV death reduction'],
    'NeuroVite': ['Reduces burning & tingling', 'Improves nerve conduction', 'Safe long-term', '73% symptom improvement'],
    'GlucoShield': ['38% CV death reduction', 'Weight loss benefit', 'Once daily dosing', 'Renal protection'],
  };

  @override
  void initState() {
    super.initState();
    _brandsDiscussed.addAll(widget.session.brandIds);
    _micPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _competitorCtrl.dispose();
    _topicCtrl.dispose();
    _recorder.dispose();
    _player.dispose();
    _recordTimer?.cancel();
    _micPulseCtrl.dispose();
    super.dispose();
  }

  // ─── Voice Recording ──────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    try {
      // hasPermission() also requests the permission on Android/iOS
      final granted = await _recorder.hasPermission();
      if (!granted) {
        if (mounted) {
          _showSnack(
            'Microphone permission is required. '
            'Please allow it in app settings and try again.',
            isError: true,
          );
        }
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(
          dir.path, 'clm', 'voice',
          'note_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await Directory(p.dirname(path)).create(recursive: true);

      await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc), path: path);

      if (!mounted) return;
      _voiceNotePath = path;
      _recordSeconds = 0;
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
      setState(() => _recording = true);
    } catch (e) {
      if (mounted) {
        _showSnack('Could not start recording: $e', isError: true);
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordTimer?.cancel();
      await _recorder.stop();
      setState(() {
        _recording = false;
        _hasRecording = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _recording = false);
        _showSnack('Error stopping recording: $e', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : null,
      duration: Duration(seconds: isError ? 4 : 2),
    ));
  }

  Future<void> _togglePlayback() async {
    if (_voiceNotePath == null) return;
    try {
      if (_playing) {
        await _player.stop();
        setState(() => _playing = false);
      } else {
        _player.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _playing = false);
        });
        await _player.play(DeviceFileSource(_voiceNotePath!));
        setState(() => _playing = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _playing = false);
        _showSnack('Playback error: $e', isError: true);
      }
    }
  }

  Future<void> _deleteRecording() async {
    await _player.stop();
    if (_voiceNotePath != null) {
      final f = File(_voiceNotePath!);
      if (await f.exists()) await f.delete();
    }
    setState(() {
      _recording = false;
      _hasRecording = false;
      _playing = false;
      _voiceNotePath = null;
      _transcript = '';
      _recordSeconds = 0;
    });
  }

  Future<void> _transcribeVoice() async {
    setState(() => _transcribing = true);
    try {
      final available = await _stt.initialize();
      if (!available) {
        if (mounted) {
          setState(() => _transcribing = false);
          _showSnack('Speech recognition not available on this device.',
              isError: true);
        }
        return;
      }
      await _stt.listen(
        onResult: (r) {
          if (mounted) setState(() => _transcript = r.recognizedWords);
          if (r.finalResult) {
            _stt.stop();
            if (mounted) {
              setState(() => _transcribing = false);
              if (_transcript.isNotEmpty) {
                final existing = _notesCtrl.text.trim();
                _notesCtrl.text =
                    existing.isEmpty ? _transcript : '$existing\n$_transcript';
              }
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _transcribing = false);
        _showSnack('Transcription error: $e', isError: true);
      }
    }
  }

  String _formatRecordTime(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final durationMins = widget.session.durationSeconds ~/ 60;
    final durationSecs = widget.session.durationSeconds % 60;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text('Post-Call Report',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSessionSummaryBar(durationMins, durationSecs),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVoiceNoteSection(),
                  const SizedBox(height: 16),
                  _buildReactionPicker(),
                  const SizedBox(height: 16),
                  _buildBrandsSection(),
                  const SizedBox(height: 16),
                  _buildKeyMessagesSection(),
                  const SizedBox(height: 16),
                  _buildTopicsSection(),
                  const SizedBox(height: 16),
                  _buildNotesField(),
                  const SizedBox(height: 16),
                  _buildCompetitorField(),
                  const SizedBox(height: 16),
                  _buildSamplesRow(),
                  const SizedBox(height: 16),
                  _buildNextCallRow(context),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildSubmitBar(),
    );
  }

  // ─── Session Summary Bar ──────────────────────────────────────────────────────

  Widget _buildSessionSummaryBar(int mins, int secs) {
    return Container(
      color: _purple,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: Text(widget.doctor.initials,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.doctor.name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            Text(widget.doctor.speciality,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            const Icon(Icons.timer_outlined, color: Colors.white70, size: 13),
            const SizedBox(width: 4),
            Text('${mins}m ${secs}s',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  // ─── Voice Note Section ───────────────────────────────────────────────────────

  Widget _buildVoiceNoteSection() {
    return _card(
      title: 'Key Call Notes – Voice',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Recording controls
        if (!_hasRecording) _buildRecordButton(),
        if (_hasRecording) _buildPlaybackRow(),
        if (_recording) ...[
          const SizedBox(height: 12),
          _buildRecordingWaveform(),
        ],
        if (_hasRecording && _transcript.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.auto_awesome, size: 12, color: Colors.blue.shade600),
                const SizedBox(width: 4),
                Text('Transcript', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: Colors.blue.shade700)),
              ]),
              const SizedBox(height: 4),
              Text(_transcript,
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade800)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildRecordButton() {
    return Row(children: [
      AnimatedBuilder(
        animation: _micPulseCtrl,
        builder: (context, child) {
          return GestureDetector(
            onTap: _recording ? _stopRecording : _startRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _recording ? 56 + _micPulseCtrl.value * 4 : 56,
              height: _recording ? 56 + _micPulseCtrl.value * 4 : 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _recording ? Colors.red.shade600 : _purple,
                boxShadow: _recording
                    ? [BoxShadow(
                        color: Colors.red.shade300.withValues(alpha: 0.6),
                        blurRadius: 12 + _micPulseCtrl.value * 8,
                        spreadRadius: 2)]
                    : [],
              ),
              child: Icon(
                _recording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          );
        },
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _recording
                ? 'Recording… ${_formatRecordTime(_recordSeconds)}'
                : 'Tap to record key call notes',
            style: TextStyle(
              fontSize: 13,
              fontWeight: _recording ? FontWeight.w600 : FontWeight.normal,
              color: _recording ? Colors.red.shade700 : Colors.grey.shade700,
            ),
          ),
          if (!_recording)
            Text('Voice note saved with call report',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ]),
      ),
    ]);
  }

  Widget _buildPlaybackRow() {
    return Row(children: [
      // Play/pause
      GestureDetector(
        onTap: _togglePlayback,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _purple.withValues(alpha: 0.1)),
          child: Icon(
            _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: _purple,
            size: 24,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Voice note recorded',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700)),
          Text(_formatRecordTime(_recordSeconds),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
      ),
      // Transcribe
      if (!_transcribing)
        TextButton.icon(
          onPressed: _transcribeVoice,
          icon: const Icon(Icons.text_snippet_outlined, size: 15),
          label: const Text('Transcribe', style: TextStyle(fontSize: 11)),
          style: TextButton.styleFrom(foregroundColor: Colors.blue.shade700),
        )
      else
        const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      // Delete
      IconButton(
        onPressed: _deleteRecording,
        icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    ]);
  }

  Widget _buildRecordingWaveform() {
    return AnimatedBuilder(
      animation: _micPulseCtrl,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(16, (i) {
            final height = 8.0 +
                (i % 3 == 0
                    ? _micPulseCtrl.value * 20
                    : i % 2 == 0
                        ? (1 - _micPulseCtrl.value) * 14
                        : 8);
            return AnimatedContainer(
              duration: Duration(milliseconds: 100 + i * 20),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  // ─── Reaction Picker ──────────────────────────────────────────────────────────

  Widget _buildReactionPicker() {
    return _card(
      title: 'Doctor\'s Reaction',
      child: Row(
        children: DoctorReaction.values.map((r) {
          final selected = _reaction == r;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _reaction = r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? _reactionColor(r).withValues(alpha: 0.15)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? _reactionColor(r) : Colors.grey.shade200,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(children: [
                  Text(r.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(r.label,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? _reactionColor(r)
                              : Colors.grey.shade500),
                      textAlign: TextAlign.center),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _reactionColor(DoctorReaction r) {
    switch (r) {
      case DoctorReaction.positive:    return Colors.green.shade600;
      case DoctorReaction.receptive:   return Colors.blue.shade600;
      case DoctorReaction.neutral:     return Colors.grey.shade600;
      case DoctorReaction.objection:   return Colors.red.shade600;
      case DoctorReaction.notAvailable:return Colors.orange.shade600;
    }
  }

  // ─── Brands Section ───────────────────────────────────────────────────────────

  Widget _buildBrandsSection() {
    return _card(
      title: 'Brands Discussed',
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: widget.brands.map((b) {
          final selected = _brandsDiscussed.contains(b.id);
          return GestureDetector(
            onTap: () => setState(() {
              if (selected) { _brandsDiscussed.remove(b.id); }
              else { _brandsDiscussed.add(b.id); }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? _purple : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected ? _purple : Colors.grey.shade300),
              ),
              child: Text(b.name,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.grey.shade700)),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Key Messages ─────────────────────────────────────────────────────────────

  Widget _buildKeyMessagesSection() {
    final messages = <String>[];
    for (final b in widget.brands) {
      messages.addAll(_brandMessages[b.name] ?? []);
    }
    if (messages.isEmpty) return const SizedBox.shrink();

    return _card(
      title: 'Key Messages Delivered',
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: messages.map((msg) {
          final selected = _keyMessages.contains(msg);
          return GestureDetector(
            onTap: () => setState(() {
              if (selected) { _keyMessages.remove(msg); }
              else { _keyMessages.add(msg); }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.green.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: selected ? Colors.green.shade400 : Colors.grey.shade300),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 14,
                  color: selected ? Colors.green.shade600 : Colors.grey.shade400,
                ),
                const SizedBox(width: 5),
                Text(msg,
                    style: TextStyle(
                        fontSize: 11,
                        color: selected
                            ? Colors.green.shade700
                            : Colors.grey.shade700)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Topics ───────────────────────────────────────────────────────────────────

  Widget _buildTopicsSection() {
    return _card(
      title: 'Discussion Topics',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_topics.isNotEmpty) ...[
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _topics.map((t) => Chip(
                  label: Text(t, style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => setState(() => _topics.remove(t)),
                  backgroundColor: Colors.blue.shade50,
                  side: BorderSide(color: Colors.blue.shade200),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
          ),
          const SizedBox(height: 8),
        ],
        Row(children: [
          Expanded(
            child: TextField(
              controller: _topicCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Add topic (e.g. Renal dosing)',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onSubmitted: _addTopic,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _addTopic(_topicCtrl.text),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: _purple, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
          ),
        ]),
      ]),
    );
  }

  void _addTopic(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    setState(() {
      if (!_topics.contains(t)) _topics.add(t);
      _topicCtrl.clear();
    });
  }

  // ─── Notes & Competitor ───────────────────────────────────────────────────────

  Widget _buildNotesField() {
    return _card(
      title: 'Call Notes',
      child: TextField(
        controller: _notesCtrl,
        maxLines: 4,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'What was discussed? Any follow-up actions?',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildCompetitorField() {
    return _card(
      title: 'Competitor Mentioned',
      child: TextField(
        controller: _competitorCtrl,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'e.g. Losartan, Jardiance',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          prefixIcon: Icon(Icons.warning_amber_outlined,
              size: 18, color: Colors.orange.shade400),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  // ─── Samples ──────────────────────────────────────────────────────────────────

  Widget _buildSamplesRow() {
    return _card(
      title: 'Samples Given',
      child: Row(children: [
        Icon(Icons.science_outlined, color: Colors.grey.shade400, size: 18),
        const SizedBox(width: 8),
        Text('Sample units distributed',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const Spacer(),
        _counterButton(Icons.remove, () {
          if (_samplesGiven > 0) setState(() => _samplesGiven--);
        }),
        SizedBox(
          width: 40,
          child: Text('$_samplesGiven',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        _counterButton(Icons.add, () => setState(() => _samplesGiven++)),
      ]),
    );
  }

  Widget _counterButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
            color: _purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, color: _purple, size: 16),
      ),
    );
  }

  // ─── Next Call ────────────────────────────────────────────────────────────────

  Widget _buildNextCallRow(BuildContext context) {
    return _card(
      title: 'Next Call Date',
      child: GestureDetector(
        onTap: () => _pickDate(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _nextCallDate != null
                ? Colors.green.shade50
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _nextCallDate != null
                  ? Colors.green.shade300
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(children: [
            Icon(Icons.event_outlined,
                color: _nextCallDate != null
                    ? Colors.green.shade600
                    : Colors.grey.shade400,
                size: 18),
            const SizedBox(width: 10),
            Text(
              _nextCallDate != null
                  ? DateFormat('EEEE, d MMMM yyyy').format(_nextCallDate!)
                  : 'Tap to schedule next call',
              style: TextStyle(
                  fontSize: 13,
                  color: _nextCallDate != null
                      ? Colors.green.shade700
                      : Colors.grey.shade500),
            ),
            if (_nextCallDate != null) ...[
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _nextCallDate = null),
                child: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _nextCallDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _purple),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _nextCallDate = picked);
  }

  // ─── Submit Bar ───────────────────────────────────────────────────────────────

  Widget _buildSubmitBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _saving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text('Submit Report',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _saving ? null : _submitAndFillDcr,
            icon: const Icon(Icons.assignment_outlined, size: 18),
            label: Text('Submit & Fill DCR',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _purple,
              side: BorderSide(color: _purple.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _submitAndFillDcr() async {
    setState(() => _saving = true);
    final prov = context.read<ClmProvider>();
    try {
      if (_recording) await _stopRecording();
      final report = ClmCallReport(
        id: const Uuid().v4(),
        sessionId: widget.session.id,
        doctorId: widget.doctor.id,
        createdAt: DateTime.now(),
        brandsDiscussed: _brandsDiscussed.toList(),
        reaction: _reaction,
        callNotes: _notesCtrl.text.trim(),
        topicsDiscussed: _topics,
        keyMessagesDelivered: _keyMessages.toList(),
        nextCallDate: _nextCallDate,
        samplesGiven: _samplesGiven,
        competitorMentions: _competitorCtrl.text.trim(),
        voiceNotePath: _voiceNotePath,
        voiceNoteTranscript: _transcript.isNotEmpty ? _transcript : null,
      );
      await prov.saveCallReport(report);
      if (_nextCallDate != null) {
        await prov.updateDoctorNextCallDate(widget.doctor.id, _nextCallDate);
      }
      if (!mounted) return;
      final nav = Navigator.of(context);
      final dcrProv = DcrProvider();
      await dcrProv.init();
      nav.pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: dcrProv,
            child: const DcrDoctorVisitScreen(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final prov = context.read<ClmProvider>();
    try {
      // Stop any active recording before submit
      if (_recording) await _stopRecording();

      final report = ClmCallReport(
        id: const Uuid().v4(),
        sessionId: widget.session.id,
        doctorId: widget.doctor.id,
        createdAt: DateTime.now(),
        brandsDiscussed: _brandsDiscussed.toList(),
        reaction: _reaction,
        callNotes: _notesCtrl.text.trim(),
        topicsDiscussed: _topics,
        keyMessagesDelivered: _keyMessages.toList(),
        nextCallDate: _nextCallDate,
        samplesGiven: _samplesGiven,
        competitorMentions: _competitorCtrl.text.trim(),
        voiceNotePath: _voiceNotePath,
        voiceNoteTranscript: _transcript.isNotEmpty ? _transcript : null,
      );
      await prov.saveCallReport(report);
      if (_nextCallDate != null) {
        await prov.updateDoctorNextCallDate(widget.doctor.id, _nextCallDate);
      }
      if (mounted) Navigator.pop(context, report);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Card Wrapper ─────────────────────────────────────────────────────────────

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w700, color: _purple)),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}
