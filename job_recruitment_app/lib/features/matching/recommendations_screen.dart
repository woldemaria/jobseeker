import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/job_model.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/job_card.dart';
import '../applications/apply_job_sheet.dart';
import '../jobs/job_details_screen.dart';
import '../profile/skills_management_screen.dart';
import '../authentication/login_screen.dart';
import '../../services/api_service.dart';
import 'match_detail_dialog.dart';

class RecommendationsScreen extends StatefulWidget {
  final JobRepository jobRepo;
  final ApplicationRepository appRepo;
  final ProfileRepository profRepo;

  const RecommendationsScreen({
    super.key,
    required this.jobRepo,
    required this.appRepo,
    required this.profRepo,
  });

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<JobModel> _recommendations = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedEmploymentType = 'all';
  double _minScore = 0;
  String _searchQuery = '';
  String _sortBy = 'match'; // 'match', 'recent', 'salary'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchRecommendations();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    }
  }

  Future<void> _fetchRecommendations() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final results = await widget.jobRepo.getRecommendations();
      if (mounted) {
        setState(() {
          _recommendations = results;
          if (results.isEmpty && widget.jobRepo.lastErrorMessage != null) {
            _errorMessage = widget.jobRepo.lastErrorMessage;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Unable to connect to the recommendation engine. Please verify your internet connection and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleApply(JobModel job) {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in or create an account to apply.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }
    ApplyJobSheet.show(
      context,
      job,
      widget.appRepo,
      widget.profRepo,
      () => _fetchRecommendations(),
    );
  }

  List<JobModel> get _filteredRecommendations {
    final list = _recommendations.where((job) {
      // Keyword search filter (title, employer, skills)
      if (_searchQuery.isNotEmpty) {
        final titleMatch = job.title.toLowerCase().contains(_searchQuery);
        final employerMatch = (job.employer?.organizationName ?? '')
            .toLowerCase()
            .contains(_searchQuery);
        final skillMatch = job.skills.any(
          (s) => s.name.toLowerCase().contains(_searchQuery),
        );
        final locMatch = job.location.toLowerCase().contains(_searchQuery);
        if (!titleMatch && !employerMatch && !skillMatch && !locMatch) {
          return false;
        }
      }

      // Employment type filter
      if (_selectedEmploymentType != 'all') {
        final jobType = job.employmentType.toLowerCase().replaceAll('-', '_');
        final filterType = _selectedEmploymentType.toLowerCase().replaceAll(
          '-',
          '_',
        );
        if (!jobType.contains(filterType) && !filterType.contains(jobType)) {
          return false;
        }
      }

      // Match score filter
      if (_minScore > 0) {
        final score = job.matchScore ?? 0.0;
        if (score < _minScore) return false;
      }
      return true;
    }).toList();

    // Sorting
    if (_sortBy == 'match') {
      list.sort((a, b) => (b.matchScore ?? 0.0).compareTo(a.matchScore ?? 0.0));
    } else if (_sortBy == 'recent') {
      list.sort((a, b) => b.id.compareTo(a.id));
    } else if (_sortBy == 'salary') {
      list.sort((a, b) {
        final salA = a.salaryMax ?? a.salaryMin ?? 0.0;
        final salB = b.salaryMax ?? b.salaryMin ?? 0.0;
        return salB.compareTo(salA);
      });
    }

    return list;
  }

  void _openSkillsManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SkillsManagementScreen(profRepo: widget.profRepo),
      ),
    ).then((_) => _fetchRecommendations());
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final filtered = _filteredRecommendations;

    final employmentTypes = [
      {'key': 'all', 'label': 'All Types'},
      {'key': 'full_time', 'label': 'Full-time'},
      {'key': 'part_time', 'label': 'Part-time'},
      {'key': 'contract', 'label': 'Contract'},
      {'key': 'internship', 'label': 'Internship'},
      {'key': 'remote', 'label': 'Remote'},
      {'key': 'freelance', 'label': 'Freelance'},
    ];

    final scoreFilters = [
      {'score': 0.0, 'label': 'Any Match'},
      {'score': 80.0, 'label': '80%+ Match'},
      {'score': 60.0, 'label': '60%+ Match'},
      {'score': 40.0, 'label': '40%+ Match'},
    ];

    final sortOptions = [
      {'key': 'match', 'label': 'Best Match'},
      {'key': 'recent', 'label': 'Newest'},
      {'key': 'salary', 'label': 'Highest Salary'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('recommendations')),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: 'Skill Profile & Badges',
            onPressed: _openSkillsManagement,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Recommendations',
            onPressed: _fetchRecommendations,
          ),
        ],
      ),
      body: _buildBody(context, filtered, employmentTypes, scoreFilters, sortOptions),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<JobModel> filtered,
    List<Map<String, String>> employmentTypes,
    List<Map<String, Object>> scoreFilters,
    List<Map<String, String>> sortOptions,
  ) {
    final auth = Provider.of<AuthService>(context, listen: false);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!auth.isAuthenticated && _recommendations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D6B4F).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  size: 48,
                  color: Color(0xFF0D6B4F),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Sign In for Tailored Matches',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in or create a job seeker account to generate multi-criteria AI recommendations based on your skills, experience, and education.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  final jobRepo = Provider.of<JobRepository>(
                    context,
                    listen: false,
                  );
                  final appRepo = Provider.of<ApplicationRepository>(
                    context,
                    listen: false,
                  );
                  final profRepo = Provider.of<ProfileRepository>(
                    context,
                    listen: false,
                  );
                  final apiService = Provider.of<ApiService>(
                    context,
                    listen: false,
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoginScreen(
                        authService: auth,
                        jobRepo: jobRepo,
                        appRepo: appRepo,
                        profRepo: profRepo,
                        apiService: apiService,
                      ),
                    ),
                  ).then((_) => _fetchRecommendations());
                },
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Sign In / Register'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6B4F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && _recommendations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 52,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(height: 14),
              const Text(
                'Unable to Load Recommendations',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchRecommendations,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6B4F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.psychology_outlined,
        title: 'No Recommendations Yet',
        subtitle:
            'Add your professional skills, work experiences, and education records to generate multi-criteria AI job recommendations.',
        actionLabel: 'Add Skills & Complete Profile',
        onAction: _openSkillsManagement,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRecommendations,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
                  // Multi-Criteria Explanation Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D6B4F).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF0D6B4F).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D6B4F).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFF0D6B4F),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Ranked with multi-criteria AI matching: Skills (40%), Education (20%), Experience (15%), Location (10%), Type (10%).',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0F5132),
                              height: 1.3,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _openSkillsManagement,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            'Edit Skills',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D6B4F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar in Recommendations
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search recommendations by title, skill, company...',
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 20,
                          color: Color(0xFF0D6B4F),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF0D6B4F),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Sort Bar & Recommendation Count
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${filtered.length} Curated Matches',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Sort: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            DropdownButton<String>(
                              value: _sortBy,
                              isDense: true,
                              underline: const SizedBox(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D6B4F),
                              ),
                              items: sortOptions.map((opt) {
                                return DropdownMenuItem<String>(
                                  value: opt['key'],
                                  child: Text(opt['label']!),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _sortBy = val);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Employment Type Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: employmentTypes.map((type) {
                        final isSelected =
                            _selectedEmploymentType == type['key'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(
                              type['label']!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF334155),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF0D6B4F),
                            checkmarkColor: Colors.white,
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (_) {
                              setState(
                                () => _selectedEmploymentType = type['key']!,
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Score Threshold Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    child: Row(
                      children: scoreFilters.map((s) {
                        final scoreVal = s['score'] as double;
                        final isSelected = _minScore == scoreVal;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              s['label'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF475569),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF0F766E),
                            backgroundColor: Colors.white,
                            onSelected: (_) {
                              setState(() => _minScore = scoreVal);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 6),

                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.filter_list_off,
                              size: 40,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No matching vacancies for these filters.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _selectedEmploymentType = 'all';
                                  _minScore = 0;
                                });
                              },
                              child: const Text('Reset All Filters'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filtered.map((job) {
                      return JobCard(
                        job: job,
                        onApply: () => _handleApply(job),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => JobDetailsScreen(
                                jobId: job.id,
                                jobRepo: widget.jobRepo,
                                appRepo: widget.appRepo,
                                profRepo: widget.profRepo,
                              ),
                            ),
                          ).then((_) => _fetchRecommendations());
                        },
                        onSaveToggle: () async {
                          final newSaved = !job.isSaved;
                          setState(() {
                            final idx = _recommendations.indexWhere(
                              (j) => j.id == job.id,
                            );
                            if (idx != -1) {
                              _recommendations[idx] = _recommendations[idx]
                                  .copyWith(isSaved: newSaved);
                            }
                          });
                          if (newSaved) {
                            await widget.jobRepo.saveJob(job.id);
                          } else {
                            await widget.jobRepo.unsaveJob(job.id);
                          }
                        },
                        onMatchTap: () async {
                          if (job.matchDetails != null) {
                            MatchDetailDialog.show(
                              context,
                              job.title,
                              job.matchDetails!,
                            );
                          } else {
                            final details = await widget.jobRepo
                                .getMatchDetails(job.id);
                            if (details != null && mounted) {
                              MatchDetailDialog.show(
                                context,
                                job.title,
                                details,
                              );
                            }
                          }
                        },
                      );
                    }),
                ],
              ),
            );
  }
}
