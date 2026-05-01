enum TxType { expense, income }

class TxRecord {
  final String id;
  final TxType type;
  final double amount;
  final String categoryId;
  final DateTime date;
  final String? account;
  final String? store;
  final String? comment;

  const TxRecord({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.account,
    this.store,
    this.comment,
  });

  TxRecord copyWith({
    String? id,
    TxType? type,
    double? amount,
    String? categoryId,
    DateTime? date,
    String? account,
    String? store,
    String? comment,
  }) {
    return TxRecord(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      account: account ?? this.account,
      store: store ?? this.store,
      comment: comment ?? this.comment,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'categoryId': categoryId,
        'date': date.toIso8601String(),
        'account': account,
        'store': store,
        'comment': comment,
      };

  factory TxRecord.fromJson(Map<String, dynamic> json) {
    return TxRecord(
      id: json['id'] as String,
      type: TxType.values.firstWhere((t) => t.name == json['type']),
      amount: (json['amount'] as num).toDouble(),
      categoryId: json['categoryId'] as String,
      date: DateTime.parse(json['date'] as String),
      account: json['account'] as String?,
      store: json['store'] as String?,
      comment: json['comment'] as String?,
    );
  }
}
