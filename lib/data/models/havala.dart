import '../../core/util/app_time.dart';
import '../../core/util/money.dart';

/// A transfer between two parties.
///
/// `p_member` pays and `h_member` receives. The names are the system's own;
/// the app never shows them raw, because "payer" and "receiver" is what the
/// operator actually needs to be sure of.
class Havala {
  const Havala({
    required this.id,
    required this.voucherNo,
    required this.date,
    required this.fromId,
    required this.fromCode,
    required this.fromName,
    required this.toId,
    required this.toCode,
    required this.toName,
    required this.amount,
    this.description = '',
    this.createdBy = '',
    this.isChecked = false,
  });

  final int id;
  final String voucherNo;
  final DateTime? date;

  /// Who pays.
  final int fromId;
  final String fromCode;
  final String fromName;

  /// Who receives.
  final int toId;
  final String toCode;
  final String toName;

  final double amount;
  final String description;
  final String createdBy;

  /// Ticked while reconciling - the same mark the desk and View Party show.
  final bool isChecked;

  factory Havala.fromJson(Map<String, dynamic> json) => Havala(
        id: int.tryParse('${json['id']}') ?? 0,
        voucherNo: (json['voucher_no'] ?? '').toString().trim(),
        date: AppTime.toLocal(json['voucher_date']),
        fromId: int.tryParse('${json['p_member']}') ?? 0,
        fromCode: (json['p_member_code_display'] ?? '').toString().trim().toUpperCase(),
        fromName: (json['p_member_name_display'] ?? '').toString().trim(),
        toId: int.tryParse('${json['h_member']}') ?? 0,
        toCode: (json['h_member_code_display'] ?? '').toString().trim().toUpperCase(),
        toName: (json['h_member_name_display'] ?? '').toString().trim(),
        amount: Money.toDouble(json['amount']),
        description: (json['description'] ?? '').toString().trim(),
        createdBy: (json['created_by_name'] ?? '').toString().trim(),
        isChecked: json['is_checked'] == true,
      );
}
