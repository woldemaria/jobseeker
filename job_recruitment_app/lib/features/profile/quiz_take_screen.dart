import 'package:flutter/material.dart';

import '../../repositories/profile_repository.dart';

class QuizTakeScreen extends StatefulWidget {
  final int quizId;
  final String quizTitle;
  final ProfileRepository profRepo;

  const QuizTakeScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
    required this.profRepo,
  });

  @override
  State<QuizTakeScreen> createState() => _QuizTakeScreenState();
}

class _QuizTakeScreenState extends State<QuizTakeScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<dynamic> _questions = [];
  int _currentIndex = 0;
  final Map<int, int> _selectedAnswers = {}; // question_id -> option_id

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await widget.profRepo.getQuizDetails(widget.quizId);
      if (mounted) {
        if (data != null) {
          final questions = (data['questions'] as List?) ?? [];
          setState(() {
            _questions = questions;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Could not load quiz questions.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load assessment: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitQuiz() async {
    if (_selectedAnswers.length < _questions.length) {
      final unselected = _questions.length - _selectedAnswers.length;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unanswered Questions'),
          content: Text(
            'You have $unselected unanswered question(s). Are you sure you want to submit your assessment now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Review Questions'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6B4F),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Map to answers format
      final formattedAnswers = _selectedAnswers.map(
        (qId, oId) => MapEntry(qId.toString(), oId),
      );

      final resp = await widget.profRepo.submitQuiz(widget.quizId, formattedAnswers);

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (resp.success && resp.data is Map) {
          final result = resp.data as Map<String, dynamic>;
          _showResultDialog(result);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(resp.formattedErrorMessage)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission error: $e')),
        );
      }
    }
  }

  void _showResultDialog(Map<String, dynamic> result) {
    final passed = result['passed'] == true;
    final score = (result['score_percent'] as num?)?.toDouble() ?? 0.0;
    final correct = result['correct_count'] ?? 0;
    final total = result['total_questions'] ?? _questions.length;
    final message = result['message'] ?? (passed ? 'Assessment passed!' : 'Keep practicing!');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: passed ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              child: Icon(
                passed ? Icons.verified : Icons.replay,
                size: 44,
                color: passed ? const Color(0xFF15803D) : const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              passed ? 'Assessment Passed!' : 'Assessment Incomplete',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${score.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: passed ? const Color(0xFF0D6B4F) : const Color(0xFFDC2626),
              ),
            ),
            Text(
              '$correct out of $total questions answered correctly',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: passed ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: passed ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  if (passed) ...[
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.workspace_premium, color: Color(0xFFD97706), size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Verified Skill Badge Earned!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!passed)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _selectedAnswers.clear();
                  _currentIndex = 0;
                });
              },
              child: const Text('Try Again'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D6B4F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true); // Return to quiz list with refresh
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quizTitle),
        elevation: 0,
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
                          onPressed: _loadQuiz,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _questions.isEmpty
                  ? const Center(child: Text('No questions available in this assessment.'))
                  : _buildQuizContent(),
    );
  }

  Widget _buildQuizContent() {
    final currentQ = _questions[_currentIndex] as Map<String, dynamic>;
    final qId = currentQ['id'] as int;
    final qText = currentQ['question_text'] ?? 'Question';
    final points = currentQ['points'] ?? 20;
    final options = (currentQ['options'] as List?) ?? [];
    final selectedOptionId = _selectedAnswers[qId];

    final progress = (_currentIndex + 1) / _questions.length;

    return SafeArea(
      child: Column(
        children: [
          // Linear Progress Indicator
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D6B4F)),
            minHeight: 6,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(
                    'Question ${_currentIndex + 1} of ${_questions.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D6B4F),
                    ),
                  ),
                  backgroundColor: const Color(0xFFE8F5E9),
                ),
                Text(
                  '$points Points',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    qText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select the correct answer:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                ...options.map((opt) {
                  final optMap = opt as Map<String, dynamic>;
                  final optId = optMap['id'] as int;
                  final optText = optMap['option_text'] ?? '';
                  final isSelected = selectedOptionId == optId;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _selectedAnswers[qId] = optId;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0D6B4F).withOpacity(0.08)
                              : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF0D6B4F)
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? const Color(0xFF0D6B4F)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF0D6B4F)
                                      : Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                optText,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected
                                      ? const Color(0xFF0D6B4F)
                                      : Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // Navigation Bottom Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentIndex > 0)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () {
                      setState(() => _currentIndex--);
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Prev'),
                  )
                else
                  const SizedBox.shrink(),
                const Spacer(),
                if (_currentIndex < _questions.length - 1)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6B4F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      setState(() => _currentIndex++);
                    },
                    label: const Text('Next'),
                    icon: const Icon(Icons.arrow_forward),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6B4F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _isSubmitting ? null : _submitQuiz,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: const Text('Submit Assessment'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
