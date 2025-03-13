import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:html/parser.dart' show parse;

import '../models/session_model.dart';

/// 인증 관련 예외 클래스
class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, {this.code});

  @override
  String toString() => 'AuthException: $message${code != null ? ' (code: $code)' : ''}';
}

/// 중원대학교 기숙사 인증 서비스
class AuthService {
  static const String _storageKey = "dorm_session";

  // URL 상수들
  static const _urls = _DormUrls();

  // HTTP 클라이언트 (재사용)
  final http.Client _client;

  // 보안 저장소
  final FlutterSecureStorage _storage;

  // 로깅 인스턴스
  final Logger _logger;

  /// 기본 생성자
  AuthService({
    http.Client? client,
    FlutterSecureStorage? storage,
    Logger? logger,
  }) :
        _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage(),
        _logger = logger ?? ConsoleLogger();

  /// 리소스 해제
  void dispose() {
    _client.close();
  }

  /// ViewState 관련 값들을 동적으로 가져오는 메서드
  Future<Map<String, String>> getFormValues() async {
    try {
      final response = await _client.get(Uri.parse(_urls.loginUrl));
      if (response.statusCode == 200) {
        // HTML 파싱
        var document = parse(response.body);

        String viewState = document.querySelector('input[name="__VIEWSTATE"]')?.attributes['value'] ?? '';
        String viewStateGenerator = document.querySelector('input[name="__VIEWSTATEGENERATOR"]')?.attributes['value'] ?? '';
        String eventValidation = document.querySelector('input[name="__EVENTVALIDATION"]')?.attributes['value'] ?? '';

        _logger.info("ViewState 값들을 성공적으로 가져왔습니다.");
        return {
          "__VIEWSTATE": viewState,
          "__VIEWSTATEGENERATOR": viewStateGenerator,
          "__EVENTVALIDATION": eventValidation,
        };
      }

      _logger.error("ViewState 값 가져오기 실패: HTTP ${response.statusCode}");
      throw AuthException("서버 응답 오류", code: "SERVER_ERROR");
    } catch (e) {
      _logger.error("ViewState 값 가져오는 중 오류 발생: $e");
      if (e is AuthException) rethrow;
      throw AuthException("네트워크 오류", code: "NETWORK_ERROR");
    }
  }

  /// 로그인 시도
  /// 성공하면 SessionModel 반환, 실패하면 AuthException 발생
  Future<SessionModel> login(String userId, String userPw) async {
    try {
      // 폼 값 가져오기
      final formValues = await getFormValues();

      // 로그인 요청 실행
      final cookie = await _performLogin(userId, userPw, formValues);

      // 초기화 요청
      await _initializeSession(userId, cookie);

      // 세션 모델 생성 및 저장
      final session = SessionModel(
        userId: userId,
        userPassword: userPw,
        cookie: cookie,
      );

      await saveSessionToStorage(session);

      _logger.info("정상적으로 로그인되었습니다.");
      return session;
    } catch (e) {
      _logger.error("로그인 중 오류: $e");
      if (e is AuthException) rethrow;
      throw AuthException("로그인 처리 중 오류 발생", code: "LOGIN_ERROR");
    }
  }

  /// 로그인 요청 실행
  Future<String> _performLogin(
      String userId,
      String userPw,
      Map<String, String> formValues
      ) async {
    final postData = {
      "__VIEWSTATE": formValues["__VIEWSTATE"] ?? "",
      "__VIEWSTATEGENERATOR": formValues["__VIEWSTATEGENERATOR"] ?? "",
      "__EVENTVALIDATION": formValues["__EVENTVALIDATION"] ?? "",
      "TextBox1": userId,
      "TextBox2": userPw,
      "Button1": "Log+in",
    };

    final loginResp = await _client.post(
      Uri.parse(_urls.loginUrl),
      body: postData,
    );

    // 로그인 실패 확인
    if (loginResp.body.contains("Error logging in ...")) {
      _logger.warning("로그인 실패. 입력한 계정 정보를 재확인해주세요.");
      throw AuthException("아이디 또는 비밀번호가 올바르지 않습니다", code: "INVALID_CREDENTIALS");
    }

    // 쿠키 추출
    String? cookie = _extractCookie(loginResp);
    if (cookie == null) {
      _logger.error("로그인 쿠키를 찾는데 실패했습니다.");
      throw AuthException("인증 쿠키를 받을 수 없습니다", code: "NO_COOKIE");
    }

    return cookie;
  }

  /// 세션 초기화 요청
  Future<void> _initializeSession(String userId, String cookie) async {
    // 첫 번째 초기화 요청
    final initUrl = _urls.initUrl + userId;
    bool initOk = await _getWithCookie(initUrl, cookie);
    if (!initOk) {
      throw AuthException("세션 초기화 실패 (1)", code: "INIT_FAILED_1");
    }

    // 두 번째 초기화 요청
    initOk = await _getWithCookie(_urls.initHeaderUrl, cookie);
    if (!initOk) {
      throw AuthException("세션 초기화 실패 (2)", code: "INIT_FAILED_2");
    }
  }

