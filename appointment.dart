class Appointment {
  final int? id;
  final int patientId;
  final String dateJalali;
  final String? time;
  final String? reason;
  final bool done;

  const Appointment({
    this.id,
    required this.patientId,
    required this.dateJalali,
    this.time,
    this.reason,
    this.done = false,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) "id": id,
        "patient_id": patientId,
        "date_jalali": dateJalali,
        "time": time,
        "reason": reason,
        "done": done ? 1 : 0,
      };

  factory Appointment.fromMap(Map<String, dynamic> m) => Appointment(
        id: m["id"] as int?,
        patientId: m["patient_id"] as int,
        dateJalali: (m["date_jalali"] ?? "") as String,
        time: m["time"] as String?,
        reason: m["reason"] as String?,
        done: (m["done"] ?? 0) == 1,
      );
}
