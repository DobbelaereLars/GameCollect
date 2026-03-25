import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';

class CodeLensResult {
  final String title;
  final String description;

  const CodeLensResult({required this.title, required this.description});
}

class CustomLensUploadView extends StatefulWidget {
  final File imageFile;
  final ValueChanged<CodeLensResult>? onResult;
  final ValueChanged<String>? onStatus;

  const CustomLensUploadView({
    super.key,
    required this.imageFile,
    this.onResult,
    this.onStatus,
  });

  @override
  State<CustomLensUploadView> createState() => _CustomLensUploadViewState();
}

class _CustomLensUploadViewState extends State<CustomLensUploadView> {
  late final WebViewController _controller;
  bool _didUpload = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'CustomResultHandler',
        onMessageReceived: (msg) {
          final text = msg.message;

          if (text.startsWith('STATUS|')) {
            widget.onStatus?.call(text.substring('STATUS|'.length));
            return;
          }

          final parts = text.split('\n');
          final title = parts.isNotEmpty ? parts[0].trim() : '';
          final description = parts.length > 1
              ? parts.sublist(1).join('\n').trim()
              : '';

          if (title.isNotEmpty && title != "undefined") {
            widget.onResult?.call(
              CodeLensResult(title: title, description: description),
            );
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (url.startsWith('file://')) {
              _injectAndUpload();
            } else if (url.contains('lens.google.com') ||
                url.contains('google.com')) {
              _injectScraper();
            }
          },
        ),
      )
      ..setBackgroundColor(Colors.white);

    _loadLocalHtml();
  }

  Future<void> _loadLocalHtml() async {
    const html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Google Lens Upload</title>
  <style>
    html, body {
      margin: 0; padding: 0; height: 100%; width: 100%;
      font-family: 'Helvetica Neue', sans-serif;
      display: flex; justify-content: center; align-items: center;
      background: rgba(255,255,255,0.6);
    }
    form, canvas { display: none; }
  </style>
</head>
<body>
  <form id="uploadForm" enctype="multipart/form-data" method="POST" action="https://lens.google.com/upload">
    <input type="file" name="encoded_image" id="fileInput" accept="image/*">
    <input type="submit" value="Upload">
  </form>
  <canvas id="canvas"></canvas>
  <script>
    function injectAndSubmit(base64String) {
      try {
        const canvas = document.getElementById('canvas');
        const ctx = canvas.getContext('2d');
        const image = new Image();
        image.onload = function () {
          canvas.width = image.width;
          canvas.height = image.height;
          ctx.drawImage(image, 0, 0);
          canvas.toBlob(function (blob) {
            try {
              const file = new File([blob], 'upload.jpg', { type: 'image/jpeg' });
              const dataTransfer = new DataTransfer();
              dataTransfer.items.add(file);
              const input = document.getElementById('fileInput');
              input.files = dataTransfer.files;
              document.getElementById('uploadForm').submit();
            } catch (e) {
              console.error('Form submit failed', e);
            }
          }, 'image/jpeg', 0.95);
        };
        image.src = 'data:image/jpeg;base64,' + base64String;
      } catch (err) {
        console.error('Submit failed', err);
      }
    }
  </script>
</body>
</html>
''';
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/custom_lens_upload_${DateTime.now().millisecondsSinceEpoch}.html',
    );
    await file.writeAsString(html);
    await _controller.loadRequest(Uri.file(file.path));
  }

  Future<void> _injectAndUpload() async {
    if (_didUpload) return;
    _didUpload = true;

    widget.onStatus?.call('uploading');

    final bytes = await widget.imageFile.readAsBytes();
    final b64 = base64Encode(bytes).replaceAll('\n', '');

    await _controller.runJavaScript("injectAndSubmit('$b64');");
  }

  Future<void> _injectScraper() async {
    widget.onStatus?.call('Analyseren (AI overzicht)...');

    final js = '''
(function(){
  function postStatus(s){
    try{ window.CustomResultHandler && window.CustomResultHandler.postMessage('STATUS|' + s); }catch(_){}
  }

  function postResult(t, d){
    try{ window.CustomResultHandler && window.CustomResultHandler.postMessage((t||'') + "\\n" + (d||'')); }catch(_){}
  }

  // Google constantly changes DOM. We use generic scraping tactics.
  function scrapeAndPost(){
    let title = '';
    let desc = '';
    let isGameRelated = false;
    let foundBoldText = false;

    // Check if the page contains words that indicate it's a game/console
    const lowerBody = document.body.innerText.toLowerCase();
    if (lowerBody.includes('game') || lowerBody.includes('playstation') || lowerBody.includes('xbox') || lowerBody.includes('nintendo') || lowerBody.includes('wii') || lowerBody.includes('sega')) {
      isGameRelated = true;
    }

    // Tactic 1: Look for bold text within an AI overview or a descriptive paragraph
    const boldElements = document.querySelectorAll('b, strong');
    for (const el of boldElements) {
      const text = el.innerText.trim();
      if (text.length > 2 && text.length < 60 && !text.toLowerCase().includes('zoekresultaten')) {
         const parentText = (el.parentElement.innerText || '').trim();
         if (parentText.length > 20 && parentText.length < 400) { 
            title = text;
            foundBoldText = true;
            break;
         }
      }
    }

    // Tactic 2: Grab the biggest meaningful headings
    if (!title || title.length < 2) {
       const headings = document.querySelectorAll('h1, h2, h3, .BVG0Nb, .g h3');
       for (const h of headings) {
          const text = h.innerText.trim();
          if (text.length > 2 && 
              !text.toLowerCase().includes('zoekresultaten') && 
              !text.toLowerCase().includes('visuele overeenkomsten') &&
              !text.toLowerCase().includes('overzicht')) {
             title = text;
             break;
          }
       }
    }

    // If completely empty or no bold text found (AI overview niet getriggerd)
    if (!foundBoldText || !title) {
       postResult("ERROR_NO_RESULTS", "");
       return;
    }

    // if we found a title but the overall page doesn't mention game keywords
    if (!isGameRelated) {
       postResult("ERROR_NOT_A_GAME", "");
       return;
    }

    postResult(title, desc);
  }

  // We wait exactly 3.5 seconds for the page (en de AI overview animatie) to render fully then scrape it, 
  // to avoid missing dynamic elements in AI overviews.
  setTimeout(scrapeAndPost, 3500);
})();
    ''';

    await _controller.runJavaScript(js);
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
