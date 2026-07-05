import 'dart:io';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:googleai_dart/googleai_dart.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';
import 'package:lottie/lottie.dart';


class Gemini extends StatefulWidget {
  const Gemini({super.key});

  @override
  State<Gemini> createState() => _GeminiState();
}

enum TtsState { playing, stopped }

class _GeminiState extends State<Gemini> {
  final _speechToText = SpeechToText();
  final translator = GoogleTranslator();
  static final _flutterTts = FlutterTts();
  final myApiKey = "YOUR_GOOGLE_AI_API_KEY"; // replace locally, do not commit real keys
  List<Content> conversationHistory = [];
  bool _isListening = false;
  String _wordsSpoken = '';
  // ignore: unused_field
  bool _speechEnabled = false;
  bool _speaking = false;
  bool _micIcon = false;
  bool spoken = false;
  bool noinput = false;
  TtsState ttsState = TtsState.stopped;

  bool get isPlaying => ttsState == TtsState.playing;
  bool get isStopped => ttsState == TtsState.stopped;

  @override
  void initState() {
    _initialGuidelines();
    super.initState();
    _checkSpeechAvailability();
    initTts();
  }

  dynamic initTts() {
    _flutterTts.setStartHandler(() {
      setState(() {
        ttsState = TtsState.playing;
      });
    });

    _flutterTts.setCompletionHandler(() {
      setState(() {
        if (spoken == true) {
          _micIcon = false;
          _speaking = false;
          _isListening = false;
          _wordsSpoken = '';
          spoken = false;
        }
        if (noinput == true) {
          _micIcon = true;
          noinput = false;
          _speaking = false;
          _startListening();
        }
      });
      ttsState = TtsState.stopped;
    });
  }

    Future<void> _initialGuidelines() async {
    _flutterTts.speak("Please Tap and ask question");
  }
  Future<void> _checkSpeechAvailability() async {
    final speechAvailable = await _speechToText.initialize(
      onStatus: (val) => print('onStatus: $val'),
      onError: (val) => print('onError: $val'),
    );
    setState(() {
      _speechEnabled = speechAvailable;
    });
  }

  Future<void> _speak(String text) async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
  }

  void _startListening() async {
    if (!_isListening) {
      _isListening = true;
      _speechToText.listen(
        onResult: (val) => setState(() {
          _wordsSpoken = val.recognizedWords;
        }),
      );
    }
  }

  void _stopListening() {
    _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  Future<void> _supportedLanguages() async {
    List<dynamic> languages = await _flutterTts.getLanguages;
    if (!languages.contains("ur-PK")) {
      _speak(
          "Urdu language pack is not installed on this device. Please install it from the device settings.");
    }
  }


  Future<void> _askQuestionAndGetAnswer() async {
    bool hindi = false;
    String forText = _wordsSpoken;
    String result;

    if (forText.isNotEmpty) {
      // Add current question to conversation history with "user" role
      conversationHistory.add(Content(
        role: 'user',
        parts: [Part(text: forText)],
      ));

      // Make API call with the conversation history
      final response = await GoogleAIClient(apiKey: myApiKey).generateContent(
        modelId: 'gemini-pro',
        request: GenerateContentRequest(
          contents: conversationHistory,
          generationConfig: GenerationConfig(temperature: 0.8),
        ),
      );

      String answer =
          response.candidates?.first.content?.parts?.first.text ?? "";

      // Add the answer to conversation history with "model" role
      conversationHistory.add(Content(
        role: 'model',
        parts: [Part(text: answer)],
      ));

      await translator.translate(answer).then((value) {
        result = value.sourceLanguage.name;
        hindi = (result == "Hindi");
      });

      if (hindi == true) {
        _supportedLanguages();
        await translator.translate(answer, from: "hi", to: "en").then((value) {
          answer = value.toString();
        });

        await translator.translate(answer, from: "en", to: "ur").then((value) {
          answer = value.toString();
          answer = answer.replaceAll('*', '');
        });
      } else {
        await _flutterTts.setLanguage("en-US");
        answer = answer.replaceAll('*', '');
      }

      _speak(answer);
      spoken = true;
    } else {
      _speak("Please ask your question again. I didn't hear it.");
      noinput = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child:
            // Column(
            //   children: [
            ElevatedButton.icon(
          onPressed: () async {
            setState(() {
              if (_micIcon == false && _speaking == false) {
                _micIcon = true;
                _startListening();
              } else if (_micIcon == true && _speaking == false) {
                _speaking = true;
                _stopListening();
                _askQuestionAndGetAnswer();
                _wordsSpoken = '';
              } else {
                _micIcon = false;
                _speaking = false;
                _isListening = false;
                _stopSpeaking();
              }
            });
          },
          icon: _speaking
              ? Lottie.asset("assets/speak.json", width: 300, height: 300)
              : (_micIcon
                  ? Lottie.asset("assets/mic_on.json", width: 300, height: 300)
                  : const Icon(Icons.mic_off)),
          label: const Text(""),
          style: ButtonStyle(
            iconSize: MaterialStateProperty.all<double>(
                300), // Set the size of the icon
            backgroundColor: MaterialStateProperty.all(Colors.white),
            iconColor: MaterialStateProperty.all(
                Colors.blue[600]), // Set the background color to transparent
            padding: MaterialStateProperty.all(
                const EdgeInsets.all(0)), // Set the padding to 0
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
            ), // Set the shape to RoundedRectangleBorder with no borderRadius
          ),
        ),
        //   ],
        // ),
      ),
    );
  }
}
