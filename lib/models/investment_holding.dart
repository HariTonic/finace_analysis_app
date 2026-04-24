import 'package:hive/hive.dart';

class InvestmentHolding {
  InvestmentHolding({
    required this.id,
    required this.type,
    required this.name,
    required this.quantity,
    required this.buyUnitPrice,
    required this.currentUnitPrice,
    required this.unitLabel,
    required this.purchaseDate,
    required this.notes,
    this.symbol = '',
    this.exchange = '',
  });

  String id;
  String type;
  String name;
  double quantity;
  double buyUnitPrice;
  double currentUnitPrice;
  String unitLabel;
  DateTime purchaseDate;
  String notes;
  String symbol;
  String exchange;

  double get investedAmount => quantity * buyUnitPrice;
  double get currentValue => quantity * currentUnitPrice;
  double get profitLoss => currentValue - investedAmount;
  double get profitLossPercent => investedAmount == 0 ? 0 : (profitLoss / investedAmount) * 100;
}

class InvestmentHoldingAdapter extends TypeAdapter<InvestmentHolding> {
  @override
  final int typeId = 1;

  @override
  InvestmentHolding read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var index = 0; index < fieldCount; index++) {
      fields[reader.readByte()] = reader.read();
    }

    return InvestmentHolding(
      id: fields[0] as String,
      type: fields[1] as String,
      name: fields[2] as String,
      quantity: (fields[3] as num).toDouble(),
      buyUnitPrice: (fields[4] as num).toDouble(),
      currentUnitPrice: (fields[5] as num).toDouble(),
      unitLabel: fields[6] as String,
      purchaseDate: fields[7] as DateTime,
      notes: fields[8] as String,
      symbol: (fields[9] as String?) ?? '',
      exchange: (fields[10] as String?) ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, InvestmentHolding obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.buyUnitPrice)
      ..writeByte(5)
      ..write(obj.currentUnitPrice)
      ..writeByte(6)
      ..write(obj.unitLabel)
      ..writeByte(7)
      ..write(obj.purchaseDate)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.symbol)
      ..writeByte(10)
      ..write(obj.exchange);
  }
}
