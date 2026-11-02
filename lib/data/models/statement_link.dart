/// A party's shared statement link, as the desk manages it.
///
/// The link carries a random token rather than the party code. The party sets
/// a password the first time it is opened; the desk can only switch the link
/// off or reset it, never see the password.
class StatementLink {
  const StatementLink({
    required this.token,
    required this.isActive,
    required this.passwordSet,
  });

  final String token;
  final bool isActive;
  final bool passwordSet;

  factory StatementLink.fromJson(Map<String, dynamic> json) => StatementLink(
        token: (json['token'] ?? '').toString(),
        isActive: json['is_active'] != false,
        passwordSet: json['password_set'] == true,
      );
}
