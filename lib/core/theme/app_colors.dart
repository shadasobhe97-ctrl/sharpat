import 'package:flutter/material.dart';

/// LUMÉ Store Visual Identity & Color Palette
/// 
/// Reflects luxury, elegance, and warm Arabic aesthetics for scarves and shawls.
class AppColors {
  AppColors._();

  // Primary Brand Identity Colors
  static const Color warmIvory = Color(0xFFF8F3ED);       // خلفيات وقواعد هادئة
  static const Color dustyPink = Color(0xFFDDBFC1);       // لمسات ناعمة وأنثوية
  static const Color deepBurgundy = Color(0xFF702F40);    // اللون الأساسي والهوية الفاخرة
  static const Color champagneBeige = Color(0xFFC7AE91);  // لمسات ذهبية بيج راقية
  static const Color oliveGreen = Color(0xFF777F69);      // ألوان تفاصيل هادئة
  static const Color darkBrown = Color(0xFF39312F);       // نصوص داكنة وعناصر تأكيد

  // Functional & Semantic Colors
  static const Color background = warmIvory;
  static const Color surface = Colors.white;
  static const Color textPrimary = darkBrown;
  static const Color textSecondary = Color(0xFF6B5E5B);
  static const Color border = Color(0xFFE5DDD5);

  // Reservation Status Colors
  static const Color statusPending = Color(0xFFD9822B);    // قيد المراجعة (برتقالي دافئ)
  static const Color statusConfirmed = Color(0xFF3B7A57);  // مؤكد (أخضر هادئ)
  static const Color statusRejected = Color(0xFF9E2A2B);   // مرفوض (أحمر عنابي)
  static const Color statusExpired = Color(0xFF7F8C8D);    // منتهي الصلاحية (رمادي)
  static const Color statusCancelled = Color(0xFF5D6D7E);  // ملغي من العميل
}
