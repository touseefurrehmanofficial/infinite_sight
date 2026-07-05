import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../text_to_speech/text_to_speech.dart';
import 'package:speech_to_text/speech_to_text.dart';

class Voicereminder extends StatefulWidget {
  @override
  _VoicereminderState createState() => _VoicereminderState();
}

class _VoicereminderState extends State<Voicereminder> {
  final _speechToText = SpeechToText();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final TextToSpeechService flutterTts = TextToSpeechService();

  final TextEditingController _pauseForController =
      TextEditingController(text: '10');
  final TextEditingController _listenForController =
      TextEditingController(text: '30');
  int _notificationId = 0;
  List<Map<String, String>> _reminders = [];
  bool _newnote = false;
  bool _deleteNote = false;
  bool _speechEnabled = false;
  bool _isListening = false;
  String _wordsSpoken = '';
  String? _spokenDateWords;
  String? _spokenTimeWords;
  String? _spokenNoteWords;
  String _buttonText = "Voice Reminder";
  bool _spokenTime = false;
  bool _spokenDate = false;
  bool _spokenNote = false;
  bool _spokenYear = false;
  bool _spokenMonth = false;
  bool _spokenDay = false;
  bool _spokenHour = false;
  bool _spokenMin = false;
  bool _scheduleReminder = false;

  @override
  void initState() {
    _checkSpeechAvailability();
    _initialGuidelines();
    super.initState();
    tz.initializeTimeZones();
    final initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final initializationSettingsIOS = DarwinInitializationSettings();
    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
    _loadNotificationId();
    _loadReminders(); // Ensure the list is loaded and filtered
  }

