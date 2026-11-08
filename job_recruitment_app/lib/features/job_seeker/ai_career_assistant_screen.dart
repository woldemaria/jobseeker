import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/job_model.dart';
import '../../repositories/career_repository.dart';
import '../../repositories/job_repository.dart';

class AiCareerAssistantScreen extends StatefulWidget {
  final CareerRepository? careerRepo;
  final JobRepository? jobRepo;
  final int? initialJobId;
  final int initialTabIndex;

  const AiCareerAssistantScreen({
    super.key,
    this.careerRepo,
    this.jobRepo,
    this.initialJobId,
    this.initialTabIndex = 0,
  });

  @override
  State<AiCareerAssistantScreen> createState() =>
      _AiCareerAssistantScreenState();
}

class _AiCareerAssistantScreenState extends State<AiCareerAssistantScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  CareerRepository get _careerRepo =>
      widget.careerRepo ??
      Provider.of<CareerRepository>(context, listen: false);
  JobRepository get _jobRepo =>
      widget.jobRepo ?? Provider.of<JobRepository>(context, listen: false);

  // Q&A State
  final TextEditingController _questionController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isAsking = false;

  // Cover Letter State
  List<JobModel> _availableJobs = [];
  JobModel? _selectedJob;
  String _selectedTone = 'professional';
  final TextEditingController _coverLetterNotesController =
      TextEditingController();
  String? _generatedCoverLetter;
  bool _isGeneratingLetter = false;

  // Interview Simulator State
  List<Map<String, dynamic>> _interviewQuestions = [];
  bool _isLoadingQuestions = false;

  // Skill-Gap State
  Map<String, dynamic>? _skillGapAnalysis;
  bool _isLoadingSkillGap = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadJobs();

    // Default welcome prompt
    _messages.add({
      'isUser': false,
      'text': "Hello! I'm your AI Career Assistant. I can provide personalized career guidance in English and Amharic, draft tailored cover letters, run mock interview practice, and analyze your skill gaps.",
      'action_steps': [
        'Ask questions about career paths or salary benchmarks.',
        'Generate customized cover letters for your job applications.',
        'Practice STAR-method interview questions.',
      ],
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _questionController.dispose();
    _coverLetterNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    try {
      final jobs = await _jobRepo.getJobs();
      if (mounted) {
        setState(() {
          _availableJobs = jobs;
          if (widget.initialJobId != null && jobs.isNotEmpty) {
            _selectedJob = jobs.firstWhere(
              (j) => j.id == widget.initialJobId,
              orElse: () => jobs.first,
            );
          } else if (jobs.isNotEmpty) {
            _selectedJob = jobs.first;
          }
        });

        if (_selectedJob != null) {
          if (widget.initialTabIndex == 2) {
            _loadInterviewQuestions(_selectedJob!.id);
          } else if (widget.initialTabIndex == 3) {
            _loadSkillGap(_selectedJob!.id);
          }
        }
      }
    } catch (_) {}
  }

  // ----------------------------------------------------
  // Q&A Functions
  // ----------------------------------------------------
  Future<void> _sendQuestion([String? preset]) async {
    final text = preset ?? _questionController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'isUser': true, 'text': text});
      _isAsking = true;
    });
    _questionController.clear();

    final result = await _careerRepo.askAssistant(text);
    if (mounted) {
      setState(() {
        _isAsking = false;
        if (result != null) {
          _messages.add({
            'isUser': false,
            'text': result['reply'] ?? '',
            'action_steps': result['action_steps'] ?? [],
            'category': result['category'],
          });
        } else {
          _messages.add({
            'isUser': false,
            'text': "I apologize, but I was unable to retrieve career advice at this moment. Please check your connection and try again.",
          });
        }
      });
    }
  }

  // ----------------------------------------------------
  // Cover Letter Functions
  // ----------------------------------------------------
  Future<void> _generateCoverLetter() async {
    if (_selectedJob == null) return;

    setState(() => _isGeneratingLetter = true);
    final res = await _careerRepo.generateCoverLetter(
      _selectedJob!.id,
      tone: _selectedTone,
      customNotes: _coverLetterNotesController.text.trim().isNotEmpty
          ? _coverLetterNotesController.text.trim()
          : null,
    );

    if (mounted) {
      setState(() {
        _isGeneratingLetter = false;
        if (res != null) {
          _generatedCoverLetter = res['generated_letter'];
        }
      });
    }
  }

  // ----------------------------------------------------
  // Interview Simulator Functions
  // ----------------------------------------------------
  Future<void> _loadInterviewQuestions(int jobId) async {
    setState(() => _isLoadingQuestions = true);
    try {
      final res = await _careerRepo.getInterviewPractice(jobId);
      if (mounted) {
        setState(() {
          if (res != null && res['questions'] is List) {
            _interviewQuestions = (res['questions'] as List)
                .whereType<Map>()
                .map((q) => Map<String, dynamic>.from(q))
                .toList();
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoadingQuestions = false);
      }
    }
  }

  // ----------------------------------------------------
  // Skill-Gap Functions
  // ----------------------------------------------------
  Future<void> _loadSkillGap(int jobId) async {
    setState(() => _isLoadingSkillGap = true);
    try {
      final res = await _careerRepo.getSkillGap(jobId);
      if (mounted) {
        setState(() {
          _skillGapAnalysis = res;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoadingSkillGap = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Text('AI Career Assistant'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Career Coach'),
            Tab(icon: Icon(Icons.description_outlined), text: 'Cover Letter'),
            Tab(icon: Icon(Icons.psychology_outlined), text: 'Interview Prep'),
            Tab(
              icon: Icon(Icons.insights_outlined),
              text: 'Skill-Gap Analysis',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCoachTab(),
          _buildCoverLetterTab(),
          _buildInterviewPrepTab(),
          _buildSkillGapTab(),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // Tab 1: Career Coach
  // ----------------------------------------------------
  Widget _buildCoachTab() {
    final presets = [
      'How to craft a standout CV in Ethiopia?',
      'STAR method for job interviews',
      'Career advice for fresh graduates',
      'How to negotiate salary effectively?',
      'ለስራ ቃለ-መጠይቅ እንዴት መዘጋጀት እችላለሁ?',
    ];

    return Column(
      children: [
        // Presets horizontal list
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.grey.shade50,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: presets.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(
                      Icons.lightbulb_outline,
                      size: 14,
                      color: AppTheme.primaryColor,
                    ),
                    label: Text(p, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _sendQuestion(p),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Chat messages
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final m = _messages[index];
              final isUser = m['isUser'] == true;
              final steps = m['action_steps'] as List<dynamic>?;

              return Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.85,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF0D6B4F) : Colors.white,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: isUser
                          ? const Radius.circular(0)
                          : const Radius.circular(16),
                      bottomLeft: !isUser
                          ? const Radius.circular(0)
                          : const Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: !isUser
                        ? Border.all(color: Colors.grey.shade200)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['text'] ?? '',
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                      if (steps != null && steps.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Divider(height: 16),
                        const Text(
                          'Action Steps:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...steps.map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '• ',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    s.toString(),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        if (_isAsking)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Career Coach is thinking...',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

        // Text input bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _questionController,
                  decoration: const InputDecoration(
                    hintText: 'Ask any career or recruitment question...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: (_) => _sendQuestion(),
                ),
              ),
              IconButton.filled(
                icon: const Icon(Icons.send_rounded, size: 18),
                onPressed: _isAsking ? null : () => _sendQuestion(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // Tab 2: AI Cover Letter Generator
  // ----------------------------------------------------
  Widget _buildCoverLetterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Target Vacancy',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<JobModel>(
                    value: _selectedJob,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: _availableJobs.map((j) {
                      return DropdownMenuItem<JobModel>(
                        value: j,
                        child: Text(
                          '${j.title} (${j.employer?.organizationName ?? 'Employer'})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedJob = val;
                          _generatedCoverLetter = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Letter Tone',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildToneChip('Professional', 'professional'),
                      const SizedBox(width: 8),
                      _buildToneChip('Confident', 'confident'),
                      const SizedBox(width: 8),
                      _buildToneChip('Enthusiastic', 'enthusiastic'),
                    ],
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Personal Highlights or Key Achievements (Optional)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _coverLetterNotesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Led a team of 4 to deploy an automated payroll system...',
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D6B4F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isGeneratingLetter
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(
                        _isGeneratingLetter
                            ? 'Generating Letter...'
                            : 'Generate Customized Cover Letter',
                      ),
                      onPressed: _isGeneratingLetter
                          ? null
                          : _generateCoverLetter,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_generatedCoverLetter != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Generated Cover Letter Draft',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy to Clipboard'),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _generatedCoverLetter!),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cover letter copied to clipboard!'),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                _generatedCoverLetter!,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToneChip(String label, String value) {
    final isSelected = _selectedTone == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? Colors.white : Colors.black87,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF0D6B4F),
      onSelected: (val) {
        if (val) setState(() => _selectedTone = value);
      },
    );
  }

  // ----------------------------------------------------
  // Tab 3: Interview Simulator
  // ----------------------------------------------------
  Widget _buildInterviewPrepTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<JobModel>(
                  value: _selectedJob,
                  decoration: const InputDecoration(
                    labelText: 'Target Role for Mock Interview',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: _availableJobs.map((j) {
                    return DropdownMenuItem<JobModel>(
                      value: j,
                      child: Text(
                        j.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedJob = val);
                      _loadInterviewQuestions(val.id);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Refresh Practice Questions',
                icon: const Icon(Icons.refresh),
                onPressed: _selectedJob != null
                    ? () => _loadInterviewQuestions(_selectedJob!.id)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoadingQuestions)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_interviewQuestions.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const Icon(Icons.psychology, size: 54, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'Select a job above to practice tailored interview questions.',
                  ),
                  const SizedBox(height: 12),
                  if (_selectedJob != null)
                    ElevatedButton(
                      onPressed: () =>
                          _loadInterviewQuestions(_selectedJob!.id),
                      child: const Text('Generate Practice Questions'),
                    ),
                ],
              ),
            )
          else ...[
            ..._interviewQuestions.map((q) {
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0D6B4F).withOpacity(0.12),
                    child: const Icon(
                      Icons.question_answer_outlined,
                      color: Color(0xFF0D6B4F),
                      size: 18,
                    ),
                  ),
                  title: Text(
                    q['question'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    q['type'] ?? 'Interview Question',
                    style: const TextStyle(
                      color: Color(0xFF0D6B4F),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const Text(
                            'Model STAR Answer:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(
                              q['model_answer'] ?? '',
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lightbulb,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Coach Tip: ${q['eval_tip'] ?? ''}',
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 11.5,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // Tab 4: Skill-Gap Analysis
  // ----------------------------------------------------
  Widget _buildSkillGapTab() {
    final matched = (_skillGapAnalysis?['matched_skills'] as List?) ?? [];
    final missingReq =
        (_skillGapAnalysis?['missing_required_skills'] as List?) ?? [];
    final missingPref =
        (_skillGapAnalysis?['missing_preferred_skills'] as List?) ?? [];
    final courses = (_skillGapAnalysis?['recommended_courses'] as List?) ?? [];
    final score = _skillGapAnalysis?['match_score'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<JobModel>(
            value: _selectedJob,
            decoration: const InputDecoration(
              labelText: 'Analyze Skill-Gap for Vacancy',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _availableJobs.map((j) {
              return DropdownMenuItem<JobModel>(
                value: j,
                child: Text(
                  j.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedJob = val);
                _loadSkillGap(val.id);
              }
            },
          ),
          const SizedBox(height: 16),

          if (_isLoadingSkillGap)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_skillGapAnalysis == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.insights, size: 54, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text(
                      'Select a job above to analyze your skill match compatibility.',
                    ),
                    const SizedBox(height: 12),
                    if (_selectedJob != null)
                      ElevatedButton(
                        onPressed: () => _loadSkillGap(_selectedJob!.id),
                        child: const Text('Analyze Skill Gap'),
                      ),
                  ],
                ),
              ),
            )
          else ...[
            // Score Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF0D6B4F),
                    child: Text(
                      '$score%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _skillGapAnalysis?['job_title'] ?? 'Target Vacancy',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _skillGapAnalysis?['actionable_advice'] ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Matched Skills
            const Text(
              'Matched Skills (Verified)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (matched.isEmpty)
              Text(
                'No direct skill matches found in your profile.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: matched.map((s) {
                  return Chip(
                    avatar: const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Color(0xFF0D6B4F),
                    ),
                    label: Text(s['name'] ?? ''),
                    backgroundColor: const Color(0xFFDCFCE7),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),

            // Missing Required Skills
            const Text(
              'Missing Required Skills (Critical)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            if (missingReq.isEmpty)
              const Row(
                children: [
                  Icon(Icons.verified, color: Color(0xFF0D6B4F), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Great job! You meet all required skills.',
                    style: TextStyle(
                      color: Color(0xFF0D6B4F),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: missingReq.map((s) {
                  return Chip(
                    avatar: const Icon(
                      Icons.warning,
                      size: 16,
                      color: Colors.red,
                    ),
                    label: Text(s['name'] ?? ''),
                    backgroundColor: const Color(0xFFFEE2E2),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),

            // Missing Preferred Skills
            if (missingPref.isNotEmpty) ...[
              const Text(
                'Missing Preferred Skills (Bonus)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: missingPref.map((s) {
                  return Chip(
                    avatar: const Icon(
                      Icons.add,
                      size: 16,
                      color: Colors.orange,
                    ),
                    label: Text(s['name'] ?? ''),
                    backgroundColor: const Color(0xFFFEF3C7),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Recommended Courses & Roadmaps
            if (courses.isNotEmpty) ...[
              const Text(
                'Recommended Learning Roadmaps',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...courses.map((c) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE0F2FE),
                      child: Icon(Icons.school, color: Colors.blue, size: 18),
                    ),
                    title: Text(
                      c['course_title'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      '${c['platform']} • ${c['duration']}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }
}
