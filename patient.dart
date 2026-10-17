class Patient {
  final int? id;
  final String fullName;
  final String? phone;
  final String? nationalId;
  final String? birthJalali;
  final String? notes;
  final String createdAtJalali;

  const Patient({
    this.id,
    required this.fullName,
    this.phone,
    this.nationalId,
    this.birthJalali,
    this.notes,
    required this.createdAtJalali,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) "id": id,
        "full_name": fullName,
        "phone": phone,
        "national_id": nationalId,
        "birth_jalali": birthJalali,
        "notes": notes,
        "created_at_jalali": createdAtJalali,
      };

  factory Patient.fromMap(Map<String, dynamic> m) => Patient(
        id: m["id"] as int?,
        fullName: (m["full_name"] ?? "") as String,
        phone: m["phone"] as String?,
        nationalId: m["national_id"] as String?,
        birthJalali: m["birth_jalali"] as String?,
        notes: m["notes"] as String?,
        createdAtJalali: (m["created_at_jalali"] ?? "") as String,
      );
}
