import 'package:flutter/material.dart';
import '../../models/application_model.dart';
import '../../repositories/application_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_badge.dart';
import 'application_detail_screen.dart';

class MyApplicationsScreen extends StatefulWidget {
  final ApplicationRepository appRepo;

  const MyApplicationsScreen({
    super.key,
    required this.appRepo,
  });

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  List<ApplicationModel> _applications = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    final apps = await widget.appRepo.getMyApplications();
    if (mounted) {
      setState(() {
        _applications = apps;
        _isLoading = false;
      });
    }
  }

  List<ApplicationModel> get _filteredApplications {
    if (_selectedFilter == 'all') return _applications;
    if (_selectedFilter == 'pending') {
      return _applications.where((a) => a.status == 'submitted' || a.status == 'pending').toList();
    }
    if (_selectedFilter == 'interview') {
      return _applications.where((a) => a.status == 'interview' || a.interviewAt != null).toList();
    }
    return _applications.where((a) => a.status.toLowerCase() == _selectedFilter).toList();
  }

  int _countFor(String filter) {
    if (filter == 'all') return _applications.length;
    if (filter == 'pending') {
      return _applications.where((a) => a.status == 'submitted' || a.status == 'pending').length;
    }
    if (filter == 'interview') {
      return _applications.where((a) => a.status == 'interview' || a.interviewAt != null).length;
    }
    return _applications.where((a) => a.status.toLowerCase() == filter).length;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final filtered = _filteredApplications;

    final filterOptions = [
      {'key': 'all', 'label': 'All'},
      {'key': 'pending', 'label': 'Submitted'},
      {'key': 'under_review', 'label': 'Under Review'},
      {'key': 'shortlisted', 'label': 'Shortlisted'},
      {'key': 'interview', 'label': 'Interview'},
      {'key': 'accepted', 'label': 'Accepted'},
      {'key': 'rejected', 'label': 'Rejected'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('applications')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApplications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter Tab Chips
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: filterOptions.map((opt) {
                        final key = opt['key']!;
                        final label = opt['label']!;
                        final count = _countFor(key);
                        final isSelected = _selectedFilter == key;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              count > 0 ? '$label ($count)' : label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : const Color(0xFF334155),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF0D6B4F),
                            checkmarkColor: Colors.white,
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (_) {
                              setState(() => _selectedFilter = key);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: filtered.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.assignment_outlined,
                          title: _selectedFilter == 'all'
                              ? 'No Applications Yet'
                              : 'No $_selectedFilter Applications',
                          subtitle: _selectedFilter == 'all'
                              ? 'Explore vacancies and apply to start tracking your recruitment status here.'
                              : 'You have no applications under this specific recruitment status right now.',
                        )
                      : RefreshIndicator(
                          onRefresh: _loadApplications,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final app = filtered[index];
                              final hasInterview = app.interviewAt != null || app.status == 'interview';

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                elevation: 0.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: hasInterview
                                        ? const Color(0xFF0D6B4F).withOpacity(0.4)
                                        : Colors.grey.shade200,
                                    width: hasInterview ? 1.5 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ApplicationDetailScreen(
                                          applicationId: app.id,
                                          appRepo: widget.appRepo,
                                        ),
                                      ),
                                    ).then((_) => _loadApplications());
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                app.job?.title ?? 'Vacancy Application',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                            ),
                                            StatusBadge(status: app.status),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          app.job?.employer?.organizationName ?? 'Employer',
                                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                        ),
                                        const SizedBox(height: 8),

                                        if (hasInterview && app.interviewAt != null) ...[
                                          Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0D6B4F).withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.event, size: 16, color: Color(0xFF0D6B4F)),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'Interview: ${app.interviewAt!.replaceFirst('T', ' ').split('.').first} (${app.interviewType ?? "Online"})',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF0D6B4F),
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF0D6B4F),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    app.interviewStatus?.toUpperCase() ?? 'BOOKED',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],

                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Applied: ${app.appliedAt.split('T').first}',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                            ),
                                            const Row(
                                              children: [
                                                Text(
                                                  'View Details',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF0D6B4F),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Icon(Icons.chevron_right, size: 16, color: Color(0xFF0D6B4F)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
