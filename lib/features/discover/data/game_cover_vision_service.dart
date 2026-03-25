import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class VisionCoverResult {
  const VisionCoverResult({required this.query});

  final String query;
}

class GameCoverVisionService {
  Future<VisionCoverResult?> extractQueryFromImagePath(String imagePath) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }

    // We proberen eerst 'gemini-1.5-flash-latest', en als fallback de oudere 'gemini-pro-vision'
    var model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: apiKey,
    );

    final bytes = await File(imagePath).readAsBytes();
    final prompt = TextPart('''
Analyze this image of a video game physical case/cover.
Identify the full exact title of the video game shown.
Return ONLY the title of the game. Do not add any extra text, platform names, or punctuation.
If you cannot identify any game, return exactly: UNKNOWN
''');
    final imageParts = [DataPart('image/jpeg', bytes)];

    try {
      GenerateContentResponse? response;
      try {
        response = await model.generateContent([
          Content.multi([prompt, ...imageParts]),
        ]);
      } catch (e) {
        print('--- AI FALLBACK DEBUG ---');
        print(
          'gemini-1.5-flash-latest mislukt, probeer gemini-pro-vision. Fout: $e',
        );
        model = GenerativeModel(model: 'gemini-pro-vision', apiKey: apiKey);
        response = await model.generateContent([
          Content.multi([prompt, ...imageParts]),
        ]);
      }

      final text = response?.text?.trim() ?? '';
      print('--- AI RESPONSE DEBUG ---');
      print('Titel gevonden: "$text"');
      print('-------------------------');

      if (text.isEmpty || text == 'UNKNOWN') {
        return null;
      }

      return VisionCoverResult(query: text);
    } catch (e) {
      print('--- AI ERROR DEBUG ---');
      print(e);
      print('----------------------');
      // In case of rate limits, wrong api key, or other errors
      throw Exception(e.toString());
    }
  }
}
