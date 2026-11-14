import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../icons/app_icon.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'form.dart';
import 'widgets.dart';
import 'toast.dart';

/// A file chosen on the phone, not yet uploaded.
class PickedFile {
  const PickedFile(this.path, this.name);

  final String path;
  final String name;

  bool get isPdf => name.toLowerCase().endsWith('.pdf');
}

/// Asks where the file comes from (camera, photos, or files when [allowPdf])
/// and returns it. Null when dismissed or the source isn't available.
Future<PickedFile?> pickFile(BuildContext context, {bool allowPdf = true, bool cameraFirst = true}) async {
  final source = await showChoiceSheet<String>(
    context,
    title: 'Add a file',
    options: [('camera', 'Take a photo'), ('photos', 'Choose from photos'), if (allowPdf) ('files', 'Choose a PDF')],
  );
  if (source == null) return null;
  try {
    if (source == 'files') {
      final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      final f = res.firstOrNull;
      if (f?.path == null) return null;
      return PickedFile(f!.path!, f.name);
    }
    final x = await ImagePicker().pickImage(
      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 82,
    );
    return x == null ? null : PickedFile(x.path, x.name);
  } catch (_) {
    if (context.mounted) {
      showToast(
        context,
        source == 'camera' ? "Couldn't open the camera. Choose a photo instead." : "Couldn't open that.",
        kind: ToastKind.error,
      );
    }
    return null;
  }
}

/// Uploads [file] for later reference and returns its `upl_` id.
Future<String> uploadFile(ApiClient api, PickedFile file, String purpose) async {
  final res = await api.upload<Map<String, dynamic>>('/uploads', filePath: file.path, fields: {'purpose': purpose});
  return '${res.data['id']}';
}

/// A slot for one file: empty with an "Add" button, or the chosen file with
/// a thumbnail (or a PDF tile) and a way to replace it. [existingUrl] shows
/// a file already on the server.
class FileSlot extends StatelessWidget {
  const FileSlot({
    super.key,
    required this.label,
    required this.file,
    required this.onPick,
    this.existingUrl,
    this.existingLabel,
    this.allowPdf = true,
    this.errorText,
    this.hint,
    this.locked = false,
  });

  final String label;
  final PickedFile? file;
  final ValueChanged<PickedFile> onPick;
  final String? existingUrl;
  final String? existingLabel;
  final bool allowPdf;
  final String? errorText;
  final String? hint;

  /// Approved and can't be replaced.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final f = file;
    final has = f != null || existingUrl != null || existingLabel != null;
    Widget preview;
    if (f != null && !f.isPdf) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(Radii.tile),
        child: Image.file(File(f.path), width: 56, height: 56, fit: BoxFit.cover),
      );
    } else if (existingUrl != null && f == null && !existingUrl!.toLowerCase().contains('.pdf')) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(Radii.tile),
        child: Image.network(
          existingUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => IconTile(AppIcons.doc, size: 56, color: c.accent, background: c.accentTint),
        ),
      );
    } else {
      preview = IconTile(has ? AppIcons.doc : AppIcons.upload, size: 56, color: c.accent, background: c.accentTint);
    }
    final subtitle = f != null
        ? f.name
        : locked
        ? 'Approved'
        : has
        ? (existingLabel ?? 'Uploaded · tap to replace')
        : (hint ?? (allowPdf ? 'Photo or PDF' : 'Photo'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: locked
              ? null
              : () async {
                  final picked = await pickFile(context, allowPdf: allowPdf);
                  if (picked != null) onPick(picked);
                },
          child: Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: context.fieldFill,
              borderRadius: BorderRadius.circular(Radii.field),
              border: errorText != null ? Border.all(color: c.danger, width: 1.5) : null,
            ),
            child: Row(
              children: [
                preview,
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: context.text.body, maxLines: 2),
                      Text(
                        subtitle,
                        style: context.text.label.copyWith(color: locked ? c.success : null),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!locked)
                  Text(
                    has ? 'Replace' : 'Add',
                    style: context.text.label.copyWith(color: c.accent, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: Space.xs),
          Text(errorText!, style: context.text.label.copyWith(color: c.danger)),
        ],
      ],
    );
  }
}
