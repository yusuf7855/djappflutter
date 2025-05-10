import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _resetEmailController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  static const String _loginEndpoint = 'http://192.168.1.102:5000/api/login';
  static const String _forgotPasswordEndpoint = 'http://192.168.1.102:5000/api/forgot-password';

  @override
  void initState() {
    super.initState();
    _checkIfLoggedIn();
  }

  Future<void> _checkIfLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

   
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  void _navigateToHome() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainHomePage()));
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse(_loginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', responseData['token']);
        // Token'dan userId'yi çıkar ve kaydet
        final tokenData = _parseJwt(responseData['token']);
        await prefs.setString('userId', tokenData['userId']);
        await prefs.setString('userName', responseData['username'] ?? '');

        _navigateToHome();
      } else {
        throw responseData['message'] ?? 'Giriş başarısız';
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

// JWT token'dan bilgileri çözümle
  Map<String, dynamic> _parseJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('invalid token');
    }
    final payload = _decodeBase64(parts[1]);
    final payloadMap = json.decode(payload);
    if (payloadMap is! Map<String, dynamic>) {
      throw Exception('invalid payload');
    }
    return payloadMap;
  }

  String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string!');
    }
    return utf8.decode(base64Url.decode(output));
  }

  Future<void> _forgotPassword() async {
    if (_resetEmailController.text.isEmpty) {
      setState(() => _errorMessage = 'Lütfen e-posta girin');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(_forgotPasswordEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': _resetEmailController.text}),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'])),
        );
        Navigator.pop(context);
      } else {
        throw responseData['message'] ?? 'Şifre sıfırlama başarısız';
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    _resetEmailController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Şifre Sıfırlama', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            TextFormField(
              controller: _resetEmailController,
              decoration: InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.email)),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _forgotPassword,
              child: _isLoading ? CircularProgressIndicator(color: Colors.white) : Text('Gönder'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 40),
              FlutterLogo(size: 100),
              SizedBox(height: 40),
              Text(
                'Hoş Geldiniz',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              if (_errorMessage.isNotEmpty)
                Text(_errorMessage, style: TextStyle(color: Colors.red), textAlign: TextAlign.center),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.email)),
                      validator: (value) => value!.isEmpty ? 'E-posta girin' : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(labelText: 'Şifre', prefixIcon: Icon(Icons.lock)),
                      validator: (value) => value!.length < 6 ? 'En az 6 karakter' : null,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading ? CircularProgressIndicator(color: Colors.white) : Text('Giriş Yap'),
                    ),
                    TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: Text('Şifremi Unuttum'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterPage()));
                      },
                      child: Text('Hesabınız yok mu? Kayıt Ol'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}