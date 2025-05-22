import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'playlist_card.dart';
import './url_constants.dart';

// todo : bio , tri image,  links, event pickers, design,

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
  File? _imageFile;
  bool _isUpdatingImage = false;
  final ImagePicker _picker = ImagePicker();

  // WebView management
  int? currentlyExpandedIndex;
  final Map<String, WebViewController> activeWebViews = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadToken();
    if (mounted && authToken != null && authToken!.isNotEmpty) {
      await fetchCurrentUser();
    } else {
     // _navigateToLogin();
    }
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        authToken = prefs.getString('auth_token');
        currentUserId = prefs.getString('user_id');
      });
    }
  }

  // void _navigateToLogin() {
   // if (mounted) {
     // Navigator.pushReplacementNamed(context, '/login');
    // }
  //}

  Future<void> fetchCurrentUser() async {
    if (!mounted || authToken == null) return;

    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/me'),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            userData = data;
            currentUserId = data['_id'];
            followerCount = data['followers']?.length ?? 0;
            followingCount = data['following']?.length ?? 0;
            isLoading = false;
            isFollowing = data['followers']?.contains(currentUserId) ?? false;
          });
        }
        await fetchPlaylists();
      } else {
        _handleFetchError("Profile could not be loaded");
      }
    } catch (e) {
      _handleFetchError("An error occurred: $e");
    }
  }

  void _handleFetchError(String message) {
    if (mounted) {
      setState(() => isLoading = false);
      _showErrorSnackbar(message);
    }
  }

  Future<void> fetchPlaylists() async {
    if (currentUserId == null || !mounted) return;

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/user/$currentUserId'),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted && data['success'] == true) {
          setState(() {
            playlists = _parsePlaylistData(data['playlists']);
          });
        }
      }
    } catch (e) {
      _showErrorSnackbar("Error loading playlists: $e");
    }
  }

  List<dynamic> _parsePlaylistData(List<dynamic>? playlists) {
    return (playlists ?? []).map((playlist) {
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
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null || !mounted) return; // mounted kontrolü

      debugPrint("Seçilen dosya: ${pickedFile.path}");
      debugPrint("Boyut: ${await File(pickedFile.path).length()} bytes");

      final file = File(pickedFile.path);
      setState(() => _imageFile = file);

      await _uploadProfileImage();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar("Hata: ${e.toString()}");
    }
  }

  bool _isValidImageExtension(String path) {
    final extension = path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
  }

  Future<void> _uploadProfileImage() async {
    if (_imageFile == null || authToken == null || !mounted) return;

    setState(() => _isUpdatingImage = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${UrlConstants.apiBaseUrl}/api/upload-profile-image'),
      )..headers['Authorization'] = 'Bearer $authToken'
        ..files.add(await http.MultipartFile.fromPath('profileImage', _imageFile!.path));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (!mounted) return; // mounted kontrolü

      if (response.statusCode == 200) {
        await fetchCurrentUser();
        _showSuccessSnackbar("Resim yüklendi");
      } else {
        _showErrorSnackbar(jsonDecode(responseData)['message'] ?? 'Yükleme başarısız');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar("Sunucu hatası: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isUpdatingImage = false);
      }
    }
  }
  void _handleExpansionChanged(int index, bool expanded) {
    if (!mounted) return;

    if (expanded) {
      _cleanupPreviousWebViews(index);
      setState(() => currentlyExpandedIndex = index);
    } else if (currentlyExpandedIndex == index) {
      _cleanupWebViewsForIndex(index);
      setState(() => currentlyExpandedIndex = null);
    }
  }

  void _cleanupPreviousWebViews(int currentIndex) {
    if (currentlyExpandedIndex != null && currentlyExpandedIndex != currentIndex) {
      final keysToRemove = activeWebViews.keys
          .where((key) => key.startsWith('${currentlyExpandedIndex}-'))
          .toList();
      for (var key in keysToRemove) {
        activeWebViews.remove(key);
      }
    }
  }

  void _cleanupWebViewsForIndex(int index) {
    final keysToRemove = activeWebViews.keys
        .where((key) => key.startsWith('$index-'))
        .toList();
    for (var key in keysToRemove) {
      activeWebViews.remove(key);
    }
  }

  ImageProvider _getProfileImage() {
    if (_imageFile != null) {
      return FileImage(_imageFile!);
    } else if (userData?['profileImage'] != null &&
        userData!['profileImage'].isNotEmpty &&
        userData!['profileImage'] != 'image.jpg') {
      return NetworkImage('${UrlConstants.apiBaseUrl}/uploads/${userData!['profileImage']}');
    }
    return const AssetImage('assets/default_profile.png');
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
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: _getProfileImage(),
              ),
              if (currentUserId == userData?['_id'])
                _buildCameraButton(),
            ],
          ),
          const SizedBox(height: 16),
          _buildUserInfoSection(),
          if (currentUserId != userData?['_id'])
            _buildFollowButton(),
        ],
      ),
    );
  }

  Widget _buildCameraButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.indigo,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: IconButton(
        icon: _isUpdatingImage
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 2,
          ),
        )
            : const Icon(Icons.camera_alt, size: 20),
        onPressed: _isUpdatingImage ? null : _pickImage,
        color: Colors.white,
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${userData?['firstName']} ${userData?['lastName']}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '@${userData?['username']}',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 16),
              _buildStatsRow(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatColumn(followerCount, "Followers"),
        _buildStatColumn(followingCount, "Following"),
        _buildStatColumn(playlists.length, "Playlist"),
      ],
    );
  }

  Widget _buildFollowButton() {
    return Column(
        children: [
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
    )
    ],
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
    if (authToken == null || userData == null || !mounted) return;

    try {
      final endpoint = isFollowing ? 'unfollow' : 'follow';
      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/$endpoint/${userData!['_id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          isFollowing = !isFollowing;
          followerCount += isFollowing ? 1 : -1;
        });
        _showSuccessSnackbar(isFollowing ? "Followed" : "Unfollowed");
      }
    } catch (e) {
      _showErrorSnackbar("An error occurred: $e");
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return; // Bu satırı ekleyin
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingScreen();
    }

    if (userData == null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            _buildProfileCard(),
            const SizedBox(height: 20),
            _buildPlaylistsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
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

  Widget _buildPlaylistsSection() {
    return Column(
      children: [
        const Text(
          "Playlists",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        if (playlists.isEmpty)
          _buildEmptyPlaylistMessage(),
        ...playlists.asMap().entries.map((entry) => PlaylistCard(
          playlist: entry.value,
          index: entry.key,
          currentlyExpandedIndex: currentlyExpandedIndex,
          onExpansionChanged: _handleExpansionChanged,
          activeWebViews: activeWebViews,
          cachedWebViews: {},
        )),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildEmptyPlaylistMessage() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Text(
        "No playlists created yet",
        style: TextStyle(color: Colors.grey),
      ),
    );
  }
}