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

  Map<String, dynamic> toJson() => {
    'code': code,
    'filename': filename,
    'filePath': filePath,
    'size': size,
    'password': password,
    'maxDownloads': maxDownloads,
    'expiryTime': expiryTime?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'downloads': downloads,
  };

  factory SharedFile.fromJson(Map<String, dynamic> json) => SharedFile(
    code: json['code'],
    filename: json['filename'],
    filePath: json['filePath'],
    size: json['size'],
    password: json['password'],
    maxDownloads: json['maxDownloads'],
    expiryTime: json['expiryTime'] != null 
        ? DateTime.parse(json['expiryTime']) 
        : null,
    createdAt: DateTime.parse(json['createdAt']),
    downloads: json['downloads'] ?? 0,
  );
}