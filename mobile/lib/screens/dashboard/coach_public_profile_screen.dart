import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/scrollable_body.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/certificate_files_gallery.dart';
import 'widgets/coach_home/coach_dashboard_theme.dart';
import '../../widgets/coach_appointment_days_display.dart';
import '../../widgets/coach_working_days_display.dart';

class CoachPublicProfileScreen extends StatefulWidget {
  final String coachId;
  final String coachName;
  final bool canRequest;
  final ValueChanged<Map<String, dynamic>>? onRequestSubmitted;

  const CoachPublicProfileScreen({
    super.key,
    required this.coachId,
    required this.coachName,
    this.canRequest = true,
    this.onRequestSubmitted,
  });

  @override
  State<CoachPublicProfileScreen> createState() => _CoachPublicProfileScreenState();
}

class _CoachPublicProfileScreenState extends State<CoachPublicProfileScreen> {
  final ApiService _apiService = ApiService();
  final _messageController = TextEditingController();
  Map<String, dynamic>? _coach;
  Map<String, dynamic>? _reviewsData;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  double get _averageRating =>
      (_coach?['averageRating'] as num?)?.toDouble() ??
      (_reviewsData?['averageRating'] as num?)?.toDouble() ??
      0;
  int get _numReviews =>
      (_coach?['numReviews'] as int?) ?? (_reviewsData?['numReviews'] as int?) ?? 0;
  List<dynamic> get _reviews => (_reviewsData?['reviews'] as List<dynamic>?) ?? [];
  Map<String, dynamic>? get _myReview =>
      _reviewsData?['myReview'] as Map<String, dynamic>?;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final coach = await _apiService.getPublicCoach(widget.coachId);
      final reviews = await _apiService
          .getCoachReviews(widget.coachId)
          .catchError((_) => <String, dynamic>{});
      if (mounted) {
        setState(() {
          _coach = coach;
          _reviewsData = reviews;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitRequest() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final created = await _apiService.submitCoachRequest(
        coachId: widget.coachId,
        message: _messageController.text.trim(),
      );
      if (!mounted) return;
      widget.onRequestSubmitted?.call(created);
      Navigator.pop(context, created);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coach request sent!'),
          backgroundColor: CoachDashboardTheme.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showRequestDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF181B24) : Colors.white;
    final muted = isDark ? Colors.white60 : CoachDashboardTheme.textSecondary;
    final border = isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB);
    final initials = widget.coachName.trim().isNotEmpty
        ? widget.coachName.trim()[0].toUpperCase()
        : 'C';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 18),
                decoration: const BoxDecoration(
                  gradient: CoachDashboardTheme.headerGradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        initials,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Coaching Request',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.coachName,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Introduce yourself and share your fitness goals. Your coach will review this before accepting.',
                      style: TextStyle(fontSize: 13.5, height: 1.45, color: muted),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Personal message',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : CoachDashboardTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      maxLines: 4,
                      maxLength: 400,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Example: I want to lose weight and build consistency 3 days a week…',
                        hintStyle: TextStyle(color: muted.withValues(alpha: 0.8), fontSize: 13),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF9FAFB),
                        counterStyle: TextStyle(fontSize: 11, color: muted),
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: border),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: CoachDashboardTheme.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : CoachDashboardTheme.textSecondary,
                          side: BorderSide(color: border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _submitRequest();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CoachDashboardTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(_isSubmitting ? 'Sending…' : 'Send Request', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _starRow(double rating, {double size = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icon;
        if (rating >= i + 1) {
          icon = Icons.star_rounded;
        } else if (rating >= i + 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, size: size, color: const Color(0xFFFFB400));
      }),
    );
  }

  Future<void> _showRateDialog() async {
    int rating = (_myReview?['rating'] as int?) ?? 5;
    final commentController =
        TextEditingController(text: _myReview?['comment']?.toString() ?? '');

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(_myReview != null ? 'Edit your review' : 'Rate ${widget.coachName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFFFB400),
                      size: 36,
                    ),
                    onPressed: () => setLocal(() => rating = i + 1),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  hintText: 'Share your experience...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (submitted == true) {
      try {
        await _apiService.submitCoachReview(
          coachId: widget.coachId,
          rating: rating,
          comment: commentController.text.trim(),
        );
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thanks for your review!'), backgroundColor: CoachDashboardTheme.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: CoachDashboardTheme.danger),
          );
        }
      }
    }
    commentController.dispose();
  }

  Widget _buildReviewsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Reviews', style: CoachDashboardTheme.sectionLabel(isDark)),
            const Spacer(),
            if (!widget.canRequest)
              TextButton.icon(
                onPressed: _showRateDialog,
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: Text(_myReview != null ? 'Edit review' : 'Rate coach'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_reviews.isEmpty)
          Text(
            'No reviews yet.',
            style: TextStyle(color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
          )
        else
          ..._reviews.map((raw) {
            final r = Map<String, dynamic>.from(raw as Map);
            final clientName = r['client']?['name']?.toString() ?? 'Member';
            final rating = (r['rating'] as num?)?.toDouble() ?? 0;
            final comment = r['comment']?.toString() ?? '';
            final date = DateTime.tryParse(r['updatedAt']?.toString() ?? '');
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: CoachDashboardTheme.cardDecoration(isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(clientName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      _starRow(rating, size: 16),
                    ],
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(comment, style: const TextStyle(fontSize: 14, height: 1.4)),
                  ],
                  if (date != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      DateFormat.yMMMd().format(date.toLocal()),
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : CoachDashboardTheme.textSecondary),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = _coach?['profile'] as Map<String, dynamic>? ?? {};
    final specs = profile['specialization'] as List<dynamic>? ?? [];
    final workingDays = CoachWorkingDaysDisplay.parseDays(profile['workingDays']);
    final appointmentDays = CoachAppointmentDaysDisplay.daysFromProfile(profile);
    final name = _coach?['name'] as String? ?? widget.coachName;

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      appBar: AppBar(
        title: const Text('Coach Profile'),
        backgroundColor: CoachDashboardTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CoachDashboardTheme.primary))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: CoachDashboardTheme.danger)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: dashboardScrollPhysics,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  ProfileAvatar(
                                    name: name,
                                    photoUrl: profile['photoUrl'] as String?,
                                    radius: 40,
                                    backgroundColor: CoachDashboardTheme.primary,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.verified_rounded, color: Color(0xFF00D4AA), size: 18),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _starRow(_averageRating),
                                      const SizedBox(width: 8),
                                      Text(
                                        _numReviews == 0
                                            ? 'No ratings yet'
                                            : '${_averageRating.toStringAsFixed(1)} ($_numReviews)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? Colors.white60 : CoachDashboardTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (profile['yearsExperience'] != null)
                                    Text(
                                      '${profile['yearsExperience']} years experience',
                                      style: TextStyle(color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
                                    ),
                                  if ((profile['location'] as String?)?.trim().isNotEmpty == true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        profile['location'] as String,
                                        style: TextStyle(color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
                                      ),
                                    ),
                                  if ((profile['phone'] as String?)?.trim().isNotEmpty == true ||
                                      (_coach?['phone'] as String?)?.trim().isNotEmpty == true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        (profile['phone'] as String?)?.trim().isNotEmpty == true
                                            ? profile['phone'] as String
                                            : _coach!['phone'] as String,
                                        style: TextStyle(color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (workingDays.isNotEmpty) ...[
                              CoachWorkingDaysDisplay(
                                workingDays: workingDays,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (appointmentDays.isNotEmpty) ...[
                              CoachAppointmentDaysDisplay(
                                appointmentDays: appointmentDays,
                                dayAvailability: profile['dayAvailability'] as List?,
                                appointmentDurationMinutes: profile['appointmentDurationMinutes'] as int?,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (specs.isNotEmpty) ...[
                              Text('Specializations', style: CoachDashboardTheme.sectionLabel(isDark)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: specs
                                    .map(
                                      (s) => Chip(
                                        label: Text(s.toString()),
                                        backgroundColor: CoachDashboardTheme.primary.withValues(alpha: 0.1),
                                        labelStyle: const TextStyle(color: CoachDashboardTheme.primary),
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 20),
                            ],
                            if ((profile['certifications'] as String?)?.isNotEmpty == true) ...[
                              Text('Certifications', style: CoachDashboardTheme.sectionLabel(isDark)),
                              const SizedBox(height: 8),
                              Text(profile['certifications'] as String, style: const TextStyle(fontSize: 14, height: 1.5)),
                              const SizedBox(height: 20),
                            ],
                            CertificateFilesGallery(
                              files: normalizeCertificateFiles(profile['certificateFiles']),
                              emptyLabel: 'No certificate files available for this coach.',
                            ),
                            const SizedBox(height: 20),
                            if ((profile['bio'] as String?)?.isNotEmpty == true) ...[
                              Text('About', style: CoachDashboardTheme.sectionLabel(isDark)),
                              const SizedBox(height: 8),
                              Text(profile['bio'] as String, style: const TextStyle(fontSize: 14, height: 1.5)),
                              const SizedBox(height: 20),
                            ],
                            if ((profile['experience'] as String?)?.isNotEmpty == true) ...[
                              Text('Experience', style: CoachDashboardTheme.sectionLabel(isDark)),
                              const SizedBox(height: 8),
                              Text(profile['experience'] as String, style: const TextStyle(fontSize: 14, height: 1.5)),
                              const SizedBox(height: 20),
                            ],
                            _buildReviewsSection(isDark),
                          ],
                        ),
                      ),
                    ),
                    if (widget.canRequest)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: CoachDashboardTheme.primaryButtonStyle(),
                              onPressed: _isSubmitting ? null : _showRequestDialog,
                              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                              label: const Text('Request This Coach'),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
