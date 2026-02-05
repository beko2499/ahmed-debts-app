import 'package:flutter/services.dart';

/// فورماتر لإضافة الفواصل للأرقام الكبيرة (مثال: 10000 → 10,000)
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // إذا كان النص فارغ
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // إزالة كل الفواصل القديمة
    String newText = newValue.text.replaceAll(',', '');

    // التحقق من أن النص رقمي فقط
    if (!RegExp(r'^\d*$').hasMatch(newText)) {
      return oldValue;
    }

    // إضافة الفواصل
    final formattedText = _formatWithCommas(newText);

    // حساب موقع المؤشر الجديد
    int cursorPosition = formattedText.length;
    
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }

  String _formatWithCommas(String value) {
    if (value.isEmpty) return value;
    
    // تنسيق الرقم بالفواصل
    final number = int.tryParse(value);
    if (number == null) return value;
    
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

/// استخراج الرقم من نص يحتوي فواصل
double parseFormattedNumber(String text) {
  if (text.isEmpty) return 0;
  final cleanText = text.replaceAll(',', '');
  return double.tryParse(cleanText) ?? 0;
}
