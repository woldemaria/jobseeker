import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class MatchDetailDialog extends StatelessWidget {
  final String jobTitle;
  final Map<String, dynamic> matchAnalysis;

  const MatchDetailDialog({
    super.key,
    required this.jobTitle,
    required this.matchAnalysis,
  });

  static void show(BuildContext context, String jobTitle, Map<String, dynamic> matchAnalysis) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => MatchDetailDialog(
        jobTitle: jobTitle,
        matchAnalysis: matchAnalysis,
      ),
    );
  }

  Widget _buildCriterionBar(String title, String weight, double score, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$title ($weight)',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(
                '${score.toStringAsFixed(0)}%',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (score / 100.0).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final totalScore = double.tryParse(matchAnalysis['match_score'].toString()) ?? 0.0;
    final breakdown = matchAnalysis['breakdown'] as Map<String, dynamic>? ?? {};
    final explanation = matchAnalysis['explanation']?.toString() ?? '';

    final skillsData = breakdown['skills'] as Map<String, dynamic>? ?? {};
    final eduData = breakdown['education'] as Map<String, dynamic>? ?? {};
    final expData = breakdown['experience'] as Map<String, dynamic>? ?? {};
    final locData = breakdown['location'] as Map<String, dynamic>? ?? {};

    final matchingSkills = (skillsData['matching_skills'] as List?) ?? [];
    final missingPref = (skillsData['missing_preferred_skills'] as List?) ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.t('skills_match'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          jobTitle,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D6B4F).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${totalScore.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D6B4F),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Formula Weights Baseline:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _buildCriterionBar(
                loc.t('skills_match'),
                '40%',
                double.tryParse(skillsData['score']?.toString() ?? '0') ?? 0.0,
                const Color(0xFF0D6B4F),
              ),
              _buildCriterionBar(
                loc.t('education'),
                '20%',
                double.tryParse(eduData['score']?.toString() ?? '0') ?? 0.0,
                const Color(0xFF2563EB),
              ),
              _buildCriterionBar(
                loc.t('experience'),
                '15%',
                double.tryParse(expData['score']?.toString() ?? '0') ?? 0.0,
                const Color(0xFFD97706),
              ),
              _buildCriterionBar(
                loc.t('location'),
                '10%',
                double.tryParse(locData['score']?.toString() ?? '0') ?? 0.0,
                const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 16),
              if (matchingSkills.isNotEmpty) ...[
                Text(
                  loc.t('matching_skills'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: matchingSkills.map((s) => Chip(
                    backgroundColor: const Color(0xFFDCFCE7),
                    label: Text(s.toString(), style: const TextStyle(color: Color(0xFF166534), fontSize: 12)),
                  )).toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (missingPref.isNotEmpty) ...[
                Text(
                  loc.t('missing_skills'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: missingPref.map((s) => Chip(
                    backgroundColor: const Color(0xFFFEF3C7),
                    label: Text(s.toString(), style: const TextStyle(color: Color(0xFF92400E), fontSize: 12)),
                  )).toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (explanation.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recommendation Summary:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        explanation,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
