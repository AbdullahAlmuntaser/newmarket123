class BomEntry {
  final int id;
  final int finishedProductId;
  final int componentProductId;
  final double quantity;
  final double alertLimit;
  final String cartonUnit;
  final DateTime createdAt;
  final double piecesPerCarton;
  final String syncStatus;
  final double taxRate;
  final String unit;
  final DateTime updatedAt;
  final double wholesalePrice;

  const BomEntry({
    required this.id,
    required this.finishedProductId,
    required this.componentProductId,
    required this.quantity,
    required this.alertLimit,
    required this.cartonUnit,
    required this.createdAt,
    required this.piecesPerCarton,
    required this.syncStatus,
    required this.taxRate,
    required this.unit,
    required this.updatedAt,
    required this.wholesalePrice,
  });

  factory BomEntry.fromJson(Map<String, dynamic> json) => BomEntry(
    id: json['id'] as int,
    finishedProductId: json['finishedProductId'] as int,
    componentProductId: json['componentProductId'] as int,
    quantity: (json['quantity'] as num).toDouble(),
    alertLimit: (json['alertLimit'] as num).toDouble(),
    cartonUnit: json['cartonUnit'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    piecesPerCarton: (json['piecesPerCarton'] as num).toDouble(),
    syncStatus: json['syncStatus'] as String,
    taxRate: (json['taxRate'] as num).toDouble(),
    unit: json['unit'] as String,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    wholesalePrice: (json['wholesalePrice'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'finishedProductId': finishedProductId,
    'componentProductId': componentProductId,
    'quantity': quantity,
    'alertLimit': alertLimit,
    'cartonUnit': cartonUnit,
    'createdAt': createdAt.toIso8601String(),
    'piecesPerCarton': piecesPerCarton,
    'syncStatus': syncStatus,
    'taxRate': taxRate,
    'unit': unit,
    'updatedAt': updatedAt.toIso8601String(),
    'wholesalePrice': wholesalePrice,
  };
}
