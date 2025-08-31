import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// 공통 폼 검증 유틸리티.
/// - 입력값 유효성 검사를 분리해 위젯 코드의 가독성과 재사용성을 높입니다.
/// - context가 제공되면 현지화된 메시지를 반환합니다.
class Validators {
  static String? validateEmail(String? value, [BuildContext? context]) {
    if (value == null || value.isEmpty) {
      return context != null ? AppLocalizations.of(context).t('err_email_required') : 'Email is required';
    }
    
    // 기본 이메일 패턴. 과도한 제약을 피하고 UX를 해치지 않도록 최소 검증만 합니다.
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return context != null ? AppLocalizations.of(context).t('err_email_invalid') : 'Please enter a valid email address';
    }
    
    return null;
  }

  static String? validatePassword(String? value, [BuildContext? context]) {
    if (value == null || value.isEmpty) {
      return context != null ? AppLocalizations.of(context).t('err_password_required') : 'Password is required';
    }
    
    if (value.length < 6) {
      return context != null ? AppLocalizations.of(context).t('err_password_min') : 'Password must be at least 6 characters long';
    }
    
    // 대문자/소문자/숫자 조합 권장: 약한 비밀번호를 예방합니다.
    bool hasUppercase = value.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = value.contains(RegExp(r'[a-z]'));
    bool hasNumbers = value.contains(RegExp(r'[0-9]'));
    
    if (!hasUppercase || !hasLowercase || !hasNumbers) {
      return context != null ? AppLocalizations.of(context).t('err_password_combo') : 'Password must contain uppercase, lowercase, and numbers';
    }
    
    return null;
  }

  static String? validateConfirmPassword(String? value, String password, [BuildContext? context]) {
    if (value == null || value.isEmpty) {
      return context != null ? AppLocalizations.of(context).t('err_confirm_required') : 'Please confirm your password';
    }
    
    if (value != password) {
      return context != null ? AppLocalizations.of(context).t('err_password_mismatch') : 'Passwords do not match';
    }
    
    return null;
  }

  static String? validateFullName(String? value, [BuildContext? context]) {
    if (value == null || value.isEmpty) {
      return context != null ? AppLocalizations.of(context).t('err_fullname_required') : 'Full name is required';
    }
    
    if (value.length < 2) {
      return context != null ? AppLocalizations.of(context).t('err_fullname_min') : 'Full name must be at least 2 characters long';
    }
    
    // Check if name contains only letters and spaces
    final nameRegex = RegExp(r'^[a-zA-Z\s]+$');
    if (!nameRegex.hasMatch(value)) {
      return context != null ? AppLocalizations.of(context).t('err_fullname_chars') : 'Full name can only contain letters and spaces';
    }
    
    return null;
  }

  static String? validatePhoneNumber(String? value, [BuildContext? context]) {
    if (value == null || value.isEmpty) {
      return context != null ? AppLocalizations.of(context).t('err_phone_required') : 'Phone number is required';
    }
    
    // Remove all non-digit characters for validation
    String digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.length < 10 || digitsOnly.length > 15) {
      return context != null ? AppLocalizations.of(context).t('err_phone_invalid') : 'Please enter a valid phone number';
    }
    
    return null;
  }

  static String? validateRequired(String? value, String fieldName, [BuildContext? context]) {
    if (value == null || value.trim().isEmpty) {
      return context != null ? '${AppLocalizations.of(context).t(fieldName)} ${AppLocalizations.of(context).t('err_required')}' : '$fieldName is required';
    }
    return null;
  }

  static String? validateMinLength(String? value, int minLength, String fieldName, [BuildContext? context]) {
    if (value == null || value.length < minLength) {
      return context != null ? '${AppLocalizations.of(context).t(fieldName)} ${AppLocalizations.of(context).t('err_min_len')} $minLength' : '$fieldName must be at least $minLength characters long';
    }
    return null;
  }

  static String? validateMaxLength(String? value, int maxLength, String fieldName, [BuildContext? context]) {
    if (value != null && value.length > maxLength) {
      return context != null ? '${AppLocalizations.of(context).t(fieldName)} ${AppLocalizations.of(context).t('err_max_len')} $maxLength' : '$fieldName must be no more than $maxLength characters long';
    }
    return null;
  }
}
