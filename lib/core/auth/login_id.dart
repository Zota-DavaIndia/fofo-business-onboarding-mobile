/// What the user typed in the sign-in field, as the API expects it: an email
/// address, or a 10-digit Indian mobile number.
class LoginId {
  const LoginId._(this.field, this.value);

  /// `email` or `mobile`: the request field to send.
  final String field;
  final String value;

  /// Returns null when the text is neither a plausible email nor a mobile
  /// number. Mobile numbers may be typed with +91, a leading 0, spaces or
  /// dashes.
  static LoginId? parse(String input) {
    final text = input.trim();
    if (text.contains('@')) {
      final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
      return ok ? LoginId._('email', text.toLowerCase()) : null;
    }
    var digits = text.replaceAll(RegExp(r'[\s\-()]'), '');
    if (digits.startsWith('+91')) {
      digits = digits.substring(3);
    } else if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ? LoginId._('mobile', digits) : null;
  }
}