  /// 저장된 아이디/비번을 가지고 재로그인 - 세션 새로고침
  Future<SessionModel> reLogin(SessionModel oldSession) async {
    return await login(oldSession.userId, oldSession.userPassword);
  }

  /// QR Token 가져오기
  Future<String> fetchQR(SessionModel session) async {
    try {
      // 초기화 URL 접근
      bool initOk = await _getWithCookie(_urls.initHeaderUrl, session.cookie);
      if (!initOk) {
        throw AuthException("QR 초기화 실패", code: "QR_INIT_FAILED");
      }

      // QR 페이지 접근
      final qrResp = await _getResponseWithCookie(_urls.qrUrl, session.cookie);
      if (qrResp == null || qrResp.statusCode != 200) {
        throw AuthException("QR 페이지 가져오기 실패", code: "QR_FETCH_FAILED");
      }

      // QR 토큰 추출
      final token = _extractQrToken(qrResp.body);
      if (token == null) {
        throw AuthException("QR 코드를 찾을 수 없습니다", code: "QR_NOT_FOUND");
      }

      _logger.info("QR 토큰을 가져왔습니다");
      return token;
    } catch (e) {
      _logger.error("QR 로딩 중 오류: $e");
      if (e is AuthException) rethrow;
      throw AuthException("QR 코드 처리 중 오류 발생", code: "QR_ERROR");
    }
  }

  /// QR 토큰 추출
  String? _extractQrToken(String html) {
    final regex = RegExp(r'text:\s*"(.*?)"');
    final match = regex.firstMatch(html);
    return match?.group(1);
  }

  /// 세션 정보(아이디, 비번, 쿠키) 보안 저장
  Future<void> saveSessionToStorage(SessionModel session) async {
    final data = json.encode(session.toJson());
    await _storage.write(key: _storageKey, value: data);
  }

  /// 세션 정보 가져오기
  Future<SessionModel?> loadSessionFromStorage() async {
    final data = await _storage.read(key: _storageKey);
    if (data == null) return null;

    try {
      final jsonData = json.decode(data);
      return SessionModel.fromJson(jsonData);
    } catch (e) {
      _logger.error("저장된 세션 정보 파싱 오류: $e");
      await clearSession(); // 오류 발생 시 세션 정보 삭제
      return null;
    }
  }

  /// 로그인 정보 변경시(로그아웃) 세션 정보 삭제
  Future<void> clearSession() async {
    await _storage.delete(key: _storageKey);
    _logger.info("세션 정보가 삭제되었습니다.");
  }

  // GET 요청을 보내고 statusCode == 200이면 true, 아니면 false
  Future<bool> _getWithCookie(String url, String cookie) async {
    final resp = await _getResponseWithCookie(url, cookie);
    if (resp == null) return false;
    return (resp.statusCode == 200);
  }

  // 쿠키를 포함한 GET 요청
  Future<http.Response?> _getResponseWithCookie(String url, String cookie) async {
    try {
      final resp = await _client.get(
        Uri.parse(url),
        headers: {"Cookie": cookie},
      );
      return resp;
    } catch (e) {
      _logger.error("HTTP 요청 오류: $e");
      return null;
    }
  }

  /// Set-Cookie에서 첫 세미콜론 전까지 추출
  String? _extractCookie(http.Response resp) {
    final rawSetCookie = resp.headers['set-cookie'];
    if (rawSetCookie == null) return null;

    final semicolonIndex = rawSetCookie.indexOf(';');
    if (semicolonIndex != -1) {
      return rawSetCookie.substring(0, semicolonIndex);
    }
    return rawSetCookie;
  }
}

/// URL 정보를 담는 클래스
class _DormUrls {
  const _DormUrls();

  final String qrUrl = "http://jw_lms.smartedu.center/mypage.aspx";
  final String loginUrl = "https://www.dtizen.net/alarm/login_student_new_app_ini.aspx";
  final String initUrl = "http://jw_lms.smartedu.center/alarm/ini.aspx?a_ID=";
  final String initHeaderUrl = "http://jw_lms.smartedu.center/go_header_alarm.aspx";
}

/// 로깅 인터페이스
abstract class Logger {
  void info(String message);
  void warning(String message);
  void error(String message);
}

/// 콘솔 로깅 구현
class ConsoleLogger implements Logger {
  @override
  void info(String message) => print("[INFO] $message");

  @override
  void warning(String message) => print("[WARNING] $message");

  @override
  void error(String message) => print("[ERROR] $message");
}
