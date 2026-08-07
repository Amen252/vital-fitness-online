import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/dashboard/widgets/coach_home/coach_dashboard_theme.dart';

List<Map<String, dynamic>> normalizeCertificateFiles(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .where((e) => (e['url']?.toString() ?? '').trim().isNotEmpty)
      .toList();
}

bool _isPdf(Map<String, dynamic> file) {
  final mime = (file['mimeType']?.toString() ?? '').toLowerCase();
  final url = (file['url']?.toString() ?? '').toLowerCase();
  return mime.contains('pdf') || url.endsWith('.pdf');
}

/// Image / PDF gallery for uploaded coach certificates.
class CertificateFilesGallery extends StatelessWidget {
  final List<Map<String, dynamic>> files;
  final String title;
  final String emptyLabel;
  final bool showEmpty;

  const CertificateFilesGallery({
    super.key,
    required this.files,
    this.title = 'Certificate files',
    this.emptyLabel = 'No certificate files uploaded.',
    this.showEmpty = true,
  });

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open certificate file')),
      );
    }
  }

  void _previewImage(BuildContext context, String url, String name) {
    showDialog(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            width: size.width,
            height: size.height * 0.75,
            child: Column(
              children: [
                AppBar(
                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _open(context, url),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Expanded(
                  child: InteractiveViewer(
                    child: Center(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Unable to load image'),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (files.isEmpty) {
      if (!showEmpty) return const SizedBox.shrink();
      return Text(
        emptyLabel,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: CoachDashboardTheme.sectionLabel(isDark)),
        const SizedBox(height: 8),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: files.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final file = files[index];
              final url = file['url']?.toString() ?? '';
              final name = (file['fileName']?.toString().trim().isNotEmpty == true)
                  ? file['fileName'].toString()
                  : 'Certificate ${index + 1}';
              final pdf = _isPdf(file);
              return InkWell(
                onTap: () {
                  if (pdf) {
                    _open(context, url);
                  } else {
                    _previewImage(context, url, name);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 112,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB),
                    ),
                    color: isDark ? const Color(0xFF0F1117) : const Color(0xFFF9FAFB),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: pdf
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.picture_as_pdf, color: CoachDashboardTheme.danger),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Open',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: CoachDashboardTheme.primary,
                              ),
                            ),
                          ],
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          width: 112,
                          height: 104,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a file to preview or open',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : CoachDashboardTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
