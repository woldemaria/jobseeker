import 'package:flutter/material.dart';
import '../../models/job_model.dart';
import '../../data/ethiopian_job_titles_data.dart';
import 'match_score_badge.dart';
import 'location_map_modal.dart';
import 'share_with_friends_modal.dart';

class JobCard extends StatelessWidget {
  final JobModel job;
  final VoidCallback onTap;
  final VoidCallback? onSaveToggle;
  final VoidCallback? onMatchTap;

  const JobCard({
    super.key,
    required this.job,
    required this.onTap,
    this.onSaveToggle,
    this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D6B4F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.business, color: Color(0xFF0D6B4F)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          job.employer?.organizationName ?? 'Enterprise Employer',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onSaveToggle != null)
                        IconButton(
                          icon: Icon(
                            job.isSaved ? Icons.bookmark : Icons.bookmark_border,
                            color: job.isSaved ? const Color(0xFF0D6B4F) : const Color(0xFF94A3B8),
                          ),
                          onPressed: onSaveToggle,
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          tooltip: job.isSaved ? 'Unsave' : 'Save Job',
                        ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
                        tooltip: 'Job Options',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (val) {
                          if (val == 'save' && onSaveToggle != null) {
                            onSaveToggle!();
                          } else if (val == 'share') {
                            ShareWithFriendsModal.show(context, job);
                          } else if (val == 'map') {
                            LocationMapModal.show(
                              context,
                              title: job.title,
                              address: job.location,
                              organizationName: job.employer?.organizationName,
                            );
                          } else if (val == 'details') {
                            onTap();
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share, size: 18, color: Color(0xFF0D6B4F)),
                                SizedBox(width: 8),
                                Text('Share Vacancy'),
                              ],
                            ),
                          ),
                          if (onSaveToggle != null)
                            PopupMenuItem(
                              value: 'save',
                              child: Row(
                                children: [
                                  Icon(
                                    job.isSaved ? Icons.bookmark : Icons.bookmark_border,
                                    size: 18,
                                    color: const Color(0xFF0D6B4F),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(job.isSaved ? 'Remove Bookmark' : 'Bookmark Job'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'map',
                            child: Row(
                              children: [
                                Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF0D6B4F)),
                                SizedBox(width: 8),
                                Text('View on Map'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'details',
                            child: Row(
                              children: [
                                Icon(Icons.send_outlined, size: 18, color: Color(0xFF0D6B4F)),
                                SizedBox(width: 8),
                                Text('Apply Now / Details'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      LocationMapModal.show(
                        context,
                        title: job.title,
                        address: job.location,
                        organizationName: job.employer?.organizationName,
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF0D6B4F)),
                          const SizedBox(width: 4),
                          Text(
                            job.location,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0D6B4F),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.work_outline, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(job.employmentType, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Builder(
                    builder: (context) {
                      final catData = EthiopianJobCatalogue.findCategoryForTitle(job.title);
                      final categoryText = job.category ?? catData?.name;
                      if (categoryText == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(catData?.icon ?? Icons.category_outlined, size: 14, color: const Color(0xFF0D6B4F)),
                            const SizedBox(width: 3),
                            Text(
                              categoryText,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF0D6B4F), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (job.skills.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: job.skills.take(3).map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        skill.name,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      job.salaryText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D6B4F),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (job.matchScore != null) ...[
                        MatchScoreBadge(
                          score: job.matchScore!,
                          onTap: onMatchTap,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (job.hasApplied)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA5D6A7)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 14, color: Color(0xFF2E7D32)),
                              SizedBox(width: 4),
                              Text(
                                'Applied',
                                style: TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: onTap,
                          icon: const Icon(Icons.send_rounded, size: 13, color: Color(0xFF0D6B4F)),
                          label: const Text(
                            'Apply Now',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D6B4F),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            side: const BorderSide(color: Color(0xFF0D6B4F)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
