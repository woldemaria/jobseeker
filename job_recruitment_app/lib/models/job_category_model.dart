import 'package:flutter/material.dart';
import 'job_title_model.dart';

class JobCategoryModel {
  final int id;
  final String name;
  final String slug;
  final String? iconName;
  final String? description;
  final int displayOrder;
  final int titlesCount;
  final int publishedJobsCount;
  final List<JobTitleModel> titles;

  JobCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.iconName,
    this.description,
    this.displayOrder = 0,
    this.titlesCount = 0,
    this.publishedJobsCount = 0,
    this.titles = const [],
  });

  factory JobCategoryModel.fromJson(Map<String, dynamic> json) {
    List<JobTitleModel> titlesList = [];
    if (json['titles'] != null && json['titles'] is List) {
      titlesList = (json['titles'] as List)
          .map((t) => JobTitleModel.fromJson(t))
          .toList();
    }

    return JobCategoryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      iconName: json['icon'],
      description: json['description'],
      displayOrder: json['display_order'] ?? 0,
      titlesCount: json['titles_count'] ?? titlesList.length,
      publishedJobsCount: json['published_jobs_count'] ?? 0,
      titles: titlesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'icon': iconName,
      'description': description,
      'display_order': displayOrder,
      'titles_count': titlesCount,
      'published_jobs_count': publishedJobsCount,
    };
  }

  IconData get icon {
    switch (iconName) {
      case 'agriculture': return Icons.agriculture;
      case 'home': return Icons.home;
      case 'engineering': return Icons.engineering;
      case 'chair': return Icons.chair;
      case 'school': return Icons.school;
      case 'security': return Icons.security;
      case 'account_balance': return Icons.account_balance;
      case 'business_center': return Icons.business_center;
      case 'shopping_bag': return Icons.shopping_bag;
      case 'campaign': return Icons.campaign;
      case 'local_hospital': return Icons.local_hospital;
      case 'local_shipping': return Icons.local_shipping;
      case 'hotel': return Icons.hotel;
      case 'precision_manufacturing': return Icons.precision_manufacturing;
      case 'computer': return Icons.computer;
      case 'phone_in_talk': return Icons.phone_in_talk;
      case 'mic': return Icons.mic;
      case 'gavel': return Icons.gavel;
      case 'volunteer_activism': return Icons.volunteer_activism;
      case 'spa': return Icons.spa;
      case 'science': return Icons.science;
      case 'bolt': return Icons.bolt;
      case 'work': return Icons.work;
      case 'sports_soccer': return Icons.sports_soccer;
      case 'water_drop': return Icons.water_drop;
      case 'brush': return Icons.brush;
      case 'flight': return Icons.flight;
      case 'child_care': return Icons.child_care;
      case 'receipt_long': return Icons.receipt_long;
      case 'lightbulb': return Icons.lightbulb;
      default: return Icons.work_outline;
    }
  }
}
