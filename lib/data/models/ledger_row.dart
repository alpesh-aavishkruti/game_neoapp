import '../../core/util/app_time.dart';
import '../../core/util/money.dart';

/// One line of a party's statement.
class LedgerRow {
  const LedgerRow({
    required this.id,
    required this.date,
    required this.description,
    required this.credit,
    required this.debit,
    required this.closingBalance,
    this.voucherNo = '',
    this.voucherType = '',
    this.matchId,
    this.ptrnSlot,
    this.ptrnSourceId,
    this.ptrnSourceCode,
    this.isEdited = false,
  });

  final int id;
  final DateTime? date;
  final String description;
  final double credit;
  final double debit;
  final double closingBalance;
  final String voucherNo;
  final String voucherType;

  /// Set on a settlement row, so it can drill into that match's trades.
  final int? matchId;

  /// Set when this line is a partnership leg rather than the party's own
  /// result - the share it earned as someone else's partner.
  final int? ptrnSlot;
  final int? ptrnSourceId;
  final String? ptrnSourceCode;

  final bool isEdited;

  factory LedgerRow.fromJson(Map<String, dynamic> json) => LedgerRow(
        id: int.tryParse('${json['id']}') ?? 0,
        // The server sends this already rendered in the caller's timezone.
        date: AppTime.toLocal(json['created_date']) ?? _parseDayFirst(json['vch_date']),
        description: (json['description'] ?? '').toString().trim(),
        credit: Money.toDouble(json['cr_amount']),
        debit: Money.toDouble(json['dr_amount']),
        closingBalance: Money.toDouble(json['closing_balance'] ?? json['closing_bal']),
        voucherNo: (json['vch_no'] ?? '').toString().trim(),
        voucherType: (json['vch_type'] ?? '').toString().trim(),
        matchId: int.tryParse('${json['match_id']}'),
        ptrnSlot: int.tryParse('${json['ptrn_slot']}'),
        ptrnSourceId: int.tryParse('${json['ptrn_source_id']}'),
        ptrnSourceCode: (json['ptrn_source_code'] ?? '').toString().trim().isEmpty
            ? null
            : json['ptrn_source_code'].toString().trim().toUpperCase(),
        isEdited: json['is_edited'] == true,
      );

  /// `dd-MM-yyyy`, which is how the backend writes the voucher date.
  static DateTime? _parseDayFirst(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  /// A share earned on someone else's book rather than this party's own play.
  bool get isPartnershipLeg => ptrnSlot != null && ptrnSourceId != null;

  /// Positive means money owed to the party.
  double get movement => credit - debit;

  /// Whose trades this line drills into: the client whose book the share came
  /// from on a partnership leg, otherwise the party being viewed.
  int? drillIntoPartyId(int viewingPartyId) => ptrnSourceId ?? viewingPartyId;
}
