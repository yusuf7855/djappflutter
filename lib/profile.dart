import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'playlist_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // State variables
  Map<String, dynamic>? userData;
  List<dynamic> playlists = [];
  bool isLoading = true;
  bool isFollowing = false;
  int followerCount = 0;
  int followingCount = 0;
  String? authToken;
  String? currentUserId;

  // WebView management
  int? currentlyExpandedIndex;
  final Map<String, WebViewController> activeWebViews = {};
  @override
  void initState() {
    super.initState();
    _loadToken().then((_) {
      if (mounted && authToken != null) {
        fetchCurrentUser();
      }
    });
  }

  @override
  void dispose() {
    activeWebViews.values.forEach((controller) {
      // Add any cleanup needed for WebView controllers
    });
    super.dispose();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      authToken = prefs.getString('auth_token');
      currentUserId = prefs.getString('user_id');
    });
  }

  Future<void> fetchCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.103:5000/api/me'),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          userData = data;
          currentUserId = data['_id'];
          followerCount = data['followers']?.length ?? 0;
          followingCount = data['following']?.length ?? 0;
          isLoading = false;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', currentUserId!);
        fetchPlaylists();
      } else {
        setState(() => isLoading = false);
        _showErrorSnackbar("Profile could not be loaded");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackbar("An error occurred: $e");
    }
  }

  Future<void> fetchPlaylists() async {
    if (currentUserId == null) return;

    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.103:5000/api/playlists/user/$currentUserId'),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            playlists = (data['playlists'] as List<dynamic>).map((playlist) {
              return {
                '_id': playlist['_id']?.toString(),
                'name': playlist['name']?.toString() ?? 'Untitled Playlist',
                'description': playlist['description']?.toString() ?? '',
                'musicCount': playlist['musicCount'] ?? 0,
                'musics': (playlist['musics'] as List<dynamic>?)?.map((music) {
                  return {
                    'title': music['title']?.toString(),
                    'artist': music['artist']?.toString(),
                    'spotifyId': music['spotifyId']?.toString(),
                  };
                }).toList() ?? [],
              };
            }).toList();
          });
        }
      }
    } catch (e) {
      _showErrorSnackbar("Error loading playlists: $e");
    }
  }

  void _handleExpansionChanged(int index, bool expanded) {
    if (expanded) {
      if (currentlyExpandedIndex != null && currentlyExpandedIndex != index) {
        // Önceki playlist'in tüm WebView'lerini temizle
        final keysToRemove = activeWebViews.keys
            .where((key) => key.startsWith('${currentlyExpandedIndex}-'))
            .toList();
        for (var key in keysToRemove) {
          activeWebViews.remove(key);
        }
      }
      setState(() {
        currentlyExpandedIndex = index;
      });
    } else if (currentlyExpandedIndex == index) {
      // Mevcut playlist'in tüm WebView'lerini temizle
      final keysToRemove = activeWebViews.keys
          .where((key) => key.startsWith('$index-'))
          .toList();
      for (var key in keysToRemove) {
        activeWebViews.remove(key);
      }
      setState(() {
        currentlyExpandedIndex = null;
      });
    }
  }
  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: userData!['profileImage'] != null &&
                    userData!['profileImage'] != ''
                    ? NetworkImage(userData!['profileImage'])
                    : const AssetImage('assets/default_profile.png') as ImageProvider,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${userData!['firstName']} ${userData!['lastName']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${userData!['username']}',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatColumn(followerCount, "Followers"),
                        _buildStatColumn(followingCount, "Following"),
                        _buildStatColumn(playlists.length, "Playlists"),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (currentUserId != userData!['_id']) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: toggleFollow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing ? Colors.grey : Colors.indigo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isFollowing ? "Unfollow" : "Follow",
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatColumn(int count, String label) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> toggleFollow() async {
    if (authToken == null || userData == null) return;

    try {
      final endpoint = isFollowing ? 'unfollow' : 'follow';
      final response = await http.post(
        Uri.parse('http://192.168.1.103:5000/api/$endpoint/${userData!['_id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          isFollowing = !isFollowing;
          followerCount = isFollowing ? followerCount + 1 : followerCount - 1;
        });
        _showSuccessSnackbar(isFollowing ? "Followed" : "Unfollowed");
      }
    } catch (e) {
      _showErrorSnackbar("An error occurred: $e");
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
          ),
        ),
      );
    }

    if (userData == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "User not found",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text("Sign In"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.indigo),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (currentUserId == userData!['_id'])
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.indigo),
              onPressed: () {
                // Navigate to edit profile
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            _buildProfileCard(),
            const SizedBox(height: 20),
            const Text(
              "Playlists",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 12),
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  "No playlists created yet",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ...playlists.asMap().entries.map((entry) => PlaylistCard(
              playlist: entry.value,
              index: entry.key,
              currentlyExpandedIndex: currentlyExpandedIndex,
              onExpansionChanged: _handleExpansionChanged,
              activeWebViews: activeWebViews,
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}