import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

/// Circular profile avatar that shows the user's photo (or initials) and,
/// when [editable] is true, lets the user pick/replace it from the gallery
/// or camera. Uploads the image as a base64 data URL and reports the new
/// photo URL via [onPhotoChanged].
class ProfileAvatar extends StatefulWidget {
  final String name;
  final String? photoUrl;
  final double radius;
  final bool editable;
  final ValueChanged<String?>? onPhotoChanged;
  final Color? backgroundColor;

  const ProfileAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 36,
    this.editable = false,
    this.onPhotoChanged,
    this.backgroundColor,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;

  String get _initial {
    final trimmed = widget.name.trim();
    return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
  }

  ImageProvider? _imageProvider() {
    final url = widget.photoUrl;
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        final base64Part = url.substring(url.indexOf(',') + 1);
        final Uint8List bytes = base64Decode(base64Part);
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
    if (url.startsWith('http')) return NetworkImage(url);
    return null;
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (picked == null) return;

      setState(() => _uploading = true);
      final bytes = await picked.readAsBytes();
      final ext = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      final dataUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';

      final profile = await _api.updateProfilePhoto(dataUrl);
      if (mounted) {
        widget.onPhotoChanged?.call(profile.photoUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removePhoto() async {
    try {
      setState(() => _uploading = true);
      final profile = await _api.updateProfilePhoto('');
      if (mounted) widget.onPhotoChanged?.call(profile.photoUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showOptions() {
    final hasPhoto = (widget.photoUrl ?? '').isNotEmpty;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.camera);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _removePhoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? Theme.of(context).colorScheme.primary;
    final image = _imageProvider();

    final avatar = CircleAvatar(
      radius: widget.radius,
      backgroundColor: bg.withValues(alpha: 0.15),
      backgroundImage: image,
      child: _uploading
          ? SizedBox(
              width: widget.radius * 0.6,
              height: widget.radius * 0.6,
              child: const SizedBox.shrink(),
            )
          : (image == null
              ? Text(
                  _initial,
                  style: TextStyle(
                    fontSize: widget.radius * 0.7,
                    fontWeight: FontWeight.bold,
                    color: bg,
                  ),
                )
              : null),
    );

    if (!widget.editable) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          bottom: -2,
          right: -2,
          child: GestureDetector(
            onTap: _uploading ? null : _showOptions,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
