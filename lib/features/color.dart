import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:colornames/colornames.dart';
import '../text_to_speech/text_to_speech.dart';  // Ensure this import path is correct

class colorRecognition extends StatefulWidget {
  final CameraDescription camera;

  const colorRecognition({Key? key, required this.camera}) : super(key: key);

  @override
  _colorRecognitionState createState() => _colorRecognitionState();
}

class _colorRecognitionState extends State<colorRecognition> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final TextToSpeechService _tts = TextToSpeechService();
  bool _showColorNames = false;
  List<String> _colorNames = [];

  @override
  void initState() {
    _initialGuidelines();
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initialGuidelines() async {
    _tts.speak("Please Tap for taking picture");
  }

  Future<void> detectColors() async {
    await _initializeControllerFuture;

    final XFile picture = await _controller.takePicture();
    final PaletteGenerator generator = await PaletteGenerator.fromImageProvider(
      Image.file(File(picture.path)).image,
      size: Size(200, 200),
      maximumColorCount: 20,
    );

    List<PaletteColor> sortedColors = generator.paletteColors.toList();
    sortedColors.sort((a, b) => b.population.compareTo(a.population));
    List<Color> detectedColors = sortedColors.map((c) => c.color).toList();
    _colorNames = getColorNames(detectedColors.take(3).toList());

    String speechText = "This picture contains ";
    if (_colorNames.length == 0) {
      speechText += "${_colorNames[0]} color.";
    } else if (_colorNames.length == 1) {
      speechText += "${_colorNames[0]} and ${_colorNames[1]} colors.";
    } else if (_colorNames.length > 2) {
      speechText += "${_colorNames[0]}, ${_colorNames[1]}, and ${_colorNames[2]} colors.";
    }
    _tts.speak(speechText);

    setState(() {
      _showColorNames = true;
    });

    // Hide color names after 5 seconds (adjust duration as needed)
    Future.delayed(Duration(seconds: 5), () {
      setState(() {
        _showColorNames = false;
      });
    });
  }

  List<String> getColorNames(List<Color> colors) {
    return colors.map((color) {
      String name = ColorNames.guess(color);
      return name.isEmpty ? 'Unknown' : name;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: detectColors,
        child: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: CameraPreview(_controller),
                    ),
                  ),
                  if (_showColorNames)
                    Positioned(
                      bottom: 20,
                      width: MediaQuery.of(context).size.width,
                      child: Container(
                        padding: EdgeInsets.all(10),
                        color: Colors.black54,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: _colorNames
                              .map((name) => Text(
                                    name,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                ],
              );
            } else {
              return Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}
