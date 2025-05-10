import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class FreePage extends StatefulWidget {
  @override
  _FreePageState createState() => _FreePageState();
}

class _FreePageState extends State<FreePage> {
  // WebView controllers cache
  final Map<String, WebViewController> _controllerCache = {};

  // Track list
  final List<Map<String, String>> tracks = [
    {'id': "4QHKR48C18rwlpSYW6rH7p"},
    {'id': "3pPe4F2kFRp9ipARwxFmQr"},
    {'id': "2MFs3zQcS0MuIjuyyG85fV"},
    {'id': "0RMmME0OhJcrWtnb2kZMHL"},
    {'id': "70sMnVjOXAbZCH5USpGuOG"},
  ];

  @override
  void initState() {
    super.initState();
    _preloadWebViews();
  }

  void _preloadWebViews() {
    for (final track in tracks) {
      // Create controller first
      final controller = WebViewController()
        ..setBackgroundColor(Colors.transparent)
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36'
        );

      // Store in cache before setting navigation delegate
      _controllerCache[track['id']!] = controller;

      // Now set navigation delegate with cached controller
      controller.setNavigationDelegate(NavigationDelegate(
        onPageFinished: (String url) {
          // No need to cache again since we already cached it
        },
      ));

      // Finally load the request
      controller.loadRequest(Uri.parse(
          'https://open.spotify.com/embed/track/${track['id']}?utm_source=generator'
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'BANGLİST',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                return _buildTrackCard(track);
              },
            ),
          ),
          _buildBottomSection(),
        ],
      ),
    );
  }

  Widget _buildTrackCard(Map<String, String> track) {
    // Get controller from cache - it's guaranteed to exist because we preloaded
    final controller = _controllerCache[track['id']]!;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: WebViewWidget(
          controller: controller,
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Tüm Içeriklere Erişebilmek Için Sadece 10€/ay Abone Ol',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 3,
                shadowColor: Colors.white.withOpacity(0.3),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/register');
              },
              child: Text(
                'Hemen Kayıt Ol',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              child: Text(
                'Giriş Yap',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controllerCache.clear();
    super.dispose();
  }
}