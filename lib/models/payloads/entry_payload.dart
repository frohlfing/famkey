class EntryPayload {
  final String category;
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;
  final String favicon;

  EntryPayload({
    this.category = '',
    this.title = '',
    this.username = '',
    this.password = '',
    this.url = '',
    this.notes = '',
    this.favicon = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'title': title,
      'username': username,
      'password': password,
      'url': url,
      'notes': notes,
      'favicon': favicon,
    };
  }

  factory EntryPayload.fromJson(Map<String, dynamic> json) {
    return EntryPayload(
      category: json['category'] as String? ?? '',
      title: json['title'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      url: json['url'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      favicon: json['favicon'] as String? ?? '',
    );
  }
}
