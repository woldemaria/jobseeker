import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/application_model.dart';
import '../../repositories/application_repository.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../core/constants/api_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/status_badge.dart';
import 'job_offer_modal.dart';

class ApplicationDetailScreen extends StatefulWidget {
  final int applicationId;
  final ApplicationRepository appRepo;

  const ApplicationDetailScreen({
    super.key,
    required this.applicationId,
    required this.appRepo,
  });

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  ApplicationModel? _application;
  bool _isLoading = true;
  bool _isWithdrawing = false;
  bool _isConfirmingInterview = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final app = await widget.appRepo.getApplicationDetails(
        widget.applicationId,
      );
      if (mounted) {
        setState(() {
          _application = app;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _withdraw() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Application'),
        content: const Text(
          'Are you sure you want to withdraw this job application? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isWithdrawing = true);
    final resp = await widget.appRepo.withdrawApplication(widget.applicationId);
    if (mounted) {
      setState(() => _isWithdrawing = false);
      if (resp.success) {
        _load();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Application withdrawn.')));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(resp.message)));
      }
    }
  }

  Future<void> _confirmInterview() async {
    setState(() => _isConfirmingInterview = true);
    final resp = await widget.appRepo.confirmInterview(widget.applicationId);
    if (mounted) {
      setState(() => _isConfirmingInterview = false);
      if (resp.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Interview attendance confirmed! The employer has been notified.',
            ),
            backgroundColor: Color(0xFF0D6B4F),
          ),
        );
        _load();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(resp.message)));
      }
    }
  }

  Future<void> _viewCvDocument(int docId, String docName) async {
    final storage = Provider.of<StorageService>(context, listen: false);
    final token = storage.getToken();
    final url = Uri.parse(
      '${ApiConstants.baseUrl}/documents/$docId/view?token=$token&inline=1',
    );

    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open document "$docName": $e')),
        );
      }
    }
  }

  void _showRescheduleDialog() {
    final reasonController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 3));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit_calendar, color: Color(0xFF0D6B4F)),
              SizedBox(width: 8),
              Text('Request Reschedule', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Propose a preferred interview date and time to the recruitment team:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF0D6B4F),
                  ),
                  title: Text(
                    'Date: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (d != null) {
                      setDialogState(() => selectedDate = d);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.access_time,
                    color: Color(0xFF0D6B4F),
                  ),
                  title: Text('Time: ${selectedTime.format(context)}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (t != null) {
                      setDialogState(() => selectedTime = t);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason / Message to Employer',
                    hintText: 'e.g. Schedule conflict with existing exams...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      final formattedDate =
                          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')} ${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00";

                      final resp = await widget.appRepo.rescheduleInterview(
                        applicationId: widget.applicationId,
                        interviewAt: formattedDate,
                        reason: reasonController.text.trim(),
                      );

                      if (mounted) {
                        Navigator.pop(dialogCtx);
                        if (resp.success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Reschedule request sent to employer.',
                              ),
                              backgroundColor: Color(0xFF0D6B4F),
                            ),
                          );
                          _load();
                        } else {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(resp.message)));
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmployerScheduleDialog() {
    final locationController = TextEditingController(
      text: 'Google Meet / Online',
    );
    final notesController = TextEditingController();
    String selectedType = 'video';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 2));
    TimeOfDay selectedTime = const TimeOfDay(hour: 14, minute: 0);
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.calendar_month, color: Color(0xFF0D6B4F)),
              SizedBox(width: 8),
              Text('Schedule Interview', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Interview Mode',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'video',
                      child: Text('Video Conference (Online)'),
                    ),
                    DropdownMenuItem(
                      value: 'in_person',
                      child: Text('In-Person Office Interview'),
                    ),
                    DropdownMenuItem(
                      value: 'phone',
                      child: Text('Phone Screening'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedType = val;
                        if (val == 'video') {
                          locationController.text = 'Google Meet: https://meet.google.com/job-interview';
                        } else if (val == 'in_person') {
                          locationController.text =
                              _application?.job?.location ??
                              'Head Office, Addis Ababa';
                        } else {
                          locationController.text = 'Direct Phone Call';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF0D6B4F),
                  ),
                  title: Text(
                    'Date: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (d != null) setDialogState(() => selectedDate = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.access_time,
                    color: Color(0xFF0D6B4F),
                  ),
                  title: Text('Time: ${selectedTime.format(context)}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (t != null) setDialogState(() => selectedTime = t);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Location or Video Link',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Candidate Preparation Instructions',
                    hintText:
                        'e.g. Please bring portfolio and identification ID...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      final formattedDate =
                          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')} ${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00";

                      final resp = await widget.appRepo.scheduleInterview(
                        applicationId: widget.applicationId,
                        interviewAt: formattedDate,
                        interviewType: selectedType,
                        interviewLocation: locationController.text.trim(),
                        interviewNotes: notesController.text.trim(),
                      );

                      if (mounted) {
                        Navigator.pop(dialogCtx);
                        if (resp.success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Interview invitation scheduled and sent!',
                              ),
                              backgroundColor: Color(0xFF0D6B4F),
                            ),
                          );
                          _load();
                        } else {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(resp.message)));
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirm Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecruitmentStepper(String status) {
    final stages = [
      {'key': 'submitted', 'label': 'Submitted'},
      {'key': 'under_review', 'label': 'Reviewing'},
      {'key': 'shortlisted', 'label': 'Shortlisted'},
      {'key': 'interview', 'label': 'Interview'},
      {'key': 'accepted', 'label': 'Offer / Accepted'},
    ];

    int currentIndex = 0;
    final lowerStatus = status.toLowerCase();
    if (lowerStatus == 'under_review') currentIndex = 1;
    if (lowerStatus == 'shortlisted') currentIndex = 2;
    if (lowerStatus == 'interview') currentIndex = 3;
    if (lowerStatus == 'accepted' || lowerStatus == 'offered') currentIndex = 4;
    final isRejected = lowerStatus == 'rejected';
    final isWithdrawn = lowerStatus == 'withdrawn';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recruitment Progression',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF334155),
                ),
              ),
              if (isRejected)
                const StatusBadge(status: 'rejected')
              else if (isWithdrawn)
                const StatusBadge(status: 'withdrawn'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(stages.length, (index) {
              final isPassed =
                  index <= currentIndex && !isRejected && !isWithdrawn;
              final isCurrent =
                  index == currentIndex && !isRejected && !isWithdrawn;

              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 3,
                            color: index == 0
                                ? Colors.transparent
                                : (index <= currentIndex
                                      ? const Color(0xFF0D6B4F)
                                      : Colors.grey.shade300),
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isPassed
                                ? const Color(0xFF0D6B4F)
                                : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isPassed
                                  ? const Color(0xFF0D6B4F)
                                  : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: isPassed
                                ? const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 3,
                            color: index == stages.length - 1
                                ? Colors.transparent
                                : (index < currentIndex
                                      ? const Color(0xFF0D6B4F)
                                      : Colors.grey.shade300),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stages[index]['label']!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCurrent
                            ? const Color(0xFF0D6B4F)
                            : const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildInterviewBookingCard(ApplicationModel app, bool isEmployer) {
    final hasBooking = app.interviewAt != null || app.status == 'interview';
    if (!hasBooking && !isEmployer) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(top: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF0D6B4F), width: 1.5),
      ),
      color: const Color(0xFFF0FDF4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D6B4F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_month,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Interview Booking & Appointment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF0F5132),
                        ),
                      ),
                      Text(
                        app.interviewStatus != null
                            ? 'Status: ${app.interviewStatus!.toUpperCase()}'
                            : 'Interview Scheduled',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isEmployer)
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      color: Color(0xFF0D6B4F),
                      size: 18,
                    ),
                    tooltip: 'Edit Schedule',
                    onPressed: _showEmployerScheduleDialog,
                  ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFBBF7D0)),

            if (app.interviewAt != null) ...[
              Row(
                children: [
                  const Icon(
                    Icons.access_time_filled,
                    size: 18,
                    color: Color(0xFF0D6B4F),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Time: ${app.interviewAt!.replaceFirst('T', ' ').split('.').first}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.videocam_outlined,
                    size: 18,
                    color: Color(0xFF0D6B4F),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Type: ${(app.interviewType ?? "Video Conference").toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (app.interviewLocation != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: Color(0xFF0D6B4F),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Location: ${app.interviewLocation!}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        size: 16,
                        color: Color(0xFF0D6B4F),
                      ),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      tooltip: 'Copy Meeting Link/Address',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: app.interviewLocation!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Interview location copied to clipboard!',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              if (app.interviewNotes != null &&
                  app.interviewNotes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color(0xFF0D6B4F),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Instructions: ${app.interviewNotes!}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Candidate confirmation / reschedule action buttons
              if (!isEmployer) ...[
                Row(
                  children: [
                    if (app.interviewStatus != 'confirmed')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isConfirmingInterview
                              ? null
                              : _confirmInterview,
                          icon: _isConfirmingInterview
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                ),
                          label: const Text('Confirm Attendance'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D6B4F),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D6B4F),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Attendance Confirmed',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _showRescheduleDialog,
                      icon: const Icon(
                        Icons.schedule,
                        size: 16,
                        color: Color(0xFF0D6B4F),
                      ),
                      label: const Text(
                        'Reschedule',
                        style: TextStyle(color: Color(0xFF0D6B4F)),
                      ),
                    ),
                  ],
                ),
              ],
            ] else if (isEmployer) ...[
              const Text(
                'Applicant has reached interview stage. Schedule an appointment slot for the candidate:',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _showEmployerScheduleDialog,
                icon: const Icon(Icons.add_alarm, size: 16),
                label: const Text('Schedule Interview Booking'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJobOfferBanner() {
    if (_application == null) return const SizedBox.shrink();
    final isOffered = _application!.status == 'offered';
    final isAccepted = _application!.status == 'accepted';

    if (!isOffered && !isAccepted) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.verified,
                  color: Color(0xFF0D6B4F),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOffered
                          ? '🎉 Official Job Offer Received!'
                          : '🤝 Job Offer Accepted!',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF0D6B4F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOffered
                          ? 'The employer has extended a formal employment offer. Please review salary, benefits, and conditions.'
                          : 'You have formally accepted this offer. Review details and prepare for onboarding.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                JobOfferModal.show(
                  context,
                  applicationId: widget.applicationId,
                  onOfferUpdated: _load,
                );
              },
              icon: const Icon(Icons.assignment_turned_in, size: 18),
              label: Text(
                isOffered
                    ? 'Review & Respond to Job Offer'
                    : 'View Formal Offer Contract',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6B4F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final auth = Provider.of<AuthService>(context, listen: false);
    final isEmployer =
        auth.currentUser?.isEmployer == true ||
        auth.currentUser?.isAdmin == true;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.t('applications'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_application == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.t('applications'))),
        body: const Center(child: Text('Application not found.')),
      );
    }

    final canWithdraw =
        !isEmployer &&
        _application!.status != 'withdrawn' &&
        _application!.status != 'rejected' &&
        _application!.status != 'accepted';

    return Scaffold(
      appBar: AppBar(
        title: Text(_application!.job?.title ?? loc.t('applications')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Application Top Card
          Card(
            margin: EdgeInsets.zero,
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _application!.job?.title ?? 'Vacancy',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      StatusBadge(status: _application!.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _application!.job?.employer?.organizationName ??
                        'Enterprise Employer',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Applied Date: ${_application!.appliedAt.split('T').first}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                        ),
                      ),
                      Text(
                        'Type: ${_application!.job?.employmentType ?? "Full-time"}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (_application!.cvDocument != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _viewCvDocument(
                        _application!.cvDocument!.id,
                        _application!.cvDocument!.originalName,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.picture_as_pdf,
                              size: 20,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Attached CV: ${_application!.cvDocument!.originalName}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${_application!.cvDocument!.formattedSize} • Tap to view/download',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.open_in_new,
                              size: 16,
                              color: Color(0xFF0D6B4F),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Stepper
          _buildRecruitmentStepper(_application!.status),

          // Formal Job Offer Management Card
          _buildJobOfferBanner(),

          // Interview Booking Card
          _buildInterviewBookingCard(_application!, isEmployer),

          if (_application!.coverLetter != null &&
              _application!.coverLetter!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              loc.t('cover_letter'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _application!.coverLetter!,
                  style: const TextStyle(height: 1.4, fontSize: 13),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          Text(
            loc.t('status_history'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_application!.statusHistories.isEmpty)
            const Text(
              'No status history recorded yet.',
              style: TextStyle(color: Color(0xFF64748B)),
            )
          else
            ..._application!.statusHistories.map((h) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.history,
                        size: 18,
                        color: Color(0xFF0D6B4F),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                StatusBadge(status: h.newStatus),
                                Text(
                                  h.createdAt.split('T').first,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            if (h.notes != null && h.notes!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                h.notes!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 24),
          if (canWithdraw)
            OutlinedButton.icon(
              onPressed: _isWithdrawing ? null : _withdraw,
              icon: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626)),
              label: Text(
                loc.t('withdraw'),
                style: const TextStyle(color: Color(0xFFDC2626)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDC2626)),
              ),
            ),
        ],
      ),
    );
  }
}
