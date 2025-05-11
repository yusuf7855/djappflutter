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

class _MusicScreenState extends State<MusicScreen> {
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> musicList = [];
  List<Map<String, dynamic>> userPlaylists = [];
  bool isLoading = true;
  String? userId;
  String? userName;
  TextEditingController _newPlaylistController = TextEditingController();

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
    _initializeUser();
    _fetchMusic();
  }

  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final fetchedUserId = prefs.getString('userId');
    final fetchedUserName = prefs.getString('userName');

    if (mounted) {
      setState(() {
        userId = fetchedUserId;
        userName = fetchedUserName;
      });

      if (userId == null) {
        print('User not logged in, redirecting to login...');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        });
      } else {
        _fetchUserPlaylists();
      }
    }
  }

  Future<void> _fetchMusic() async {
    try {
      final response = await http.get(Uri.parse('http://192.168.1.102:5000/api/music'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
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
        }
      } else {
        throw Exception('Failed to load music');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading music: $e')),
        );
      }
    }
  }

  Future<void> _fetchUserPlaylists() async {
    if (userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('http://192.168.1.102:5000/api/playlists/user/$userId'),
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
            content: Text('Error loading playlists: ${e.toString()}'),
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
        Uri.parse('http://192.168.1.102:5000/api/music/$musicId/like'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        _fetchMusic();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling like: $e')),
        );
      }
    }
  }

  Future<void> _addToExistingPlaylist(String musicId, String playlistId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse('http://192.168.1.102:5000/api/music/$musicId/add-to-playlist'),
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
            content: Text(responseData['message'] ?? 'Added to playlist successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchUserPlaylists();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Failed to add to playlist'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createNewPlaylist(String musicId) async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to create playlists')),
      );
      return;
    }

    if (_newPlaylistController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a playlist name')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.102:5000/api/playlists'),
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
          SnackBar(content: Text('Playlist created successfully')),
        );
        _newPlaylistController.clear();
        await Future.wait([
          _fetchMusic(),
          _fetchUserPlaylists(),
        ]);
        Navigator.of(context).pop();
      } else {
        final error = json.decode(response.body)['message'] ?? 'Failed to create playlist';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
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
                          "Add to Playlist",
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
                        "Your Playlists",
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
                                "${playlist['musicCount']} songs",
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
                      "Create New Playlist",
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
                        hintText: 'Enter playlist name',
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
                            'Cancel',
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
                          child: Text('Create & Add'),
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
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Categories
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

          // Music List
          isLoading
              ? Expanded(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          )
              : Expanded(
            child: ListView.separated(
              padding: EdgeInsets.all(16),
              physics: BouncingScrollPhysics(),
              itemCount: _getFilteredMusic().length,
              separatorBuilder: (_, __) => SizedBox(height: 16),
              itemBuilder: (context, index) {
                final track = _getFilteredMusic()[index];
                return _buildMusicCard(track);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicCard(Map<String, dynamic> track) {
    final embedUrl =
        'https://open.spotify.com/embed/track/${track['id']}?utm_source=generator&theme=0';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36')
      ..loadRequest(Uri.parse(embedUrl));

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
              child: WebViewWidget(controller: controller),
            ),
          ),

          // Action buttons row
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
                      foregroundColor: Colors.white, backgroundColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    icon: Image.asset(
                      'assets/beatport_logo.png', // Make sure to add this asset
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
    _newPlaylistController.dispose();
    super.dispose();
  }
}