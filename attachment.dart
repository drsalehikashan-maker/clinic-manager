class Attachment {
  final int? id;
  final int patientId;
  final String fileName;
  final String localPath;
  final String createdAtJalali;

  const Attachment({
    this.id,
    required this.patientId,
    required this.fileName,
    required this.localPath,
    required this.createdAtJalali,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) "id": id,
        "patient_id": patientId,
        "file_name": fileName,
        "local_path": localPath,
        "created_at_jalali": createdAtJalali,
      };

  factory Attachment.fromMap(Map<String, dynamic> m) => Attachment(
        id: m["id"] as int?,
        patientId: m["patient_id"] as int,
        fileName: (m["file_name"] ?? "") as String,
        localPath: (m["local_path"] ?? "") as String,
        createdAtJalali: (m["created_at_jalali"] ?? "") as String,
      );
}
