class JobTitleModel {
  final int id;
  final int categoryId;
  final String title;
  final String slug;
  final String? categoryName;

  JobTitleModel({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.slug,
    this.categoryName,
  });

  factory JobTitleModel.fromJson(Map<String, dynamic> json) {
    return JobTitleModel(
      id: json['id'] ?? 0,
      categoryId: json['category_id'] ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      categoryName: json['category'] != null && json['category'] is Map
          ? json['category']['name']
          : json['category_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'title': title,
      'slug': slug,
      'category_name': categoryName,
    };
  }
}
