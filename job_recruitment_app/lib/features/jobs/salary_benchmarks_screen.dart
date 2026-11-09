import 'package:flutter/material.dart';

import '../../repositories/job_repository.dart';
import 'job_search_screen.dart';

class SalaryBenchmarksScreen extends StatefulWidget {
  final JobRepository jobRepo;

  const SalaryBenchmarksScreen({super.key, required this.jobRepo});

  @override
  State<SalaryBenchmarksScreen> createState() => _SalaryBenchmarksScreenState();
}

class _SalaryBenchmarksScreenState extends State<SalaryBenchmarksScreen> {
  List<Map<String, dynamic>> _allBenchmarks = [];
  List<Map<String, dynamic>> _filteredBenchmarks = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategory = 'All';
  final _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Information Technology',
    'Accounting and Finance',
    'Construction and Engineering',
    'Agriculture and Farming',
    'Education and Teaching',
    'Healthcare and Medical',
    'Transportation and Logistics',
    'Hotel, Restaurant and Tourism',
    'Shopping, Retail and Sales',
  ];

  @override
  void initState() {
    super.initState();
    _loadBenchmarks();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBenchmarks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await widget.jobRepo.getSalaryBenchmarks();
      if (mounted) {
        setState(() {
          _allBenchmarks = list;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load salary benchmarks: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredBenchmarks = _allBenchmarks.where((item) {
        final role = (item['role'] ?? '').toString().toLowerCase();
        final category = (item['category'] ?? '').toString();

        final matchesCategory = _selectedCategory == 'All' || category == _selectedCategory;
        final matchesQuery = query.isEmpty || role.contains(query) || category.toLowerCase().contains(query);

        return matchesCategory && matchesQuery;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ethiopian Salary Benchmarks'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadBenchmarks,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top search & overview banner
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              color: Theme.of(context).cardColor,
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search roles (e.g. Flutter Developer, Accountant)...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Horizontal Categories Carousel
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
                      itemBuilder: (ctx, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : const Color(0xFF334155),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF0D6B4F),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _selectedCategory = cat);
                              _applyFilters();
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Benchmark List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                const SizedBox(height: 12),
                                Text(_errorMessage!, textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadBenchmarks,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _filteredBenchmarks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.monetization_on_outlined,
                                      size: 56, color: Color(0xFF94A3B8)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No salary benchmarks match your search.',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _selectedCategory = 'All');
                                      _applyFilters();
                                    },
                                    child: const Text('Reset Filters'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredBenchmarks.length,
                              itemBuilder: (ctx, index) {
                                final b = _filteredBenchmarks[index];
                                return _buildBenchmarkCard(b);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenchmarkCard(Map<String, dynamic> b) {
    final role = b['role'] ?? 'Role';
    final category = b['category'] ?? 'Category';
    final median = (b['median_etb'] as num?)?.toInt() ?? 0;
    final p25 = (b['p25_etb'] as num?)?.toInt() ?? 0;
    final p75 = (b['p75_etb'] as num?)?.toInt() ?? 0;
    final min = (b['min_etb'] as num?)?.toInt() ?? 0;
    final max = (b['max_etb'] as num?)?.toInt() ?? 0;
    final sampleSize = b['sample_size'] ?? 30;
    final currency = b['currency'] ?? 'ETB';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline, size: 14, color: Color(0xFFB45309)),
                      const SizedBox(width: 4),
                      Text(
                        'N=$sampleSize',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Highlighted Median Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Median Market Salary',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF166534),
                    ),
                  ),
                  Text(
                    '${_formatEtb(median)} $currency/mo',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0D6B4F),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Percentile Visual Spectrum
            const Text(
              'Compensation Band Breakdown:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _percentileColumn('Min', min, currency, const Color(0xFF94A3B8)),
                ),
                Expanded(
                  child: _percentileColumn('25th %ile', p25, currency, const Color(0xFF3B82F6)),
                ),
                Expanded(
                  child: _percentileColumn('Median', median, currency, const Color(0xFF0D6B4F), isBold: true),
                ),
                Expanded(
                  child: _percentileColumn('75th %ile', p75, currency, const Color(0xFF8B5CF6)),
                ),
                Expanded(
                  child: _percentileColumn('Max', max, currency, const Color(0xFFEA580C)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            // Action button to search vacancies matching this role
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0D6B4F),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JobSearchScreen(
                        jobRepo: widget.jobRepo,
                        initialQuery: role.split(' / ').first,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Search Matching Vacancies'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _percentileColumn(String label, int amount, String currency, Color color, {bool isBold = false}) {
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: const Color(0xFF64748B), fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
        ),
        const SizedBox(height: 2),
        Text(
          _formatEtb(amount),
          style: TextStyle(
            fontSize: 11,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatEtb(int value) {
    if (value >= 1000) {
      final k = (value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1);
      return '${k}k';
    }
    return value.toString();
  }
}
