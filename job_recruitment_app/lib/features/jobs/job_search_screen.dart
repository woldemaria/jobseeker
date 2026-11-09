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
import '../../shared/widgets/advertisement_banner_carousel.dart';
import '../../data/ethiopian_job_titles_data.dart';
import '../matching/match_detail_dialog.dart';
import '../applications/apply_job_sheet.dart';
import 'job_details_screen.dart';
import 'notice_board_lookup_dialog.dart';

class JobSearchScreen extends StatefulWidget {
  final JobRepository jobRepo;
  final ApplicationRepository? appRepo;
  final ProfileRepository? profRepo;
  final String? initialCategory;
  final String? initialKeyword;
  final String? initialQuery;

  const JobSearchScreen({
    super.key,
    required this.jobRepo,
    this.appRepo,
    this.profRepo,
    this.initialCategory,
    this.initialKeyword,
    this.initialQuery,
  });

  @override
  State<JobSearchScreen> createState() => _JobSearchScreenState();
}

class _JobSearchScreenState extends State<JobSearchScreen> {
  final _searchController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedType;
  String _selectedCategory = 'All';
  List<JobModel> _jobs = [];
  bool _isLoading = false;
  List<String> _titleSuggestions = [];
  bool _showSuggestions = false;

  final List<String> _employmentTypes = [
    'All',
    'Full-time',
    'Part-time',
    'Contract',
    'Internship',
    'Remote',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _selectedCategory = widget.initialCategory!;
    }
    final kw = widget.initialKeyword ?? widget.initialQuery;
    if (kw != null && kw.isNotEmpty) {
      _searchController.text = kw;
    }
    _searchController.addListener(_onSearchChanged);
    _performSearch();
  }

  void _onSearchChanged() {
    final text = _searchController.text.trim();
    if (text.length >= 2) {
      final suggestions = EthiopianJobCatalogue.searchTitles(
        text,
        categoryName: _selectedCategory != 'All' ? _selectedCategory : null,
        limit: 5,
      );
      setState(() {
        _titleSuggestions = suggestions;
        _showSuggestions = suggestions.isNotEmpty;
      });
    } else {
      if (_showSuggestions) {
        setState(() {
          _titleSuggestions = [];
          _showSuggestions = false;
        });
      }
    }
  }

  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
      _showSuggestions = false;
    });
    final keyword = _searchController.text.trim();
    final location = _locationController.text.trim();
    final type = (_selectedType == 'All' || _selectedType == null)
        ? null
        : _selectedType;
    final category = (_selectedCategory == 'All') ? null : _selectedCategory;

    try {
      final results = await widget.jobRepo.getJobs(
        keyword: keyword.isNotEmpty ? keyword : null,
        location: location.isNotEmpty ? location : null,
        employmentType: type,
        category: category,
      );

      if (mounted) {
        setState(() {
          _jobs = results;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearFilters() {
    _searchController.clear();
    _locationController.clear();
    setState(() {
      _selectedType = null;
      _selectedCategory = 'All';
      _showSuggestions = false;
    });
    _performSearch();
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
    final effectiveAppRepo = widget.appRepo ??
        Provider.of<ApplicationRepository>(context, listen: false);
    final effectiveProfRepo = widget.profRepo ??
        Provider.of<ProfileRepository>(context, listen: false);

    ApplyJobSheet.show(
      context,
      job,
      effectiveAppRepo,
      effectiveProfRepo,
      () => _performSearch(),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final effectiveAppRepo = widget.appRepo ??
        Provider.of<ApplicationRepository>(context, listen: false);
    final effectiveProfRepo = widget.profRepo ??
        Provider.of<ProfileRepository>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('search_jobs')),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Notice Board Poster Lookup',
            onPressed: () {
              NoticeBoardLookupDialog.show(
                context,
                jobRepo: widget.jobRepo,
                appRepo: effectiveAppRepo,
                profRepo: effectiveProfRepo,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _performSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search 475+ Ethiopian job titles...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch();
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),

                // Job Title Autocomplete Suggestions Dropdown
                if (_showSuggestions && _titleSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _titleSuggestions.map((suggestion) {
                        final catData =
                            EthiopianJobCatalogue.findCategoryForTitle(
                              suggestion,
                            );
                        return InkWell(
                          onTap: () {
                            _searchController.text = suggestion;
                            setState(() {
                              _showSuggestions = false;
                              if (catData != null &&
                                  _selectedCategory == 'All') {
                                _selectedCategory = catData.name;
                              }
                            });
                            _performSearch();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  catData?.icon ?? Icons.work_outline,
                                  size: 16,
                                  color: const Color(0xFF0D6B4F),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    suggestion,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (catData != null)
                                  Text(
                                    catData.name,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          hintText: loc.t('location'),
                          prefixIcon: const Icon(
                            Icons.location_on_outlined,
                            size: 20,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _performSearch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedType,
                        hint: Text(
                          loc.t('employment_type'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: _employmentTypes.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(
                              t,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedType = val);
                          _performSearch();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Ethiopian Job Categories Horizontal Chips Bar
          Container(
            height: 48,
            color: const Color(0xFFF8FAFC),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                // 'All' chip
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('All Categories'),
                    avatar: const Icon(Icons.grid_view, size: 14),
                    selected: _selectedCategory == 'All',
                    selectedColor: const Color(0xFF0D6B4F).withOpacity(0.18),
                    checkmarkColor: const Color(0xFF0D6B4F),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: _selectedCategory == 'All'
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _selectedCategory == 'All'
                          ? const Color(0xFF0D6B4F)
                          : const Color(0xFF334155),
                    ),
                    onSelected: (selected) {
                      setState(() => _selectedCategory = 'All');
                      _performSearch();
                    },
                  ),
                ),
                // 30 Ethiopian Categories
                ...EthiopianJobCatalogue.categories.map((cat) {
                  final isSelected = _selectedCategory == cat.name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text('${cat.name} (${cat.titles.length})'),
                      avatar: Icon(
                        cat.icon,
                        size: 14,
                        color: isSelected
                            ? const Color(0xFF0D6B4F)
                            : const Color(0xFF64748B),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF0D6B4F).withOpacity(0.18),
                      checkmarkColor: const Color(0xFF0D6B4F),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? const Color(0xFF0D6B4F)
                            : const Color(0xFF334155),
                      ),
                      onSelected: (selected) {
                        setState(
                          () => _selectedCategory = selected ? cat.name : 'All',
                        );
                        _performSearch();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),

          // Job list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _jobs.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.work_off_outlined,
                    title: loc.t('no_jobs_found'),
                    subtitle: 'No jobs found matching your category and filter criteria. Try adjusting keywords.',
                    actionLabel: 'Reset Filters',
                    onAction: _clearFilters,
                  )
                : RefreshIndicator(
                    onRefresh: _performSearch,
                    child: ListView.builder(
                      itemCount: _jobs.length + (_jobs.length >= 2 ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == 2 && _jobs.length >= 2) {
                          return const AdvertisementBannerCarousel(
                            placement: 'job_list',
                            layoutType: BannerLayoutType.inline,
                            height: 95,
                          );
                        }
                        final jobIndex = (_jobs.length >= 2 && index > 2)
                            ? index - 1
                            : index;
                        if (jobIndex >= _jobs.length) {
                          return const SizedBox.shrink();
                        }
                        final job = _jobs[jobIndex];
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
                                  appRepo: effectiveAppRepo,
                                  profRepo: effectiveProfRepo,
                                ),
                              ),
                            ).then((_) => _performSearch());
                          },
                          onSaveToggle: () async {
                            final newSaved = !job.isSaved;
                            setState(() {
                              final idx = _jobs.indexWhere(
                                (j) => j.id == job.id,
                              );
                              if (idx != -1) {
                                _jobs[idx] = _jobs[idx].copyWith(
                                  isSaved: newSaved,
                                );
                              }
                            });
                            if (newSaved) {
                              await widget.jobRepo.saveJob(job.id);
                            } else {
                              await widget.jobRepo.unsaveJob(job.id);
                            }
                          },
                          onMatchTap: job.matchDetails != null
                              ? () => MatchDetailDialog.show(
                                  context,
                                  job.title,
                                  job.matchDetails!,
                                )
                              : null,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
