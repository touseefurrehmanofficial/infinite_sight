# Infinite Sight

A Flutter accessibility app for visually impaired users. The entire app is voice-driven: a spoken command from the home screen routes to one of five camera/voice-based features, and every result is read back out loud via text-to-speech.

## Features

- **AI Assistant** (`lib/features/ai_assistant.dart`) — Ask a question by voice; it's sent to Google's Gemini API (with conversation history kept for follow-ups) and the answer is spoken back. Detects Hindi/Urdu responses and translates them via `translator` before speaking.
- **Currency Recognition** (`lib/features/currency.dart`) — Takes a photo of a Pakistani banknote and classifies it on-device with a TensorFlow Lite model (`assets/model.tflite`), then speaks the denomination and a running total.
- **Color Recognition** (`lib/features/color.dart`) — Takes a photo, extracts the dominant colors with `palette_generator`, maps them to human-readable names via `colornames`, and speaks the top three.
- **Voice Notes** (`lib/features/voice_notes.dart`) — Fully voice-controlled audio recorder: say "add"/"listen"/"delete", then the note name, to record, play back, or remove a note. Notes are stored as WAV files with a name→path index persisted in JSON.
- **Voice Reminders** (`lib/features/voice_reminder.dart`) — Capture a note, date, and time by voice and schedule a local notification via `flutter_local_notifications`.

Navigation between features works both by tapping the bottom nav bar and by speaking the feature name from the home page (`lib/home_page/home_page.dart`).

## Tech stack

- Flutter/Dart, targeting Android, iOS, Windows, Linux, macOS, and web.
- `camera`, `image_picker` — capturing photos for the vision features.
- `tflite_v2` — on-device inference for currency recognition.
- `palette_generator`, `colornames` — color extraction/naming.
- `speech_to_text`, `flutter_tts`, `flutter_sound` — voice input/output and audio recording.
- `googleai_dart`, `translator` — the AI assistant and its translation fallback.
- `flutter_local_notifications`, `android_alarm_manager_plus`, `shared_preferences`, `path_provider` — reminders and local persistence.

## Currency model

The currency classifier is a CNN trained in `ml_model/model.ipynb` (TensorFlow/Keras) on photos of Pakistani banknotes, then exported to TFLite for use in the app:

- **Data**: ~180 photos per class of the 10, 20, 50, 100, 500, 1000, and 5000 rupee notes, each split into front/back — 14 classes total, in train/val/test folders.
- **Augmentation**: `ImageDataGenerator` with rescaling, rotation, width/height shift, shear, zoom, and horizontal flip, to make the small dataset generalize.
- **Architecture**: 3 stacked Conv2D + MaxPooling2D blocks (32 → 64 → 128 filters) → Flatten → Dense(512, relu) → Dense(14, softmax).
- **Training**: Adam optimizer, categorical cross-entropy, 400 epochs.
- **Export**: saved as `.h5`, converted to `assets/model.tflite` with `assets/labels.txt` for on-device inference.

Color recognition does not use a trained model — it's palette extraction on the captured image.

## Project structure

```
lib/
  main.dart                  # app entry point, camera init
  home_page/                 # splash screen, home page + voice command router
  features/                  # the five features described above
  text_to_speech/            # shared TTS wrapper service
assets/                      # model.tflite, labels.txt, icons, animations
ml_model/model.ipynb         # currency model training notebook
android/ ios/ linux/ macos/ web/ windows/   # platform runners
```

## Getting started

```bash
flutter pub get
flutter run
```

You'll need a device/emulator with camera and microphone access, and a Google AI (Gemini) API key set in `lib/features/ai_assistant.dart` (`myApiKey`) for the AI Assistant feature — the committed value is a placeholder.
