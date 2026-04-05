import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CodeLensResult {
  final String title;
  final String description;

  const CodeLensResult({required this.title, required this.description});
}

class CustomLensUploadView extends StatefulWidget {
  final File imageFile;
  final ValueChanged<CodeLensResult>? onResult;
  final ValueChanged<String>? onStatus;
  final ValueChanged<String>? onError;

  const CustomLensUploadView({
    super.key,
    required this.imageFile,
    this.onResult,
    this.onStatus,
    this.onError,
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

    // Voorkom de Google Cookie popup ("Voordat je verdergaat")
    final cookieManager = WebViewCookieManager();
    cookieManager.setCookie(
      const WebViewCookie(
        name: 'CONSENT',
        value: 'YES+cb.20230501-00-p0.base+FX+343',
        domain: '.google.com',
        path: '/',
      ),
    );
    cookieManager.setCookie(
      const WebViewCookie(
        name: 'SOCS',
        value: 'CAESHAgBEhJnd3NfMjAyMzA4MDktMF9SQzIaAm5sIAEaBgiA_LyaBg',
        domain: '.google.com',
        path: '/',
      ),
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3.1 Mobile/15E148 Safari/604.1',
      )
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
            if (!_didUpload &&
                (url == 'about:blank' ||
                    url.startsWith('data:') ||
                    url.startsWith('file://') ||
                    url == 'https://lens.google.com/')) {
              _injectAndUpload();
            } else if (url.contains('lens.google.com') ||
                url.contains('google.com')) {
              _injectScraper();
            }
          },
          onWebResourceError: (error) {
            // Treat specific errors as network issues
            if (error.errorType == WebResourceErrorType.hostLookup ||
                error.errorType == WebResourceErrorType.timeout ||
                error.errorType == WebResourceErrorType.unknown) {
              widget.onError?.call('NETWORK_ERROR');
            } else {
              widget.onError?.call('ERROR');
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
    await _controller.loadHtmlString(html, baseUrl: 'https://lens.google.com/');
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

  // Controleer direct of er een Google Cookie / GDPR popup in beeld staat en klik deze automatisch weg.
  const buttons = document.querySelectorAll('button, [role="button"], span');
  for (const b of buttons) {
    const bText = (b.innerText || '').toLowerCase().trim();
    if (bText === 'alles accepteren' || bText === 'akkoord' || bText === 'accept all' || bText === 'accepteren') {
       postStatus('Cookies accepteren...');
       b.click();
       return; // Webview zal na de klik vanzelf navigeren, scraper wordt daarna opnieuw geladen.
    }
  }

  // Google triggers AI Overviews (SGE) sneller als er een beetje gescrolld is of getikt.
  // We triggeren een soepele scroll naar beneden.
  window.scrollBy({ top: 400, left: 0, behavior: 'smooth' });

  // Google constantly changes DOM. We use generic scraping tactics.
  function scrapeAndPost(){
    let title = '';
    let desc = '';
    let isGameRelated = false;
    let foundBoldText = false;

    // Vervang alle vaste keywords met uitsluitend een strikte check op het woord "spel" of "game".
    // Door \b (woordgrenzen) te gebruiken, keuren we "spelcomputer" of "spelcontroller" af, 
    // want die hebben geen scheidingsteken. Iets als "3Ds-spel" of "ps4-game" mag wel door.
    const lowerBody = document.body.innerText.toLowerCase();
    
    const gameMatches = lowerBody.match(/\\b(game|games|spel|spellen)\\b/g);
    if (gameMatches && gameMatches.length > 0) {
      isGameRelated = true;
    }

    // Sluit gezelschapsspellen en bordspellen nadrukkelijk uit
    const boardGameKeywords = ['gezelschapsspel', 'gezelschapsspellen', 'bordspel', 'bordspellen', 'board game', 'board games', 'boardgame'];
    if (boardGameKeywords.some(kw => lowerBody.includes(kw))) {
      isGameRelated = false;
    }

    // Veranderd: filter metadata lables eruit
    const invalidTitleKeywords = ['zoekresultaten', 'visuele overeenkomsten', 'overzicht'];
    
    // Tactic 1: Look for bold text within an AI overview or a descriptive paragraph
    const boldElements = document.querySelectorAll('b, strong');
    for (const el of boldElements) {
      const text = el.innerText.trim();
      const lowerText = text.toLowerCase();
      
      const isSkippedKeyword = invalidTitleKeywords.some(keyword => lowerText.includes(keyword));
      
      if (text.length > 2 && text.length < 60 && !isSkippedKeyword) {
         const parentText = (el.parentElement.innerText || '').trim();
         if (parentText.length > 20 && parentText.length < 400) { 
            const isSingleWordWithColon = !lowerText.includes(' ') && lowerText.endsWith(':');
            const isInvalidMetadata = ['platform', 'genre', 'model', 'accountnaam', 'account', 'username', 'gebruikersnaam'].includes(lowerText);
            
            if (isSingleWordWithColon || isInvalidMetadata) {
               postResult("ERROR_NOT_A_GAME", "");
               return;
            }
            
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
          const lowerText = text.toLowerCase();
          
          const isSkippedKeyword = invalidTitleKeywords.some(keyword => lowerText.includes(keyword));
          
          if (text.length > 2 && !isSkippedKeyword) {
             const isSingleWordWithColon = !lowerText.includes(' ') && lowerText.endsWith(':');
             const isInvalidMetadata = ['platform', 'genre', 'model', 'accountnaam', 'account', 'username', 'gebruikersnaam'].includes(lowerText);
             
             if (isSingleWordWithColon || isInvalidMetadata) {
                postResult("ERROR_NOT_A_GAME", "");
                return;
             }
             
             title = text;
             break;
          }
       }
    }

    // Extra check op ongewenste onderwerpen (zoals hardware of programmeer-software) in de titel
    if (title) {
       const lowerTitle = title.toLowerCase();
       const negativeKeywords = [
           'console', 'controller', 'headset', 'ssd', 'hard drive', 'harde schijf', 
           'laptop', 'monitor', 'televisie', 'television', 'muis', 'mouse', 
           'toetsenbord', 'keyboard', 'smartphone', 'iphone', 'tablet',
           'visual studio', 'code editor', 'oordopjes', 'earbuds',
           'portable ssd', 'solid state', 'kabel', 'cable', 'hoesje', 'case'
       ];
       for (const nkw of negativeKeywords) {
         if (lowerTitle.includes(nkw) || (lowerTitle === 'playstation 5' || lowerTitle === 'xbox series x')) {
            postResult("ERROR_NOT_A_GAME", "");
            return;
         }
       }
    }

    // VOORDAT WE RESULTATEN POSTEN, CHECK EERST OF HET EEN GAME IS.
    if (!isGameRelated) {
       postResult("ERROR_NOT_A_GAME", "");
       return;
    }

    // If completely empty or no bold text found (AI overview niet getriggerd)
    if (!foundBoldText || !title) {
       postResult("ERROR_NO_RESULTS", "");
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
