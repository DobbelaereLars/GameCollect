import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrCoverResult {
  const OcrCoverResult({
    required this.query,
    required this.candidates,
    required this.isLikelyGameCover,
  });

  final String query;
  final List<String> candidates;
  final bool isLikelyGameCover;
}

class GameCoverOcrService {
  GameCoverOcrService({TextRecognizer? textRecognizer})
    : _textRecognizer =
          textRecognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _textRecognizer;

  Future<OcrCoverResult?> extractQueryFromImagePath(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    final candidates = <_OcrCandidate>[];

    double maxLineArea = 0;
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final area = _areaOf(line.boundingBox);
        if (area > maxLineArea) {
          maxLineArea = area;
        }
      }
    }

    final normalizedMaxArea = math.max(maxLineArea, 1).toDouble();

    for (final block in recognizedText.blocks) {
      final blockText = _sanitizeLine(block.text);
      if (_isValidCandidate(blockText)) {
        candidates.add(
          _OcrCandidate(
            text: blockText,
            score: _score(
              value: blockText,
              box: block.boundingBox,
              maxArea: normalizedMaxArea,
              isBlock: true,
            ),
          ),
        );
      }

      for (final line in block.lines) {
        final cleaned = _sanitizeLine(line.text);
        if (_isValidCandidate(cleaned)) {
          candidates.add(
            _OcrCandidate(
              text: cleaned,
              score: _score(
                value: cleaned,
                box: line.boundingBox,
                maxArea: normalizedMaxArea,
                isBlock: false,
              ),
            ),
          );
        }
      }
    }

    if (candidates.isEmpty) {
      final fallback = _sanitizeLine(recognizedText.text);
      if (!_isValidCandidate(fallback)) {
        return null;
      }

      return OcrCoverResult(
        query: fallback,
        candidates: [fallback],
        isLikelyGameCover: _looksLikeGameTitle(fallback),
      );
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));

    final uniqueCandidates = <String>[];
    final seen = <String>{};

    for (final candidate in candidates) {
      if (!seen.contains(candidate.text)) {
        seen.add(candidate.text);
        uniqueCandidates.add(candidate.text);
      }
      if (uniqueCandidates.length >= 5) {
        break;
      }
    }

    final best = candidates.first;
    final likelyByScore = best.score >= 140;
    final likelyByTitleShape = _looksLikeGameTitle(best.text);

    return OcrCoverResult(
      query: best.text,
      candidates: uniqueCandidates,
      isLikelyGameCover: likelyByScore && likelyByTitleShape,
    );
  }

  void dispose() {
    _textRecognizer.close();
  }

  String _sanitizeLine(String value) {
    final collapsed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    final cleaned = collapsed.replaceAll(RegExp(r"[^\w\s\-':]"), ' ').trim();
    return cleaned.replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isValidCandidate(String value) {
    if (value.length < 3) {
      return false;
    }

    if (_containsBlacklistedToken(value)) {
      return false;
    }

    final letters = RegExp(r'[A-Za-z]').allMatches(value).length;
    final digits = RegExp(r'\d').allMatches(value).length;

    // Avoid OCR noise like short codes or mostly numeric strings.
    return letters >= 3 && letters >= digits;
  }

  bool _containsBlacklistedToken(String value) {
    final lowercase = value.toLowerCase();
    const blacklist = [
      'www',
      '.com',
      '.be',
      '.info',
      'pegi',
      'esrb',
      'usk',
      'nintendo switch',
      'nintendo',
    ];

    for (final token in blacklist) {
      if (lowercase.contains(token)) {
        return true;
      }
    }

    return false;
  }

  bool _looksLikeGameTitle(String value) {
    final words = value.split(' ').where((word) => word.isNotEmpty).toList();
    if (words.length >= 2) {
      return true;
    }

    final lowercase = value.toLowerCase();
    if (RegExp(r'\d').hasMatch(lowercase)) {
      return true;
    }

    // Allow short one-word titles only when they look like a proper title.
    return words.length == 1 &&
        value.length >= 4 &&
        !lowercase.contains('www') &&
        !_containsBlacklistedToken(value);
  }

  int _score({
    required String value,
    required Rect? box,
    required double maxArea,
    required bool isBlock,
  }) {
    final words = value.split(' ').where((word) => word.isNotEmpty).length;
    final letters = RegExp(r'[A-Za-z]').allMatches(value).length;
    final area = _areaOf(box);
    final areaRatio = area / maxArea;
    final normalizedLengthBonus = value.length.clamp(0, 36);

    var score = (words * 22) + (letters * 2) + normalizedLengthBonus;

    // Game titles usually occupy larger regions than rating badges/footer text.
    score += (areaRatio * 120).round();

    // Full block text often captures multi-line titles more accurately.
    if (isBlock) {
      score += 12;
    }

    final lowercase = value.toLowerCase();
    if (lowercase.contains('hd') || lowercase.contains('remastered')) {
      score += 8;
    }

    if (RegExp(r"^[A-Za-z0-9\s\-':]+$").hasMatch(value)) {
      score += 4;
    }

    if (words == 1 && value.length < 6) {
      score -= 15;
    }

    return score;
  }

  double _areaOf(Rect? box) {
    if (box == null) {
      return 0;
    }

    return box.width.abs() * box.height.abs();
  }
}

class _OcrCandidate {
  const _OcrCandidate({required this.text, required this.score});

  final String text;
  final int score;
}
