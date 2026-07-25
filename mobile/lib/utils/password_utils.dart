class PasswordUtils {
  static const int minLength = 6;
  static const int maxLength = 128;

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static String? validatePassword(
    String? value, {
    String fieldLabel = 'Password',
  }) {
    if (value == null || value.isEmpty) {
      return 'Please enter your $fieldLabel';
    }
    if (value.length < minLength) {
      return '$fieldLabel must be at least $minLength characters';
    }
    if (value.length > maxLength) {
      return '$fieldLabel must be at most $maxLength characters';
    }
    return null;
  }

  static String? validateLoginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length > maxLength) {
      return 'Password is too long';
    }
    return null;
  }
}
