import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../text_to_speech/text_to_speech.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:tflite_v2/tflite_v2.dart';

int total = 0;

class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;
  const TakePictureScreen({
    Key? key,
    required this.camera,
  }) : super(key: key);

  @override
  _TakePictureScreenState createState() => _TakePictureScreenState();
}

class _TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final TextToSpeechService _textToSpeechService = TextToSpeechService();

  @override
  void initState() {
    super.initState();
    _initialGuidelines();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  Future<void> _initialGuidelines() async {
    _textToSpeechService.speak("Please Tap for taking currency picture");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () async {
          try {
            await _initializeControllerFuture;
            final XFile file = await _controller.takePicture();
            final imagePath = file.path;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(imagePath),
              ),
            );
          } catch (e) {
            print(e);
          }
        },
        child: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return CameraPreview(_controller);
            } else {
              return Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}

class DisplayPictureScreen extends StatefulWidget {
  final String imagePath;
  DisplayPictureScreen(this.imagePath);
  @override
  _DisplayPictureScreenState createState() => _DisplayPictureScreenState();
}

class _DisplayPictureScreenState extends State<DisplayPictureScreen> {
  late List op;
  late Image img;
  final TextToSpeechService _textToSpeechService = TextToSpeechService();

  @override
  void initState() {
    super.initState();
    loadModel().then((value) {
      setState(() {});
    });
    img = Image.file(File(widget.imagePath));
    classifyImage(widget.imagePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Display the Picture')),
      body: Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(child: Center(child: img)),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  
  Future<void> runTextToSpeech(String outputMoney, int totalMoney) async {
    FlutterTts flutterTts = FlutterTts();

    String speakString;
    if (totalMoney == 0) {
      speakString = "you have $outputMoney rupees";
    } else {
      speakString =
          "$outputMoney rupees, Your total is now rupees, $totalMoney";
    }
    await flutterTts.setSpeechRate(0.8);
    await flutterTts.awaitSpeakCompletion(true);
    await flutterTts.speak(speakString);
  }

  classifyImage(String image) async {
    var output = await Tflite.runModelOnImage(
      path: image,
      numResults: 5,
      threshold: 0.5,
      imageMean: 127.5,
      imageStd: 127.5,
    );

    op = output!;
    if (op != null) {
      String result = op[0]["label"];
      print("total no :$op");
      if (total == 0) {
        _textToSpeechService.speak("you have $result rupees");
        total += int.parse(result);
      } else {
        total += int.parse(result);
        _textToSpeechService.speak(
            "Now you have $result rupees more , So total is $total rupees");
      }
    } else {
      _textToSpeechService.speak("No note found");
    }
  }

  loadModel() async {
    await Tflite.loadModel(
        model: "assets/model.tflite", labels: "assets/labels.txt");
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }
}
