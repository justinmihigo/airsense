enum DownloadStatus { pending, inProgress, success, failed }

class DownloadItem {
  final String id;
  final String stationName;
  final String title;
  final DownloadStatus status;
  final DateTime requestedAt;

  const DownloadItem({
    required this.id,
    required this.stationName,
    required this.title,
    required this.status,
    required this.requestedAt,
  });

  String get statusLabel {
    switch (status) {
      case DownloadStatus.pending:
        return 'Pending';
      case DownloadStatus.inProgress:
        return 'Status!';
      case DownloadStatus.success:
        return 'Successful!';
      case DownloadStatus.failed:
        return 'Failed';
    }
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] as String,
      stationName: json['stationName'] as String,
      title: json['title'] as String,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.pending,
      ),
      requestedAt: DateTime.parse(json['requestedAt'] as String),
    );
  }
}
