import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class FreePage extends StatefulWidget {
  @override
  _FreePageState createState() => _FreePageState();
}

class _FreePageState extends State<FreePage> {
  final List<Map<String, String>> tracks = [
    {'id': "4QHKR48C18rwlpSYW6rH7p"},
    {'id': "3pPe4F2kFRp9ipARwxFmQr"},
    {'id': "2MFs3zQcS0MuIjuyyG85fV"},
    {'id': "0RMmME0OhJcrWtnb2kZMHL"},
    {'id': "70sMnVjOXAbZCH5USpGuOG"},
  ];

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
            child: ListView(
              physics: BouncingScrollPhysics(),
              children: [
                SizedBox(height: 20),
                ...tracks.map((track) {
                  final embedUrl =
                      'https://open.spotify.com/embed/track/${track['id']}?utm_source=generator';

                  final controller = WebViewController()
                    ..setBackgroundColor(Colors.transparent)
                    ..setJavaScriptMode(JavaScriptMode.unrestricted)
                    ..setUserAgent(
                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36')
                    ..loadRequest(Uri.parse(embedUrl));

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
                      child: WebViewWidget(controller: controller),
                    ),
                  );
                }).toList(),
                SizedBox(height: 30),
              ],
            ),
          ),
          // Bottom section with buttons and text
          Container(
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
                // Kayıt Ol Butonu
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
          ),
        ],
      ),
    );
  }
}