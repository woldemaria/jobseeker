import 'package:flutter/material.dart';

import '../../repositories/profile_repository.dart';
import 'quiz_take_screen.dart';

class QuizListScreen extends StatefulWidget {
  final ProfileRepository profRepo;

  const QuizListScreen({super.key, required this.profRepo});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  List<Map<String, dynamic>> _quizzes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await widget.profRepo.getQuizzes();
      if (mounted) {
        setState(() {
          _quizzes = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load assessments: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skill Assessments & Badges'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQuizzes,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
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
                          onPressed: _loadQuizzes,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _quizzes.isEmpty
                  ? const Center(
                      child: Text('No skill assessments currently available.'),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Educational header banner
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0D6B4F), Color(0xFF1B8A6B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white24,
                                child: Icon(Icons.verified, color: Colors.white, size: 28),
                              ),
                              SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Earn Verified Ethiopian Badges',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Score 80% or higher to earn employer-trusted badges that boost your ranking in matching algorithms.',
                                      style: TextStyle(fontSize: 12, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Available Assessments',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        ..._quizzes.map((quiz) {
                          final quizId = quiz['id'] as int;
                          final title = quiz['title'] ?? 'Skill Assessment';
                          final desc = quiz['description'] ?? 'Test your industry competence';
                          final passingScore = quiz['passing_score'] ?? 80;
                          final isVerified = quiz['is_verified'] == true;
                          final skillName = quiz['skill']?['name'] ?? 'Technical Skill';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isVerified
                                    ? const Color(0xFF0D6B4F).withOpacity(0.4)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: isVerified
                                            ? const Color(0xFFDCFCE7)
                                            : const Color(0xFFF1F5F9),
                                        child: Icon(
                                          isVerified ? Icons.verified : Icons.quiz_outlined,
                                          color: isVerified
                                              ? const Color(0xFF15803D)
                                              : const Color(0xFF0D6B4F),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Domain: $skillName',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF0D6B4F),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isVerified)
                                        const Chip(
                                          label: Text(
                                            'Badge Earned',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF15803D),
                                            ),
                                          ),
                                          backgroundColor: Color(0xFFDCFCE7),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    desc,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.rule,
                                            size: 16,
                                            color: Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Pass Mark: $passingScore%',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isVerified
                                              ? const Color(0xFFE2E8F0)
                                              : const Color(0xFF0D6B4F),
                                          foregroundColor: isVerified
                                              ? const Color(0xFF334155)
                                              : Colors.white,
                                          elevation: isVerified ? 0 : 2,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () async {
                                          final updated = await Navigator.push<bool>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => QuizTakeScreen(
                                                quizId: quizId,
                                                quizTitle: title,
                                                profRepo: widget.profRepo,
                                              ),
                                            ),
                                          );
                                          if (updated == true) {
                                            _loadQuizzes();
                                          }
                                        },
                                        icon: Icon(
                                          isVerified ? Icons.replay : Icons.play_arrow,
                                          size: 16,
                                        ),
                                        label: Text(
                                          isVerified ? 'Retake Quiz' : 'Take Assessment',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
    );
  }
}
