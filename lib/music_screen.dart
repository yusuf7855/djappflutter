import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_page.dart';

class MusicScreen extends StatefulWidget {
  @override
  _MusicScreenState createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> with SingleTickerProviderStateMixin {
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> musicList = [];
  List<Map<String, dynamic>> userPlaylists = [];
  bool isLoading = true;
  bool _allTracksLoaded = false;
  String? userId;
  TextEditingController _newPlaylistController = TextEditingController();
  bool _isDisposed = false;
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  // WebView cache and loading states
  final Map<String, WebViewController> _webViewCache = {};
  final Map<String, bool> _webViewLoadingStates = {};

  final List<String> categories = [
    'All',
    'Afra House',
    'Indie Dance',
    'Organic House',
    'Down tempo',
    'Melodic House'
  ];

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _colorAnimation = ColorTween(
      begin: Colors.white.withOpacity(0.8),
      end: Colors.white,
    ).animate(_animationController);

    _initializeUser();
    _fetchMusic();
  }

  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final fetchedUserId = prefs.getString('userId');

    if (mounted && !_isDisposed) {
      setState(() {
        userId = fetchedUserId;
      });

      if (userId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDisposed) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LoginPage()),
            );
          }
        });
      } else {
        _fetchUserPlaylists();
      }
    }
  }

  Future<void> _fetchMusic() async {
    try {
      final response = await http.get(Uri.parse('http://192.168.1.103:5000/api/music'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted && !_isDisposed) {
          setState(() {
            musicList = data.map((item) => {
              'id': item['spotifyId'],
              'title': item['title'],
              'category': item['category'],
              'likes': item['likes'] ?? 0,
              '_id': item['_id'],
              'userLikes': item['userLikes'] ?? [],
              'beatportUrl': item['beatportUrl'] ?? '',
            }).toList();
            isLoading = false;
          });
          _preloadWebViews();
        }
      } else {
        throw Exception('Failed to load music');
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Müzik yüklenirken hata: $e')),
        );
      }
    }
  }

  void _preloadWebViews() {
    for (final track in musicList) {
      _webViewLoadingStates[track['id']] = false;

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) {
              if (mounted && !_isDisposed) {
                setState(() {
                  _webViewLoadingStates[track['id']] = true;
                  _checkAllTracksLoaded();
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(
          'https://open.spotify.com/embed/track/${track['id']}?utm_source=generator&theme=0',
        ));

      _webViewCache[track['id']] = controller;
    }
  }
  void _checkAllTracksLoaded() {
    if (_webViewLoadingStates.values.every((isLoaded) => isLoaded)) {
      if (mounted && !_isDisposed) {
        setState(() {
          _allTracksLoaded = true;
        });
        // Only stop the animation, don't dispose here
        _animationController.stop();
      }
    }
  }


  Future<void> _fetchUserPlaylists() async {
    if (userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('http://192.168.1.103:5000/api/playlists/user/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> data = responseData['playlists'];
          if (mounted) {
            setState(() {
              userPlaylists = data.map((item) => {
                '_id': item['_id'],
                'name': item['name'],
                'description': item['description'] ?? '',
                'musicCount': item['musicCount'] ?? 0,
              }).toList();
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Çalma listeleri yüklenirken hata: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleLike(String musicId) async {
    if (userId == null) return;

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.103:5000/api/music/$musicId/like'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        _fetchMusic();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Beğeni işlemi sırasında hata: $e')),
        );
      }
    }
  }

  Future<void> _addToExistingPlaylist(String musicId, String playlistId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse('http://192.168.1.103:5000/api/music/$musicId/add-to-playlist'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'playlistId': playlistId,
          'userId': userId,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Çalma listesine başarıyla eklendi'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchUserPlaylists();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Çalma listesine eklenirken hata'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createNewPlaylist(String musicId) async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çalma listesi oluşturmak için giriş yapın')),
      );
      return;
    }

    if (_newPlaylistController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çalma listesi adı girin')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.103:5000/api/playlists'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'name': _newPlaylistController.text,
          'musicId': musicId,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Çalma listesi oluşturuldu')),
        );
        _newPlaylistController.clear();
        await Future.wait([
          _fetchMusic(),
          _fetchUserPlaylists(),
        ]);
        Navigator.of(context).pop();
      } else {
        final error = json.decode(response.body)['message'] ?? 'Çalma listesi oluşturulamadı';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: ${e.toString()}')),
      );
    }
  }

  void _showAddToPlaylistDialog(String musicId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Çalma Listesine Ekle",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    if (userPlaylists.isNotEmpty) ...[
                      Text(
                        "Çalma Listeleriniz",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        constraints: BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: userPlaylists.length,
                          itemBuilder: (context, index) {
                            final playlist = userPlaylists[index];
                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                              leading: Icon(Icons.playlist_play, color: Colors.white),
                              title: Text(
                                playlist['name'],
                                style: TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                "${playlist['musicCount']} şarkı",
                                style: TextStyle(color: Colors.white70),
                              ),
                              trailing: Icon(Icons.add, color: Colors.green),
                              onTap: () {
                                _addToExistingPlaylist(musicId, playlist['_id']);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      Divider(color: Colors.grey[700]),
                      SizedBox(height: 8),
                    ],
                    Text(
                      "Yeni Çalma Listesi Oluştur",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _newPlaylistController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[800],
                        hintText: 'Çalma listesi adı girin',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'İptal',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () => _createNewPlaylist(musicId),
                          child: Text('Oluştur ve Ekle'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _isLikedByUser(Map<String, dynamic> track) {
    return track['userLikes']?.contains(userId) ?? false;
  }

  Future<void> _launchBeatportUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      } else {
        throw 'Bağlantı açılamadı: $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Kategoriler
          Container(
            height: 60,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => SizedBox(width: 8),
              itemBuilder: (context, index) {
                return ChoiceChip(
                  label: Text(
                    categories[index],
                    style: TextStyle(
                      color: _selectedCategory == categories[index]
                          ? Colors.black
                          : Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  selected: _selectedCategory == categories[index],
                  selectedColor: Colors.white,
                  backgroundColor: Colors.grey[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = categories[index];
                    });
                  },
                );
              },
            ),
          ),

          // İçerik
          Expanded(
            child: isLoading || !_allTracksLoaded
                ? _buildLoadingAnimation()
                : _buildMusicContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingAnimation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Text(
                  'B',
                  style: TextStyle(
                    color: _colorAnimation.value,
                    fontSize: 96,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    shadows: [
                      Shadow(
                        color: Colors.white.withOpacity(0.7),
                        blurRadius: 15,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMusicContent() {
    final filteredMusic = _getFilteredMusic();

    return ListView.separated(
      padding: EdgeInsets.all(16),
      physics: BouncingScrollPhysics(),
      itemCount: filteredMusic.length,
      separatorBuilder: (_, __) => SizedBox(height: 16),
      itemBuilder: (context, index) {
        final track = filteredMusic[index];
        return _buildMusicCard(track);
      },
    );
  }

  Widget _buildMusicCard(Map<String, dynamic> track) {
    final controller = _webViewCache[track['id']];

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Spotify embed
          Container(
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              child: WebViewWidget(controller: controller!),
            ),
          ),

          // Action buttons
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Like button
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isLikedByUser(track) ? Icons.favorite : Icons.favorite_border,
                        color: _isLikedByUser(track) ? Colors.red : Colors.white,
                        size: 24,
                      ),
                      onPressed: () => _toggleLike(track['_id']),
                    ),
                    Text(
                      '${track['likes']}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),

                // Add to playlist button
                IconButton(
                  icon: Icon(Icons.playlist_add, color: Colors.white, size: 24),
                  onPressed: () => _showAddToPlaylistDialog(track['_id']),
                ),

                // Beatport button
                if (track['beatportUrl']?.isNotEmpty == true)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    icon: Image.asset(
                      'assets/beatport_logo.png',
                      width: 24,
                      height: 24,
                    ),
                    label: Text('Buy on Beatport'),
                    onPressed: () => _launchBeatportUrl(track['beatportUrl']),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredMusic() {
    if (_selectedCategory == 'All') {
      return musicList;
    }
    return musicList.where((music) => music['category'] == _selectedCategory).toList();
  }

  @override
  void dispose() {
    _isDisposed = true; // Set the flag when disposing
    _animationController.stop(); // Stop the animation first
    _animationController.dispose(); // Then dispose it
    _newPlaylistController.dispose();
    _webViewCache.clear();
    super.dispose();
  }
}