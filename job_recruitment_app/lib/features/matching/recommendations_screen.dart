import 'package:flutter/material.dart';

import '../../models/job_model.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/job_card.dart';
import '../jobs/job_details_screen.dart';
import '../profile/skills_management_screen.dart';
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
  String _selectedEmploymentType = 'all';
  double _minScore = 0;
  String _searchQuery = '';
  String _sortBy = 'match'; // 'match', 'recent', 'salary'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchRecommendations();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _fetchRecommendations() async {
    setState(() => _isLoading = true);
    try {
      final results = await widget.jobRepo.getRecommendations();
      if (mounted) {
        setState(() {
          _recommendations = results;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recommendations.isEmpty
          ? EmptyStateWidget(
              icon: Icons.psychology_outlined,
              title: 'No Recommendations Yet',
              subtitle: 'Add your professional skills, work experiences, and education records to generate multi-criteria AI job recommendations.',
              actionLabel: 'Add Skills & Complete Profile',
              onAction: _openSkillsManagement,
            )
          : RefreshIndicator(
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
            ),
    );
  }
}
