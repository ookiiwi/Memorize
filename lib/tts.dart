import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused, continued }

late final FlutterTts flutterTts;
final ttsState = ValueNotifier(TtsState.stopped);
final isFlutterTtsInit = ValueNotifier(false);

Future<void> init() async {
  flutterTts = FlutterTts();

  await flutterTts.awaitSpeakCompletion(true);

  if (Platform.isAndroid) {
    await _getDefaultEngine();
    await _getDefaultVoice();
  }

  flutterTts.setCompletionHandler(() {
    print("Complete");
    ttsState.value = TtsState.stopped;
  });

  flutterTts.setCancelHandler(() {
    print("Cancel");
    ttsState.value = TtsState.stopped;
  });

  flutterTts.setPauseHandler(() {
    print("Paused");
    ttsState.value = TtsState.paused;
  });

  flutterTts.setContinueHandler(() {
    print("Continued");
    ttsState.value = TtsState.continued;
  });

  flutterTts.setErrorHandler((msg) {
    print("error: $msg");
    ttsState.value = TtsState.stopped;
  });

  await flutterTts.setLanguage('ja-JP');

  isFlutterTtsInit.value = true;
}

Future _getDefaultEngine() async {
  var engine = await flutterTts.getDefaultEngine;
  if (engine != null) {
    print('Tts engine: $engine');
  }
}

Future _getDefaultVoice() async {
  var voice = await flutterTts.getDefaultVoice;
  if (voice != null) {
    print('Tts voice: $voice');
  }
}

Future speak({
  required String text,
  double volume = 0.5,
  double pitch = 1.0,
  double rate = 0.5,
}) async {
  await flutterTts.setVolume(volume);
  await flutterTts.setSpeechRate(rate);
  await flutterTts.setPitch(pitch);

  if (text.isNotEmpty) {
    await flutterTts.speak(text);
  }
}

Future<bool> stop() async {
  if (ttsState.value == TtsState.stopped) return true;

  return await flutterTts.stop() == 1;
}

Future<bool> pause() async {
  if (ttsState.value == TtsState.paused) return true;

  return await flutterTts.pause() == 1;
}
