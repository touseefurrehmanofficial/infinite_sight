// home_page.dart
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/ai_assistant.dart';
import '../features/currency.dart';
import '../features/color.dart';
import '../features/voice_reminder.dart';
import '../features/voice_notes.dart';
import '../text_to_speech/text_to_speech.dart';

class HomePage extends StatefulWidget {
  final CameraDescription camera;
  const HomePage({Key? key, required this.camera}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextToSpeechService _tts = TextToSpeechService();
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  bool _isFirstTime = true;
  String wordspoken = "";

  final PageController _pageController = PageController(initialPage: 0);
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  void _initializeSpeech() async {
    bool available = await _speechToText.initialize(
        onError: (val) => print('Error initializing speech: $val'),
        onStatus: (val) => print('Speech status: $val'));

    if (!available) {
      print("The user has denied the use of speech recognition.");
    } else {
      print("Speech initialization successful.");
      _initializeTtsAndSpeech();
    }
  }

  void _initializeTtsAndSpeech() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasSpoken = prefs.getBool('hasSpoken') ?? false;

    if (!hasSpoken) {
      _tts.speak(
          "Menu: AI Assistant, Currency Recognition, Color Recognition, Voice Notes, Reminder");
      prefs.setBool('hasSpoken', true);
    } else {
      _tts.speak("How can I assist you?");
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speechToText.stop();
      setState(() {
        _isListening = false;
      });
    }
  }

  void _handleCommand() {
    _speechToText.listen(
      onResult: (val) {
        String command = val.recognizedWords.toLowerCase();
        if (command.isNotEmpty) {
          if (command == "ai assistant" ||
              command == "assistant" ||
              command == "chatbot") {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const Gemini()));
          } else if (command == "currency recognition" ||
              command == "note recognition" ||
              command == "currency" ||
              command == "rupees recognition" ||
              command == "rupees") {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        TakePictureScreen(camera: widget.camera)));
          } else if (command == "color recognition" || command == "color") {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        colorRecognition(camera: widget.camera)));
          } else if (command == "voice notes" ||
              command == "notes" ||
              command == "keep notes") {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => VoiceNoteApp()));
          } else if (command == "reminder" ||
              command == "voice reminder" ||
              command == "alarm" ||
              command == "set alarm") {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => Voicereminder()));
          } else if (command == "menu" || command == "main menu") {
            _tts.speak(
                "AI Assistant, Currency Recognition, Color Recognition, Voice Notes, Reminder");
          } else {
            _tts.speak("Sorry, I did not understand that. Please repeat. ");
          }
        } else {
          _tts.speak("Please choose option from menu.");
        }
      },
      listenFor: Duration(seconds: 5),
      pauseFor: Duration(seconds: 5),
      partialResults: false,
      onSoundLevelChange: null,
      cancelOnError: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 50, 68, 228),
        centerTitle: true,
        title: const Text(
          'Infinite Sight',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: [
          _buildHomePage(),
          Gemini(),
          TakePictureScreen(camera: widget.camera),
          VoiceNoteApp(),
          colorRecognition(camera: widget.camera),
          Voicereminder(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assistant),
            label: 'AI Assistant',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.money),
            label: 'Currency Recognition',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note),
            label: 'Voice Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.color_lens),
            label: 'Color Recognition',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.alarm),
            label: 'Reminder',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Color.fromARGB(255, 50, 68, 228),
        unselectedItemColor: Colors.black,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          _pageController.jumpToPage(index);
        },
      ),
    );
  }

  Widget _buildHomePage() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () async {
          setState(() {
            if (_isListening == false) {
              _handleCommand();
            } else {
              _stopListening();
            }
          });
        },
        icon: const Icon(Icons.mic),
        label: const Text(""),
        style: ButtonStyle(
          iconSize: MaterialStateProperty.all<double>(350),
          backgroundColor: MaterialStateProperty.all(Colors.white),
          iconColor: MaterialStateProperty.all(Colors.blue),
          padding: MaterialStateProperty.all(const EdgeInsets.all(0)),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speechToText.stop();
    _speechToText.cancel();
    _tts.stopSpeaking();
    super.dispose();
  }
}
