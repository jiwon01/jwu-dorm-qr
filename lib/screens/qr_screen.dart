import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../models/session_model.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class QRScreen extends StatefulWidget {
  final SessionModel session;
  const QRScreen({Key? key, required this.session}) : super(key: key);

  @override
  State<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  static const int qrRefreshIntervalSeconds = 25;

  // 서비스 인스턴스
  late final AuthService _authService;

  // 상태 변수
  late SessionModel _session;
  String? _qrData;
  String? _errorMessage;
  bool _isRefreshing = false;
  bool _isRefreshingSession = false;

  // 타이머 관련
  Timer? _autoRefreshTimer;
  int _secondsUntilRefresh = qrRefreshIntervalSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _authService = AuthService();
    _loadQR();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _countdownTimer?.cancel();
    _authService.dispose();
    super.dispose();
  }

  // 타이머 시작 메서드
  void _startRefreshTimer() {
    // 작업 중이면 타이머 시작하지 않음
    if (_isRefreshingSession) return;

    // 기존 타이머 취소
    _autoRefreshTimer?.cancel();
    _countdownTimer?.cancel();

    // QR 자동 갱신 타이머
    _autoRefreshTimer = Timer.periodic(
        const Duration(seconds: qrRefreshIntervalSeconds),
            (_) => _loadQR()
    );

    // 카운트다운 타이머
    _secondsUntilRefresh = qrRefreshIntervalSeconds;
    _countdownTimer = Timer.periodic(
        const Duration(seconds: 1),
            (_) {
          if (_secondsUntilRefresh > 0) {
            setState(() => _secondsUntilRefresh--);
          }
        }
    );
  }

  // 타이머 중지 메서드
  void _stopRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _countdownTimer?.cancel();
    _autoRefreshTimer = null;
    _countdownTimer = null;
  }

  // QR 코드 로딩
  Future<void> _loadQR() async {
    // 중복 요청 방지
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      final qrToken = await _authService.fetchQR(_session);

      if (mounted) {
        setState(() {
          _qrData = qrToken;
          _isRefreshing = false;
        });

        // 타이머 재시작
        _startRefreshTimer();
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          // 오류 코드별 맞춤 메시지
          switch (e.code) {
            case 'QR_NOT_FOUND':
              _errorMessage = 'QR 코드를 찾을 수 없습니다. 세션 새로고침을 시도해보세요.';
              break;
            case 'QR_FETCH_FAILED':
              _errorMessage = 'QR 코드를 가져오지 못했습니다. 네트워크 연결을 확인하세요.';
              break;
            default:
              _errorMessage = '오류가 발생했습니다: ${e.message}';
          }
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '예상치 못한 오류: $e';
          _isRefreshing = false;
        });
      }
    }
  }

  // 세션 새로고침
  Future<void> _refreshSession() async {
    if (_isRefreshingSession) return;

    setState(() {
      _isRefreshingSession = true;
      _errorMessage = null;
    });

    // 세션 새로고침 중에는 타이머 중지
    _stopRefreshTimer();

    try {
      final newSession = await _authService.reLogin(_session);

      setState(() {
        _session = newSession;
        _isRefreshingSession = false;
      });

      // 타이머 재시작
      _startRefreshTimer();

      // QR 코드 새로 로딩
      _loadQR();
    } on AuthException catch (e) {
      // 인증 실패 시 로그인 화면으로 이동
      if (e.code == 'INVALID_CREDENTIALS') {
        await _authService.clearSession();
        _navigateToLogin();
      } else {
        setState(() {
          _errorMessage = '세션 새로고침 실패: ${e.message}';
          _isRefreshingSession = false;
        });
        // 타이머 재시작
        _startRefreshTimer();
      }
    } catch (e) {
      setState(() {
        _errorMessage = '새로고침 중 오류 발생: $e';
        _isRefreshingSession = false;
      });
      // 타이머 재시작
      _startRefreshTimer();
    }
  }

  // 로그아웃 처리
  Future<void> _logout() async {
    await _authService.clearSession();
    _navigateToLogin();
  }

  // 로그인 화면으로 이동
  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  // 안내 다이얼로그
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사용 안내', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Text(
            "🔹QR코드는 25초마다 자동으로 새로고침됩니다.\n\n"
                "🔹위 QR코드를 인식해도 반응이 없으면\n\"세션 새로고침\" 버튼을 누르세요. 앱이 저장된 데이터로 다시 로그인을 시도합니다.\n\n"
                "🔹이 앱은 DMS와 사용자를 중계하는 앱으로 사용자 데이터를 개발자를 포함한 제3자에게 공유하지 않습니다.\n\n"
                "🔹저장된 아이디와 비밀번호 등의 데이터는 암호화된 영역(KeyChain 또는 EncryptedSharedPreferences)에 저장됩니다.",
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스피드게이트 QR 코드'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
            tooltip: '사용 안내',
          ),
        ],
      ),
      body: SafeArea(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildErrorWidget(),
            _buildQRCodeWidget(),
            const SizedBox(height: 30),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // 오류 메시지 위젯
  Widget _buildErrorWidget() {
    if (_errorMessage == null) return const SizedBox.shrink();

    return Container(
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
        textAlign: TextAlign.center,
      ),
    );
  }

  // QR 코드 위젯
  Widget _buildQRCodeWidget() {
    return Column(
      children: [
        // QR 코드 컨테이너
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // QR 코드 또는 로딩 표시
              if (_qrData != null && !_isRefreshing)
                QrImageView(
                  data: _qrData!,
                  version: QrVersions.auto,
                  size: 220.0,
                  backgroundColor: Colors.white,
                )
              else
                const SizedBox(
                  width: 220,
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),

              // 새로고침 오버레이
              if (_isRefreshing && _qrData != null)
                Container(
                  width: 220.0,
                  height: 220.0,
                  color: Colors.black.withOpacity(0.2),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 새로고침 카운트다운
        const SizedBox(height: 12),
        Text(
          '새로고침까지 $_secondsUntilRefresh초',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 버튼 섹션 위젯
  Widget _buildActionButtons() {
    // 어떤 작업이라도 진행 중이면 모든 버튼 비활성화
    final bool isAnyActionInProgress = _isRefreshing || _isRefreshingSession;

    return Column(
      children: [
        // QR 코드 새로고침 버튼
        OutlinedButton.icon(
          onPressed: isAnyActionInProgress ? null : _loadQR,
          icon: const Icon(Icons.refresh),
          label: Text(_isRefreshing ? '새로고침 중...' : 'QR코드 새로고침'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(220, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 세션 새로고침 버튼
        ElevatedButton.icon(
          onPressed: isAnyActionInProgress ? null : _refreshSession,
          icon: _isRefreshingSession
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : const Icon(Icons.sync),
          label: Text(_isRefreshingSession ? '새로고침 중...' : '세션 새로고침'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(220, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 로그아웃 버튼
        TextButton.icon(
          onPressed: isAnyActionInProgress ? null : _logout,
          icon: const Icon(Icons.logout),
          label: const Text('로그아웃'),
          style: TextButton.styleFrom(
            minimumSize: const Size(220, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
