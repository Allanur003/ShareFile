class SharedFile {
  final String code;
  final String filename;
  final String filePath;
  final int size;
  final String? password;
  final int? maxDownloads;
  final DateTime? expiryTime;
  final DateTime createdAt;
  int downloads;

  SharedFile({
    required this.code,
    required this.filename,
    required this.filePath,
    required this.size,
    this.password,
    this.maxDownloads,
    this.expiryTime,
    DateTime? createdAt,
    this.downloads = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExpired {
    if (expiryTime == null) return false;
    return DateTime.now().isAfter(expiryTime!);
  }

  bool get hasReachedLimit {
    if (maxDownloads == null) return false;
    return downloads >= maxDownloads!;
  }

  bool get isPasswordProtected => password != null && password!.isNotEmpty;
}
