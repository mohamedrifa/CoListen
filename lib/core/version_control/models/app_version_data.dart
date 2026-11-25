class AppVersionData {
  final String version;
  final bool isMandatoryUpdate;
  final String url;
  final String title;
  final String releaseNotes;

  const AppVersionData({
    required this.version,
    this.isMandatoryUpdate = false,
    required this.url,
    this.title = 'New Update Available',
    this.releaseNotes = '',
  });

  factory AppVersionData.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const AppVersionData(
        version: '1.0.0',
        url: '',
      );
    }

    return AppVersionData(
      version: map['version']?.toString() ?? '1.0.0',
      isMandatoryUpdate: map['isMandatoryUpdate'] as bool? ?? false,
      url: map['url']?.toString() ?? '',
      title: map['title']?.toString() ?? 'New Update Available',
      releaseNotes: map['releaseNotes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'isMandatoryUpdate': isMandatoryUpdate,
      'url': url,
      'title': title,
      'releaseNotes': releaseNotes,
    };
  }
}
