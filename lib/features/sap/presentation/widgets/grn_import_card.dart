import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/grn_upload_state.dart';
import '../../domain/services/grn_template_service.dart';
import '../controllers/grn_upload_provider.dart';

/// Material 3 card for importing GRN CSV/XLSX data.
/// Uploading always triggers full reconciliation automatically on the backend.
class GrnImportCard extends ConsumerStatefulWidget {
  const GrnImportCard({super.key});

  @override
  ConsumerState<GrnImportCard> createState() => _GrnImportCardState();
}

class _GrnImportCardState extends ConsumerState<GrnImportCard> {
  ProviderSubscription<GrnUploadState>? _uploadSubscription;
  bool _isDownloadingTemplate = false;

  Future<void> _downloadTemplate() async {
    if (_isDownloadingTemplate) return;
    setState(() => _isDownloadingTemplate = true);
    try {
      await downloadGrnTemplate();
      if (!mounted) return;
      _showSnackbar(
        context,
        'Template downloaded. Fill it in and upload it here.',
        Theme.of(context).colorScheme.primaryContainer,
        Theme.of(context).colorScheme.onPrimaryContainer,
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackbar(
        context,
        'Could not create the template: $error',
        Theme.of(context).colorScheme.errorContainer,
        Theme.of(context).colorScheme.onErrorContainer,
      );
    } finally {
      if (mounted) setState(() => _isDownloadingTemplate = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _uploadSubscription = ref.listenManual<GrnUploadState>(
      grnUploadProvider,
      (previous, next) {
        if (!mounted) return;

        if (next is GrnUploadSuccess) {
          _showSnackbar(
            context,
            next.message,
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.onPrimaryContainer,
          );
          Future.microtask(
            () => ref.read(grnUploadProvider.notifier).reset(),
          );
        } else if (next is GrnUploadError) {
          _showSnackbar(
            context,
            next.message,
            Theme.of(context).colorScheme.errorContainer,
            Theme.of(context).colorScheme.onErrorContainer,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _uploadSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const allowedFileLabel = 'CSV/XLSX';

    final uploadState = ref.watch(grnUploadProvider);
    final notifier = ref.read(grnUploadProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isLoading = uploadState is GrnUploadLoading;
    final selectedFile = switch (uploadState) {
      GrnUploadFileSelected(:final file) => file,
      GrnUploadLoading(:final file) => file,
      _ => null,
    };
    final hasFile = selectedFile != null;
    final canUpload = hasFile && !isLoading;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      color: colorScheme.primaryContainer.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.cloud_upload_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import GRN Data',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        kIsWeb
                            ? 'Upload a CSV or XLSX file exported from SAP. Reconciliation starts in the background.'
                            : 'Upload a CSV or XLSX file exported from SAP. Reconciliation starts in the background.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Actions ──────────────────────────────────────────────────────
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      (isLoading || _isDownloadingTemplate) ? null : _downloadTemplate,
                  icon: _isDownloadingTemplate
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(_isDownloadingTemplate
                      ? 'Preparing...'
                      : 'Download Template'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : notifier.pickFile,
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Choose $allowedFileLabel File'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                if (hasFile)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          colorScheme.secondaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.insert_drive_file_rounded,
                          size: 16,
                          color: colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(
                            selectedFile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                FilledButton.icon(
                  onPressed: canUpload ? notifier.upload : null,
                  icon: isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.upload_rounded, size: 18),
                  label: Text(isLoading ? 'Uploading...' : 'Upload GRNs'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Text(
              'Required columns: ${grnTemplateRequiredHeaders.join(', ')} '
              '(quantity must be more than 0). Fill challanNo wherever you have '
              'it — that is what matches a GRN to its gate entry; without it the '
              'row shows as Pending Gate Entry. Dates can be a normal Excel date '
              'cell or DD/MM/YYYY. Extra SAP columns are kept if present.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            // ── Progress ──────────────────────────────────────────────────────
            if (isLoading) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                kIsWeb
                    ? 'Uploading GRNs. Reconciliation will continue in the background...'
                    : 'Uploading file. Reconciliation will continue in the background...',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSnackbar(
    BuildContext context,
    String message,
    Color background,
    Color foreground,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
  }
}
