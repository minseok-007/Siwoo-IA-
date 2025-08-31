import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// 앱 전역 인증 상태를 관리하는 ChangeNotifier.
/// - FirebaseAuth의 authStateChanges 스트림을 구독해 로그인/로그아웃/프로필 변화를 반영합니다.
/// - Service 레이어(AuthService)와 UI 사이의 중간 계층으로, 비동기 호출과 에러 상태를 캡슐화합니다.
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    // 실시간 인증 상태 반영을 위해 초기화 시 스트림 구독을 설정합니다.
    _init();
  }

  /// Firebase 인증 스트림을 구독하고 사용자 문서를 로드합니다.
  void _init() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      if (user != null) {
        _loadUserData(user.uid);
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  /// Firestore에서 사용자 상세를 불러와 캐시합니다.
  Future<void> _loadUserData(String userId) async {
    try {
      _userModel = await _authService.getUserData(userId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// 이메일/비밀번호 회원가입 처리. 성공 시 사용자 문서 생성까지 수행합니다.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required UserType userType,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final userCredential = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
        userType: userType,
      );
      _user = userCredential.user;
      await _loadUserData(_user!.uid);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// 이메일/비밀번호 로그인 처리. 성공 시 사용자 문서를 로드합니다.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final userCredential = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;
      await _loadUserData(_user!.uid);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// 로그아웃 처리. 로컬 상태 초기화와 리스너 통지를 포함합니다.
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _user = null;
      _userModel = null;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// 비밀번호 재설정(샘플 구현). 실제 앱에서는 이메일 발송 로직을 사용합니다.
  Future<void> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      await Future.delayed(Duration(seconds: 1));
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  /// 사용자 프로필 업데이트 후 로컬 캐시를 최신화합니다.
  Future<void> updateUserProfile(UserModel updatedUser) async {
    _setLoading(true);
    _clearError();

    try {
      // Persist to Firestore and update local state
      final toSave = updatedUser.copyWith(updatedAt: DateTime.now());
      await _authService.updateUserData(toSave);
      _userModel = toSave;
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // 아래 세 개의 헬퍼는 상태 변경+notify를 일관되게 처리하기 위한 내부 유틸입니다.
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }
} 