  Future<void> _initialGuidelines() async {
    flutterTts.speak("Please Tap and provide details accordingly");
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

  void _startListening() async {
    final pauseFor = int.tryParse(_pauseForController.text);
    final listenFor = int.tryParse(_listenForController.text);
    if (!_isListening) {
      _isListening = true;
      _speechToText.listen(
        onResult: (val) => setState(() {
          _wordsSpoken = val.recognizedWords;
        }),
        listenFor: Duration(seconds: listenFor ?? 30),
        pauseFor: Duration(seconds: pauseFor ?? 10),
      );
    }
  }

  void _stopListening() {
    _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  Future<void> _loadNotificationId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationId = prefs.getInt('notification_id') ?? 0;
    });
  }

  Future<void> _incrementNotificationId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationId++;
    });
    await prefs.setInt('notification_id', _notificationId);
  }

  Future<void> _loadReminders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<Map<String, String>> loadedReminders = [];
    final now = DateTime.now();

    prefs.getKeys().forEach((key) {
      if (key.startsWith('note_')) {
        String? note = prefs.getString(key);
        String? datetime = prefs.getString('datetime_${key.split('_')[1]}');

        if (note != null && datetime != null) {
          DateTime scheduledDate = DateTime.parse(datetime);
          print('Scheduled date for $note: $scheduledDate');

          if (scheduledDate.isAfter(now)) {
            loadedReminders.add({'note': note, 'datetime': datetime});
          } else {
            // Remove past reminders from SharedPreferences
            prefs.remove(key);
            prefs.remove('datetime_${key.split('_')[1]}');
          }
        }
      }
    });

    setState(() {
      _reminders = loadedReminders;
    });
  }

  Future<void> _scheduleNotification() async {
    String _thisNote = '';
    if (_noteController.text.isEmpty ||
        _dateController.text.isEmpty ||
        _timeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields')),
      );
      flutterTts.speak("Please fill all fields");
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime? selectedDate;
    final DateTime? selectedTime;
    try {
      selectedDate = DateFormat('yyyy-MM-dd').parse(_dateController.text);
      selectedTime = DateFormat('HH:mm').parse(_timeController.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid date or time format')),
      );
      flutterTts.speak("Invalid date or time format");
      return;
    }

    final DateTime scheduledDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (scheduledDate.isBefore(now)) {
      flutterTts.speak("Selected time is in the past");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected time is in the past')),
      );
      return;
    } else {
      flutterTts.speak("Your reminder is saved successfully");
    }

    final tz.TZDateTime tzScheduledDate =
        tz.TZDateTime.from(scheduledDate, tz.local);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'your_channel_id',
      'your_channel_name',
      channelDescription: 'your_channel_description',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Schedule the notification and read the note using TTS
    await flutterLocalNotificationsPlugin.zonedSchedule(
      _notificationId,
      'Voice Reminder',
      _thisNote = _noteController.text,
      tzScheduledDate,
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: _notificationId.toString(),
    );

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('note_$_notificationId', _noteController.text);
    await prefs.setString(
        'datetime_$_notificationId', scheduledDate.toIso8601String());

    // Schedule text-to-speech
    final durationUntilReminder = scheduledDate.difference(now);
    Future.delayed(durationUntilReminder, () async {
      await flutterTts.speak(_thisNote);
    });

    await _incrementNotificationId();
    await _loadReminders(); // Refresh the list of reminders
  }

  Future<void> _onSelectNotification(String? payload) async {
    if (payload != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? note = prefs.getString('note_$payload');
      if (note != null) {
        await flutterTts.speak(note);
      }
    }
  }

  Future<void> _deleteReminder(String note) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? notificationId;

    // Find the notification ID for the given note
    for (String key in prefs.getKeys()) {
      if (key.startsWith('note_') && prefs.getString(key) == note) {
        notificationId = key.split('_')[1];
        break;
      }
    }
    if (notificationId == null) {
      _buttonText = "Reminder not exist.";
      flutterTts.speak(_buttonText);
    } else if (notificationId != null) {
      await flutterLocalNotificationsPlugin.cancel(int.parse(notificationId));
      await prefs.remove('note_$notificationId');
      await prefs.remove('datetime_$notificationId');

      setState(() {
        _reminders.removeWhere((reminder) => reminder['note'] == note);
      });
      _buttonText = "Your reminder is deleted successfully";
      flutterTts.speak(_buttonText);
    } else {
      flutterTts.speak("Something going wrong");
    }
  }

  Future<void> _onAction() async {
    _stopListening();
    setState(() {
      if (_newnote == false && _deleteNote == false) {
        _buttonText = "Add or delete";
        flutterTts.speak("Command");
        _speechToText.listen(onResult: (val) {
          String command = val.recognizedWords.toLowerCase();
          if (command.contains('add') ||
              command.contains('new reminder') ||
              command.contains('add reminder') ||
              command.contains('new')) {
            _newnote = true;
          }
          if (command.contains('delete') ||
              command.contains('remove') ||
              command.contains('delete reminder') ||
              command.contains('erase')) {
            _deleteNote = true;
          }
        });
      } else if (_newnote == true && _deleteNote == false) {
        if (_spokenTime == false) {
          if (_spokenHour == false && _spokenMin == false) {
            _buttonText = "Hour";
            flutterTts.speak("Hour");
            _startListening();
            _spokenHour = true;
          } else {
            _spokenTimeWords = _wordsSpoken;
            _buttonText = "Minutes";
            flutterTts.speak("Minutes");
            _wordsSpoken = '';
            _startListening();
            _spokenMin = true;
            _spokenTime = true;
          }
        } else if (_spokenTime == true && _spokenDate == false) {
          if (_spokenYear == false && _spokenMonth == false) {
            _spokenTimeWords = '$_spokenTimeWords:$_wordsSpoken';
            _buttonText = "Year";
            flutterTts.speak("Year");
            _wordsSpoken = '';
            _startListening();
            _spokenYear = true;
          } else if (_spokenYear == true && _spokenMonth == false) {
            _spokenDateWords = _wordsSpoken;
            _buttonText = "Month";
            flutterTts.speak("Month");
            _wordsSpoken = '';
            _startListening();
            _spokenMonth = true;
          } else {
            _spokenDateWords = '$_spokenDateWords-$_wordsSpoken';
            _buttonText = "Day";
            flutterTts.speak("Day");
            _wordsSpoken = '';
            _startListening();
            _spokenDay = true;
            _spokenDate = true;
          }
        } else if (_spokenTime == true &&
            _spokenDate == true &&
            _spokenNote == false) {
          _spokenDateWords = '$_spokenDateWords-$_wordsSpoken';
          _buttonText = "Speak Note";
          flutterTts.speak(_buttonText);
          _wordsSpoken = '';
          _startListening();
          _spokenNote = true;
        } else if (_spokenTime == true &&
            _spokenDate == true &&
            _spokenNote == true &&
            _scheduleReminder == false) {
          _spokenNoteWords = _wordsSpoken;
          flutterTts.speak("Tap to save reminder");
          _scheduleReminder = true;
        } else if (_scheduleReminder == true) {
          _buttonText = "Voice Reminder";
          _timeController.text = _spokenTimeWords ?? '';
          _dateController.text = _spokenDateWords ?? '';
          _noteController.text = _spokenNoteWords ?? '';
          _scheduleNotification();
          _loadReminders();
          _spokenTimeWords = '';
          _spokenDateWords = '';
          _spokenNoteWords = '';
          _spokenTime = false;
          _spokenDate = false;
          _spokenNote = false;
          _spokenHour = false;
          _spokenMin = false;
          _spokenYear = false;
          _spokenMonth = false;
          _spokenDay = false;
          _scheduleReminder = false;
          _newnote = false;
        } else {
          flutterTts
              .speak("Something going wrong Please give details properly");
        }
      } else if (_deleteNote == true && _newnote == false) {
        if (_spokenNote == false) {
          _buttonText = "Reminder name";
          flutterTts.speak(_buttonText);
          _wordsSpoken = '';
          _startListening();
          _spokenNote = true;
        } else if (_spokenNote == true) {
          _spokenNoteWords = _wordsSpoken;
          _deleteReminder(_spokenNoteWords!);
          _spokenNote = false;
          _deleteNote = false;
        } else {
          flutterTts.speak("Note not exists");
        }
      } else {
        flutterTts.speak("Please provide write action");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            SizedBox(height: 50.0),
            Text(_buttonText, style: const TextStyle(fontSize: 20)),
            SizedBox(height: 10.0),
            ElevatedButton.icon(
              onPressed: () async {
                _onAction();
              },
              icon: _scheduleReminder
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
            SizedBox(height: 20.0),
            Text(_wordsSpoken, style: const TextStyle(fontSize: 20)),
            SizedBox(height: 30.0),
            Expanded(
              child: _reminders.isEmpty
                  ? Center(child: Text('No reminders set'))
                  : ListView.builder(
                      itemCount: _reminders.length,
                      itemBuilder: (context, index) {
                        final reminder = _reminders[index];
                        final scheduledDate =
                            DateTime.parse(reminder['datetime']!);
                        return ListTile(
                          title: Text(reminder['note']!),
                          subtitle: Text(
                              'Date: ${DateFormat.yMd().format(scheduledDate)} - Time: ${DateFormat.jm().format(scheduledDate)}'),
                          trailing: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              _deleteReminder(reminder['note']!);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
