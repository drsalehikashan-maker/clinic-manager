/// نوع رکورد مالی: درآمد یا هزینه.
enum FinancialType { income, expense }

class FinancialRecord {
  final int? id;
  final FinancialType type;
  final int amountTomans; // مبالغ همیشه به تومان و int
  final String dateJalali;
  final String? description;
  final int? patientId;

  const FinancialRecord({
    this.id,
    required this.type,
    required this.amountTomans,
    required this.dateJalali,
    this.description,
    this.patientId,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) "id": id,
        "type": type == FinancialType.income ? "income" : "expense",
        "amount_tomans": amountTomans,
        "date_jalali": dateJalali,
        "description": description,
        "patient_id": patientId,
      };

  factory FinancialRecord.fromMap(Map<String, dynamic> m) => FinancialRecord(
        id: m["id"] as int?,
        type: m["type"] == "income"
            ? FinancialType.income
            : FinancialType.expense,
        amountTomans: (m["amount_tomans"] ?? 0) as int,
        dateJalali: (m["date_jalali"] ?? "") as String,
        description: m["description"] as String?,
        patientId: m["patient_id"] as int?,
      );
}
