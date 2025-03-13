import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwu_fast_qr/screens/login_screen.dart';
import 'package:jwu_fast_qr/screens/qr_screen.dart';
import 'package:jwu_fast_qr/services/auth_service.dart';

void main() async {
  // Flutter 엔진 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();

  // 시스템 UI 설정 (상태 표시줄 색상 등)
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 앱 실행
  runApp(const DormQRApp());
}

class DormQRApp extends StatelessWidget {
  const DormQRApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '중원대 기숙사 QR',
      debugShowCheckedModeBanner: false, // 디버그 배너 제거
      theme: _buildAppTheme(),
      home: const SplashScreen(),
    );
  }

  // 앱 테마 정의
  ThemeData _buildAppTheme() {
    return ThemeData(
      // 기본 색상 테마
      primarySwatch: Colors.blue,
      primaryColor: const Color(0xFF1976D2),
      colorScheme: ColorScheme.fromSwatch().copyWith(
        secondary: const Color(0xFF03A9F4),
        surface: Colors.white,
      ),

      // 앱바 테마
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),

      // 버튼 테마
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // 입력 필드 테마
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}

// 스플래시 스크린 (초기 로딩 화면)
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  // 인증 서비스 인스턴스
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();

    // 페이드인 애니메이션 설정
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    // 저장된 세션 확인 및 라우팅
    _checkStoredSession();
  }

  @override
  void dispose() {
    _controller.dispose();
    _authService.dispose();
    super.dispose();
  }

  // 저장된 세션 확인
  Future<void> _checkStoredSession() async {
    try {
      // 최소 1.5초의 스플래시 화면 표시 (더 좋은 UX를 위해)
      await Future.delayed(const Duration(milliseconds: 1500));

      final storedSession = await _authService.loadSessionFromStorage();

      if (!mounted) return;

      // 세션 존재 여부에 따라 적절한 화면으로 이동
      if (storedSession != null) {
        _navigateToScreen(QRScreen(session: storedSession));
      } else {
        _navigateToScreen(const LoginScreen());
      }
    } catch (e) {
      if (!mounted) return;
      // 오류 발생 시 로그인 화면으로 이동
      _navigateToScreen(const LoginScreen());
    }
  }

  // 화면 전환 메서드
  void _navigateToScreen(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 앱 로고 또는 아이콘
              Icon(
                Icons.qr_code_scanner,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),

              // 앱 이름
              Text(
                '중원대학교 기숙사 QR',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),

              const SizedBox(height: 40),

              // 로딩 인디케이터
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
