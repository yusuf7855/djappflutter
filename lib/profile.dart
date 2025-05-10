import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isFollowing = false;
  int followerCount = 0;
  int followingCount = 0;
  String? authToken;

  @override
  void initState() {
    super.initState();
    _loadToken().then((_) => fetchUser());
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      authToken = prefs.getString('auth_token');
    });
  }

  Future<void> fetchUser() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.102:5000/api/user/${widget.userId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          userData = data;
          followerCount = data['followers']?.length ?? 0;
          followingCount = data['following']?.length ?? 0;
          // Kullanıcının takip edilip edilmediğini kontrol et
          isFollowing = data['followers']?.contains(widget.userId) ?? false;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        _showErrorSnackbar("Profil yüklenemedi");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackbar("Bir hata oluştu: $e");
    }
  }

  Future<void> toggleFollow() async {
    if (authToken == null) {
      _showErrorSnackbar("Giriş yapmanız gerekiyor");
      return;
    }

    try {
      final endpoint = isFollowing ? 'unfollow' : 'follow';
      final response = await http.post(
        Uri.parse('http://192.168.1.102:5000/api/$endpoint/${widget.userId}'),
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
        _showSuccessSnackbar(isFollowing ? "Takip edildi" : "Takipten çıkıldı");
      } else {
        _showErrorSnackbar("İşlem başarısız: ${response.body}");
      }
    } catch (e) {
      _showErrorSnackbar("Bir hata oluştu: $e");
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
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
          ),
        ),
      );
    }

    if (userData == null) {
      return Scaffold(
        body: Center(
          child: Text(
            "Kullanıcı bulunamadı",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.indigo),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            // Profil Üst Kısmı
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: userData!['profileImage'] != null &&
                            userData!['profileImage'] != ''
                            ? NetworkImage(userData!['profileImage'])
                            : AssetImage('assets/default_profile.png') as ImageProvider,
                      ),
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.indigo,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(Icons.edit, size: 18, color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text(
                    '${userData!['firstName']} ${userData!['lastName']}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '@${userData!['username']}',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn(followerCount, "Takipçi"),
                      _buildStatColumn(followingCount, "Takip"),
                      _buildStatColumn(0, "Paylaşım"),
                    ],
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing ? Colors.grey : Colors.indigo,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: Text(
                        isFollowing ? "Takipten Çık" : "Takip Et",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),

            // Detaylar Kısmı
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildDetailTile(Icons.email, "Email", userData!['email']),
                  Divider(height: 30),
                  _buildDetailTile(Icons.phone, "Telefon", userData!['phone']),
                  Divider(height: 30),
                  _buildDetailTile(Icons.calendar_today, "Katılma Tarihi", "10 Mayıs 2023"),
                ],
              ),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(int count, String label) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.indigo.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.indigo),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.grey,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}