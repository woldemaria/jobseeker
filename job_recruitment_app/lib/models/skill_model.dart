class SkillModel {
  final int id;
  final String name;
  final String? category;
  final String? description;
  final String? proficiencyLevel;
  final double yearsExperience;
  final String? importance; // required, preferred

  SkillModel({
    required this.id,
    required this.name,
    this.category,
    this.description,
    this.proficiencyLevel,
    this.yearsExperience = 0.0,
    this.importance,
  });

  factory SkillModel.fromJson(Map<String, dynamic> json) {
    String? prof;
    double yrs = 0.0;
    String? imp;

    if (json['pivot'] != null) {
      prof = json['pivot']['proficiency_level'];
      yrs = json['pivot']['years_experience'] != null
          ? double.tryParse(json['pivot']['years_experience'].toString()) ?? 0.0
          : 0.0;
      imp = json['pivot']['importance'];
    }

    return SkillModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      category: json['category'],
      description: json['description'],
      proficiencyLevel: prof ?? json['proficiency_level'],
      yearsExperience: yrs,
      importance: imp ?? json['importance'],
    );
  }
}
