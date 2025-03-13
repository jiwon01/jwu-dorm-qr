import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../services/auth_service.dart';
import 'qr_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  final _authService = AuthService();

  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    _authService.dispose(); // 리소스 해제
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  // 저장된 세션 확인
  Future<void> _checkExistingSession() async {
    setState(() => _isLoading = true);

    try {
      final session = await _authService.loadSessionFromStorage();
      if (session != null) {
        // 저장된 세션이 있으면 QR 화면으로 이동
        _navigateToQRScreen(session);
      }
    } catch (e) {
      // 오류 발생 시 무시하고 로그인 화면 유지
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('중원대학교 계정 로그인')),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 10), // 로딩 인디케이터와 텍스트 사이의 간격
            Text('로그인 중입니다. 잠시만 기다려주세요.', style: TextStyle(fontSize: 16)),
          ],
        ),
      )
          : _buildLoginForm(),
    );
  }


  Widget _buildLoginForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: '아이디',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pwController,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('로그인', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    final userId = _idController.text.trim();
    final userPw = _pwController.text.trim();

    // 입력 유효성 검사
    if (userId.isEmpty || userPw.isEmpty) {
      setState(() {
        _errorMessage = '아이디와 비밀번호를 모두 입력해주세요.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final session = await _authService.login(userId, userPw);
      _navigateToQRScreen(session);
    } on AuthException catch (e) {
      // 구체적인 오류 메시지 표시
      setState(() {
        switch (e.code) {
          case 'INVALID_CREDENTIALS':
            _errorMessage = '아이디 또는 비밀번호가 올바르지 않습니다.';
            break;
          case 'NETWORK_ERROR':
            _errorMessage = '네트워크 연결을 확인해주세요.';
            break;
          case 'SERVER_ERROR':
            _errorMessage = '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
            break;
          default:
            _errorMessage = '로그인 중 오류가 발생했습니다: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = '알 수 없는 오류가 발생했습니다: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToQRScreen(SessionModel session) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => QRScreen(session: session)),
    );
  }
}
