import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechService {
  final FlutterTts _flutterTts = FlutterTts();

  TextToSpeechService._privateConstructor() {
    _initHandlers();
  }

  static final TextToSpeechService _instance = TextToSpeechService._privateConstructor();
  factory TextToSpeechService() => _instance;

  void _initHandlers() {
    _flutterTts.setStartHandler(() {
      print("Speech started");
    });

    _flutterTts.setCompletionHandler(() {
      print("Speech completed");
    });

    _flutterTts.setErrorHandler((message) {
      print("Speech error: $message");
    });
  }

  Future<void> speak(String text,) async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _flutterTts.speak(text);
    }
  }
  Future<void> fist(String text, {required void Function() onComplete}) async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }

  Future<void> setLanguage(String language) async {
    await _flutterTts.setLanguage(language);
  }

  Future<bool> isLanguageInstalled(String language) async {
    return await _flutterTts.isLanguageInstalled(language);
  }
}
