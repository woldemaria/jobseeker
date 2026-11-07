import '../models/job_model.dart';
import '../models/job_category_model.dart';
import '../models/job_title_model.dart';
import '../data/ethiopian_job_titles_data.dart';
import '../services/api_service.dart';
import '../core/constants/api_constants.dart';

class JobRepository {
  final ApiService _apiService;

  JobRepository(this._apiService);

  Future<List<JobModel>> getJobs({
    String? keyword,
    String? location,
    String? employmentType,
    int? minSalary,
    int? skillId,
    String? category,
    int? categoryId,
  }) async {
    final Map<String, String> params = {};
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    if (location != null && location.isNotEmpty) params['location'] = location;
    if (employmentType != null && employmentType.isNotEmpty) params['employment_type'] = employmentType;
    if (minSalary != null) params['min_salary'] = minSalary.toString();
    if (skillId != null) params['skill_id'] = skillId.toString();
    if (category != null && category.isNotEmpty && category != 'All') params['category'] = category;
    if (categoryId != null) params['category_id'] = categoryId.toString();

    final response = await _apiService.get(ApiConstants.jobs, queryParams: params);
    if (response.success && response.data is List) {
      return (response.data as List).map((j) => JobModel.fromJson(j)).toList();
    }
    return [];
  }

  /// Get list of Ethiopian Job Categories with vacancy counts
  Future<List<JobCategoryModel>> getCategories({bool includeTitles = false}) async {
    final response = await _apiService.get(
      ApiConstants.categories,
      queryParams: includeTitles ? {'include_titles': '1'} : null,
    );
    if (response.success && response.data is List) {
      return (response.data as List).map((c) => JobCategoryModel.fromJson(c)).toList();
    }
    // Offline fallback to bundled catalogue
    return EthiopianJobCatalogue.categories.map((c) => JobCategoryModel(
      id: c.id,
      name: c.name,
      slug: c.slug,
      iconName: c.iconName,
      titlesCount: c.titles.length,
      titles: c.titles.map((t) => JobTitleModel(id: 0, categoryId: c.id, title: t, slug: '')).toList(),
    )).toList();
  }

  /// Search standard Ethiopian job titles
  Future<List<JobTitleModel>> getJobTitles({int? categoryId, String? query, int limit = 50}) async {
    final Map<String, String> params = {'limit': limit.toString()};
    if (categoryId != null) params['category_id'] = categoryId.toString();
    if (query != null && query.isNotEmpty) params['query'] = query;

    final response = await _apiService.get(ApiConstants.jobTitles, queryParams: params);
    if (response.success && response.data is List) {
      return (response.data as List).map((t) => JobTitleModel.fromJson(t)).toList();
    }
    // Offline fallback
    final staticMatches = EthiopianJobCatalogue.searchTitles(query ?? '', limit: limit);
    return staticMatches.map((t) => JobTitleModel(
      id: 0,
      categoryId: categoryId ?? 0,
      title: t,
      slug: '',
    )).toList();
  }

  Future<JobModel?> getJobDetails(int id) async {
    final response = await _apiService.get('${ApiConstants.jobs}/$id');
    if (response.success && response.data != null) {
      return JobModel.fromJson(response.data);
    }
    return null;
  }

  Future<List<JobModel>> getRecommendations({int limit = 20}) async {
    final response = await _apiService.get(ApiConstants.recommendations, queryParams: {'limit': limit.toString()});
    if (response.success && response.data is List) {
      return (response.data as List).map((j) => JobModel.fromJson(j)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> getMatchDetails(int jobId) async {
    final response = await _apiService.get('${ApiConstants.jobs}/$jobId/match');
    if (response.success && response.data != null) {
      return response.data['match_analysis'];
    }
    return null;
  }

  Future<bool> saveJob(int jobId) async {
    final response = await _apiService.post('${ApiConstants.jobs}/$jobId/save', {});
    return response.success;
  }

  Future<bool> unsaveJob(int jobId) async {
    final response = await _apiService.delete('${ApiConstants.jobs}/$jobId/save');
    return response.success;
  }

  Future<List<JobModel>> getSavedJobs() async {
    final response = await _apiService.get(ApiConstants.savedJobs);
    if (response.success && response.data is List) {
      return (response.data as List).map((j) => JobModel.fromJson(j)).toList();
    }
    return [];
  }

  // Employer methods
  Future<List<JobModel>> getEmployerJobs() async {
    final response = await _apiService.get(ApiConstants.employerJobs);
    if (response.success && response.data is List) {
      return (response.data as List).map((j) => JobModel.fromJson(j)).toList();
    }
    return [];
  }

  Future<ApiResponse> createJob(Map<String, dynamic> jobData) async {
    return await _apiService.post(ApiConstants.jobs, jobData);
  }

  Future<ApiResponse> updateJob(int id, Map<String, dynamic> jobData) async {
    return await _apiService.put('${ApiConstants.jobs}/$id', jobData);
  }

  Future<ApiResponse> archiveJob(int id) async {
    return await _apiService.delete('${ApiConstants.jobs}/$id');
  }

  Future<ApiResponse> deleteJob(int id) async {
    return await archiveJob(id);
  }

  Future<List<dynamic>> getJobApplicants(int jobId) async {
    final response = await _apiService.get('${ApiConstants.jobs}/$jobId/applicants');
    if (response.success && response.data is List) {
      return response.data as List;
    }
    return [];
  }

  Future<ApiResponse> reportJob(int jobId, String reason, String? description) async {
    return await _apiService.post(ApiConstants.reports, {
      'job_id': jobId,
      'reason': reason,
      'description': description,
    });
  }

  Future<ApiResponse> exportCandidatePack(int jobId) async {
    return await _apiService.post('/jobs/$jobId/export-candidates', {});
  }

  Future<List<Map<String, dynamic>>> getSalaryBenchmarks() async {
    final response = await _apiService.get('/salary-benchmarks');
    if (response.success && response.data is List) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return [];
  }

  Future<Map<String, dynamic>?> getHyperlocalRadar({
    double? lat,
    double? lon,
    String? subCity,
    double radiusKm = 15.0,
  }) async {
    final params = <String, String>{
      'radius_km': radiusKm.toString(),
    };
    if (lat != null && lon != null) {
      params['lat'] = lat.toString();
      params['lon'] = lon.toString();
    }
    if (subCity != null && subCity.isNotEmpty) {
      params['sub_city'] = subCity;
    }

    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final response = await _apiService.get('/jobs/radar?$query');
    if (response.success && response.data is Map) {
      return Map<String, dynamic>.from(response.data);
    }
    return null;
  }
}
