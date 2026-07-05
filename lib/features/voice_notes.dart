import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../text_to_speech/text_to_speech.dart';
import 'dart:io';
import 'dart:convert';

class VoiceNoteApp extends StatefulWidget {
  @override
  _VoiceNoteAppState createState() => _VoiceNoteAppState();
}

class _VoiceNoteAppState extends State<VoiceNoteApp> {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  TextToSpeechService tts = TextToSpeechService();
  bool _isRecording = false;
  bool _isAskingForAction = false;
  bool _isAskingForPlayNote = false;
  bool _isAskingForDeleteNote = false;
  bool _hasNoteName = false;
  String _noteName = '';
  Map<String, String> _voiceNotes = {};
  String _actionButtonText = 'Start';

  @override
  void initState() {
    _initialGuidelines();
    super.initState();
    _requestPermissions().then((granted) {
      if (granted) {
        _initializeRecorder();
        _loadVoiceNotes();
      } else {
        tts.speak('Microphone and Storage permissions are required.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Microphone and Storage permissions are required.')),
        );
      }
    });
  }


  Future<void> _initialGuidelines() async {
    tts.speak("Please Tap and provide details accordingly");
  }
  Future<bool> _requestPermissions() async {
    final status = await [Permission.microphone, Permission.storage].request();
    return status[Permission.microphone]?.isGranted == true &&
        status[Permission.storage]?.isGranted == true;
  }

  Future<void> _initializeRecorder() async {
    await _recorder.openRecorder();
    await _player.openPlayer();
  }

  Future<void> _loadVoiceNotes() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/voice_notes.json');
    if (await file.exists()) {
      final content = await file.readAsString();
      setState(() {
        _voiceNotes = Map<String, String>.from(json.decode(content));
      });
    }
  }

  Future<void> _saveVoiceNotes() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/voice_notes.json');
    await file.writeAsString(json.encode(_voiceNotes));
  }

  Future<void> _deleteVoiceNote() async {
    if (_voiceNotes.containsKey(_noteName)) {
      final filePath = _voiceNotes[_noteName];
      final file = File(filePath!);
      if (await file.exists()) {
        await file.delete();
      }
      setState(() {
        _voiceNotes.remove(_noteName);
        _noteName = '';
        _isAskingForDeleteNote = false;
        _actionButtonText = 'Start';
      });
      await _saveVoiceNotes();
      tts.speak('Voice note deleted.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice note deleted.')),
      );
    } else {
      tts.speak('Voice note not found.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice note not found.')),
      );
      setState(() {
        _isAskingForDeleteNote = false;
        _actionButtonText = 'Start';
      });
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }

  Future<void> _askForAction() async {
    bool available = await _speechToText.initialize();
    if (available) {
      setState(() {
        _isAskingForAction = true;
        _actionButtonText = 'Listening...';
        tts.speak(_actionButtonText);
      });
      _speechToText.listen(
          onResult: (val) {
            String command = val.recognizedWords.toLowerCase();
            if (command.contains('add') ||
                command.contains('record') ||
                command.contains('new')) {
              _speechToText.stop();
              _askNoteName();
            } else if (command.contains('listen') ||
                command.contains('play') ||
                command.contains('hear')) {
              _speechToText.stop();
              _askNoteName(isForPlayback: true);
            } else if (command.contains('delete') ||
                command.contains('remove') ||
                command.contains('erase')) {
              _speechToText.stop();
              _askNoteName(isForDelete: true);
            } else {
              tts.speak('Please say "add", "listen", or "delete".');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Please select "add", "listen", or "delete".')),
              );
              _speechToText.stop();
              setState(() {
                _isAskingForAction = false;
                _actionButtonText = 'Start';
              });
            }
          },
          listenFor: Duration(seconds: 5),
          pauseFor: Duration(seconds: 5),
          partialResults: false,
          onSoundLevelChange: null,
          cancelOnError: true);
    } else {
      tts.speak('Speech recognition not available.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speech recognition not available.')),
      );
    }
  }

  Future<void> _askNoteName(
      {bool isForPlayback = false, bool isForDelete = false}) async {
    bool available = await _speechToText.initialize();
    if (available) {
      setState(() {
        _isAskingForPlayNote = isForPlayback;
        _isAskingForDeleteNote = isForDelete;
        _actionButtonText = 'Listening for note name...';
        tts.speak(_actionButtonText);
      });
      _speechToText.listen(
          onResult: (val) {
            setState(() {
              _noteName = val.recognizedWords;
            });
            if (!_speechToText.isListening) {
              _speechToText.stop();
              if (_isAskingForPlayNote) {
                _playVoiceNote();
              } else if (_isAskingForDeleteNote) {
                _deleteVoiceNote();
              } else {
                setState(() {
                  _hasNoteName = true;
                  _startRecording();
                });
              }
            }
          },
          listenFor: Duration(seconds: 5),
          pauseFor: Duration(seconds: 5),
          partialResults: false,
          onSoundLevelChange: null,
          cancelOnError: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speech recognition not available.')),
      );
    }
  }


  Future<void> _startStopRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _askForAction();
    }
  }

  Future<void> _startRecording() async {
    if (_noteName.isNotEmpty) {
      await tts.speak('Record');
      final microphoneStatus = await Permission.microphone.status;
      final storageStatus = await Permission.storage.status;

      if (!microphoneStatus.isGranted || !storageStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Microphone and Storage permissions are required.')),
        );
        return;
      }

      setState(() {
        _isRecording = true;
        _actionButtonText = 'Record';
        // await tts.speak(_actionButtonText);
      });

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$_noteName.wav';

      try {
        await _recorder.startRecorder(
          toFile: filePath,
          codec: Codec.pcm16WAV,
        );
      } catch (e) {
        setState(() {
          _isRecording = false;
          _actionButtonText = 'Start';
        });
        tts.speak('Failed to start recorder: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recorder: $e')),
        );
      }
    } else {
      tts.speak('Please provide a name for the voice note.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide a name for the voice note.')),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (_isRecording) {
      try {
        await _recorder.stopRecorder();
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$_noteName.wav';
        setState(() {
          _voiceNotes[_noteName] = filePath;
          _isRecording = false;
          _hasNoteName = false;
          _noteName = '';
          _actionButtonText = 'Start';
        });
        await _saveVoiceNotes();
      } catch (e) {
        setState(() {
          _isRecording = false;
          _actionButtonText = 'Start';
        });
        tts.speak("'Failed to stop recorder: $e'");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop recorder: $e')),
        );
      }
    }
  }

  Future<void> _playVoiceNote() async {
    final filePath = _voiceNotes[_noteName];
    if (filePath != null) {
      try {
        await _player.startPlayer(
          fromURI: filePath,
          codec: Codec.pcm16WAV,
        );
      } catch (e) {
        tts.speak('Failed to play voice note: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play voice note: $e')),
        );
      }
    } else {
      tts.speak('Voice note not found.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice note not found.')),
      );
    }
    setState(() {
      _isAskingForPlayNote = false;
      _actionButtonText = 'Start';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta! < -10) {
            _askNoteName(isForPlayback: true);
          }
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 20),
              Text(_actionButtonText, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _startStopRecording,
                icon: _isRecording
                    ? const Icon(Icons.add_task)
                    : const Icon(Icons.mic),
                label: Text(''),
                style: ButtonStyle(
                  iconSize: MaterialStateProperty.all<double>(320),
                  backgroundColor: MaterialStateProperty.all(Colors.white),
                  iconColor: MaterialStateProperty.all(Colors.blue[600]),
                  padding: MaterialStateProperty.all(const EdgeInsets.all(0)),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0)),
                  ),
                ),
              ),
              const SizedBox(height: 50),
              Expanded(
                child: ListView.builder(
                  itemCount: _voiceNotes.length,
                  itemBuilder: (context, index) {
                    final noteName = _voiceNotes.keys.elementAt(index);
                    return ListTile(
                      title: Text(noteName),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            icon: Icon(Icons.play_arrow),
                            onPressed: () {
                              setState(() {
                                _noteName = noteName;
                              });
                              _playVoiceNote();
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              setState(() {
                                _noteName = noteName;
                              });
                              _deleteVoiceNote();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() => runApp(MaterialApp(
      home: VoiceNoteApp(),
    ));
