class UserModel {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? profilePhoto;
  final String status;
  final List<String> roles;
  final JobSeekerProfileModel? profile;
  final List<EmployerModel>? employers;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.profilePhoto,
    required this.status,
    required this.roles,
    this.profile,
    this.employers,
  });

  bool get isJobSeeker =>
      roles.any(
        (r) => [
          'job_seeker',
          'jobseeker',
          'seeker',
          'candidate',
          'user',
        ].contains(r.toLowerCase()),
      ) ||
      (!isAdmin && !isEmployer);

  bool get isEmployer =>
      roles.any(
        (r) => [
          'employer',
          'company',
          'recruiter',
          'organization',
          'employee',
        ].contains(r.toLowerCase()),
      ) ||
      (employers != null && employers!.isNotEmpty);

  bool get isAdmin => roles.any(
    (r) => [
      'administrator',
      'admin',
      'super_admin',
      'superadmin',
      'manager',
      'moderator',
      'staff',
    ].contains(r.toLowerCase()),
  );

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<String> roleList = [];
    if (json['roles'] != null && json['roles'] is List) {
      for (var r in json['roles']) {
        if (r is Map && r['name'] != null) {
          final name = r['name'].toString().toLowerCase().trim();
          if (name.isNotEmpty && !roleList.contains(name)) {
            roleList.add(name);
          }
        } else if (r is String) {
          final name = r.toLowerCase().trim();
          if (name.isNotEmpty && !roleList.contains(name)) {
            roleList.add(name);
          }
        }
      }
    }

    if (json['role'] != null) {
      if (json['role'] is String) {
        final roleStr = json['role'].toString().toLowerCase().trim();
        if (roleStr.isNotEmpty && !roleList.contains(roleStr)) {
          roleList.add(roleStr);
        }
      } else if (json['role'] is Map && json['role']['name'] != null) {
        final roleStr = json['role']['name'].toString().toLowerCase().trim();
        if (roleStr.isNotEmpty && !roleList.contains(roleStr)) {
          roleList.add(roleStr);
        }
      }
    }

    if (json['user_type'] != null && json['user_type'] is String) {
      final roleStr = json['user_type'].toString().toLowerCase().trim();
      if (roleStr.isNotEmpty && !roleList.contains(roleStr)) {
        roleList.add(roleStr);
      }
    }

    if (roleList.isEmpty) {
      if (json['employers'] != null &&
          json['employers'] is List &&
          (json['employers'] as List).isNotEmpty) {
        roleList.add('employer');
      } else if (json['job_seeker_profile'] != null ||
          json['profile'] != null) {
        roleList.add('job_seeker');
      } else {
        roleList.add('job_seeker');
      }
    }

    return UserModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      profilePhoto: json['profile_photo'] ?? json['avatar'],
      status: json['status'] ?? 'active',
      roles: roleList,
      profile: (json['job_seeker_profile'] ?? json['profile']) is Map
          ? JobSeekerProfileModel.fromJson(
              Map<String, dynamic>.from(
                json['job_seeker_profile'] ?? json['profile'],
              ),
            )
          : null,
      employers: json['employers'] != null && json['employers'] is List
          ? (json['employers'] as List)
                .map((e) => EmployerModel.fromJson(e))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'status': status,
    'roles': roles,
  };
}

class JobSeekerProfileModel {
  final int id;
  final int userId;
  final String? dateOfBirth;
  final String? gender;
  final String? educationLevel;
  final String? fieldOfStudy;
  final String? preferredJobTitle;
  final int? preferredCategoryId;
  final double experienceYears;
  final String? location;
  final String? biography;
  final List<dynamic>? skills;

  JobSeekerProfileModel({
    required this.id,
    required this.userId,
    this.dateOfBirth,
    this.gender,
    this.educationLevel,
    this.fieldOfStudy,
    this.preferredJobTitle,
    this.preferredCategoryId,
    required this.experienceYears,
    this.location,
    this.biography,
    this.skills,
  });

  factory JobSeekerProfileModel.fromJson(Map<String, dynamic> json) {
    return JobSeekerProfileModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      dateOfBirth: json['date_of_birth'],
      gender: json['gender'],
      educationLevel: json['education_level'],
      fieldOfStudy: json['field_of_study'],
      preferredJobTitle: json['preferred_job_title'],
      preferredCategoryId: json['preferred_category_id'] != null
          ? int.tryParse(json['preferred_category_id'].toString())
          : null,
      experienceYears: json['experience_years'] != null
          ? double.tryParse(json['experience_years'].toString()) ?? 0.0
          : 0.0,
      location: json['location'],
      biography: json['biography'],
      skills: json['skills'],
    );
  }
}

class EmployerModel {
  final int id;
  final String organizationName;
  final String? organizationType;
  final String? registrationNumber;
  final String? email;
  final String? phone;
  final String? website;
  final String? address;
  final String verificationStatus;

  EmployerModel({
    required this.id,
    required this.organizationName,
    this.organizationType,
    this.registrationNumber,
    this.email,
    this.phone,
    this.website,
    this.address,
    required this.verificationStatus,
  });

  factory EmployerModel.fromJson(Map<String, dynamic> json) {
    return EmployerModel(
      id: json['id'] ?? 0,
      organizationName: json['organization_name'] ?? '',
      organizationType: json['organization_type'],
      registrationNumber: json['registration_number'],
      email: json['email'],
      phone: json['phone'],
      website: json['website'],
      address: json['address'],
      verificationStatus: json['verification_status'] ?? 'pending',
    );
  }
}
