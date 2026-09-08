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
    this.daybookCode = '',
    this.originalId,
    this.voucherId,
    this.createdBy = '',
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

  /// Which book the line came out of. The desk routes a deletion off this, so
  /// it is carried even though nothing displays it.
  final String daybookCode;

  /// The id of the record this line was rendered from - a havala row uses one,
  /// a voucher the other.
  final int? originalId;
  final int? voucherId;

  /// Who wrote the entry. Shown so a queried figure can be taken to the person
  /// who entered it rather than guessed at.
  final String createdBy;

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
        daybookCode: (json['daybook_code'] ?? '').toString().trim(),
        originalId: int.tryParse('${json['original_id']}'),
        voucherId: int.tryParse('${json['voucher_id']}'),
        createdBy: (json['created_by'] ?? '').toString().trim().toUpperCase(),
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

  /// What this line did to the balance. Positive means money owed to the party.
  ///
  /// Added, not subtracted: the server sends `dr_amount` already negative and
  /// runs its own closing balance as `cr + dr`. Subtracting it here flipped
  /// every debit green and made a line read as the opposite of the closing
  /// balance printed under it.
  double get movement => credit + debit;

  /// Whose trades this line drills into: the client whose book the share came
  /// from on a partnership leg, otherwise the party being viewed.
  int? drillIntoPartyId(int viewingPartyId) => ptrnSourceId ?? viewingPartyId;

  /// Which book a line has to be deleted from, and with which id.
  ///
  /// A statement line is a rendering of a record in one of four books, and the
  /// only way back to that record is the shape of the line - the voucher
  /// prefix, or the daybook code it came out of. These are the desk's own
  /// rules; a line that matches none of them was produced by settling a match
  /// and cannot be removed from here at all.
  ({String path, int id})? get deleteTarget {
    if (voucherNo.toUpperCase().startsWith('HAVALA') ||
        voucherType.toUpperCase() == 'RGML') {
      final id = originalId;
      return id == null ? null : (path: '/soda/havala/', id: id);
    }

    final id = voucherId;
    if (id == null) return null;

    if (daybookCode.startsWith('03515')) {
      return (path: '/soda/inflow-clearing-jv/', id: id);
    }
    if (const ['03501', '03511', '03525', '03535']
            .any(daybookCode.startsWith) ||
        daybookCode.contains('CLOSE JV')) {
      return (path: '/soda/clearing-jv/', id: id);
    }
    return (path: '/soda/opening-balances/', id: id);
  }

  /// True when this line can be taken back out of the book it came from.
  bool get canDelete => deleteTarget != null;
}

/// A party's statement as the server sends it: the lines, and the balance it
/// arrives at.
///
/// The closing figure is taken from the server rather than re-derived from the
/// rows, because a date filter narrows the rows without changing where the
/// party actually stands.
class PartyStatement {
  const PartyStatement({required this.rows, required this.balance});

  final List<LedgerRow> rows;
  final double balance;

  static const empty = PartyStatement(rows: [], balance: 0);
}
