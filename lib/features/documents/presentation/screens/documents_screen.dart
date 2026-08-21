/// The Documents screen for Zephyr.
///
/// Displays a list of indexed documents with their status, allows
/// importing new files via file picker, and shows indexing progress.
/// Supports pull-to-refresh and swipe-to-delete actions.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../../../core/models/document_model.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../theme/zephyr_theme.dart';
import '../viewmodels/documents_viewmodel.dart';
import '../widgets/document_card.dart';
import '../../data/models/import_source.dart';

/// Navigates to the documents screen.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _refreshController = RefreshController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentsViewModel>().init();
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  /// Opens the file type selection bottom sheet.
  Future<void> _showImportSourceSheet() async {
    final source = await showModalBottomSheet<ImportSource>(
      context: context,
      backgroundColor: ZephyrColors.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _ImportSourceSheet(),
    );

    if (source == null) return;

    switch (source) {
      case ImportSource.file_picker:
        await _pickFromFilePicker();
      case ImportSource.share_intent:
        await _pickFromFilePicker();
      case ImportSource.clipboard:
        _showSnackBar('Clipboard import coming soon');
      case ImportSource.camera:
        _showSnackBar('Camera import coming soon');
    }
  }

  /// Opens the native file picker to select documents.
  Future<void> _pickFromFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'txt', 'csv', 'html', 'md',
        'json', 'xml', 'docx', 'pptx', 'xlsx',
      ],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;

    final vm = context.read<DocumentsViewModel>();
    for (final file in result.files) {
      if (file.path != null && file.extension != null) {
        final mimeType = _resolveMimeType(file.extension!);
        await vm.importDocument(file.path!, mimeType);
      }
    }
  }

  /// Resolves a file extension to a MIME type string.
  String _resolveMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return MimeTypes.pdf;
      case 'txt':
        return MimeTypes.txt;
      case 'csv':
        return MimeTypes.csv;
      case 'html':
      case 'htm':
        return MimeTypes.html;
      case 'md':
        return MimeTypes.markdown;
      case 'json':
        return MimeTypes.json;
      case 'xml':
        return MimeTypes.xml;
      case 'docx':
        return MimeTypes.docx;
      case 'pptx':
        return MimeTypes.pptx;
      case 'xlsx':
        return MimeTypes.xlsx;
      default:
        return 'application/octet-stream';
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ZephyrColors.bgTertiary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusSm),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZephyrColors.bgPrimary,
      appBar: _buildAppBar(),
      body: Consumer<DocumentsViewModel>(
        builder: (context, vm, _) {
          // ── Indexing progress bar ────────────────────────────────
          final hasProgress = vm.isIndexing && vm.progress > 0;

          return Column(
            children: [
              // ── Error banner ─────────────────────────────────────
              if (vm.errorMessage != null)
                _buildErrorBanner(vm),

              // ── Global progress indicator ────────────────────────
              if (hasProgress)
                LinearProgressIndicator(
                  value: vm.progress,
                  minHeight: 3,
                  backgroundColor: ZephyrColors.bgTertiary,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    ZephyrColors.accentPurple,
                  ),
                ).animate(
                  effects: const [
                    FadeEffect(duration: Duration(milliseconds: 200)),
                  ],
                ),

              // ── Document list ────────────────────────────────────
              Expanded(
                child: vm.documents.isEmpty
                    ? _buildEmptyState()
                    : SmartRefresher(
                        enablePullDown: true,
                        controller: _refreshController,
                        onRefresh: () async {
                          await vm.loadDocuments();
                          _refreshController.refreshCompleted();
                        },
                        header: const WaterDropHeader(
                          waterDropColor: ZephyrColors.accentPurple,
                          backgroundColor: ZephyrColors.bgPrimary,
                        ),
                        child: _buildDocumentList(vm),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Documents'),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded, size: 24),
          onPressed: _showImportSourceSheet,
          tooltip: 'Import document',
        ),
      ],
    );
  }

  // ── Error Banner ─────────────────────────────────────────────────

  Widget _buildErrorBanner(DocumentsViewModel vm) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: UIConstants.spacingMd,
        vertical: UIConstants.spacingSm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: UIConstants.spacingMd,
        vertical: UIConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: ZephyrColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusMd),
        border: Border.all(
          color: ZephyrColors.error.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: ZephyrColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              vm.errorMessage!,
              style: const TextStyle(
                color: ZephyrColors.error,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: ZephyrColors.textMuted,
              size: 18,
            ),
            onPressed: vm.clearError,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    ).animate(
      effects: const [
        FadeEffect(duration: Duration(milliseconds: 200)),
        MoveEffect(
          begin: Offset(0, -10),
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        ),
      ],
    );
  }

  // ── Empty State ──────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Illustration area — gradient circles.
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ZephyrColors.accentPurple.withOpacity(0.15),
                  ZephyrColors.accentBlue.withOpacity(0.08),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 48,
              color: ZephyrColors.accentPurpleLight,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No documents yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: ZephyrColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Import documents to build your\nknowledge base',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ZephyrColors.textMuted,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showImportSourceSheet,
            icon: const Icon(Icons.upload_file_rounded, size: 20),
            label: const Text('Import Documents'),
          ).animate(
            effects: const [
              FadeEffect(duration: Duration(milliseconds: 400)),
              MoveEffect(
                duration: Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
              ),
            ],
          ),
        ],
      ).animate(
        effects: const [
          FadeEffect(duration: Duration(milliseconds: 500)),
          MoveEffect(
            duration: Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }

  // ── Document List ────────────────────────────────────────────────

  Widget _buildDocumentList(DocumentsViewModel vm) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: UIConstants.spacingMd,
        vertical: UIConstants.spacingSm,
      ),
      itemCount: vm.documents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final doc = vm.documents[index];
        final progress = vm.getProgress(doc.id);

        return Slidable(
          key: ValueKey(doc.id),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              // Retry action (shown for failed documents).
              if (doc.status == DocumentStatus.failed)
                SlidableAction(
                  onPressed: (_) => vm.retryIndexing(doc.id),
                  backgroundColor: ZephyrColors.warning,
                  foregroundColor: Colors.white,
                  icon: Icons.refresh_rounded,
                  label: 'Retry',
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(UIConstants.radiusMd),
                  ),
                ),
              // Delete action.
              SlidableAction(
                onPressed: (_) => _confirmDelete(doc),
                backgroundColor: ZephyrColors.error,
                foregroundColor: Colors.white,
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(UIConstants.radiusMd),
                ),
              ),
            ],
          ),
          child: DocumentCard(
            document: doc,
            progress: doc.status == DocumentStatus.indexing ? progress : null,
            onTap: () => vm.selectDocument(doc),
            onLongPress: () => _showContextMenu(doc),
          ),
        ).animate(
          delay: (index.clamp(0, 10) * 50).ms,
          effects: const [
            FadeEffect(duration: Duration(milliseconds: 250)),
            MoveEffect(
              begin: Offset(0, 12),
              duration: Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
            ),
          ],
        );
      },
    );
  }

  // ── FAB ──────────────────────────────────────────────────────────

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _showImportSourceSheet,
      tooltip: 'Import document',
      child: const Icon(Icons.add_rounded, size: 28),
    ).animate(
      effects: const [
        ScaleEffect(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
        ),
        FadeEffect(duration: Duration(milliseconds: 300)),
      ],
    );
  }

  // ── Actions ──────────────────────────────────────────────────────

  Future<void> _confirmDelete(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Document'),
            content: Text(
              'Are you sure you want to delete "${doc.title}"?\n'
              'This will remove all ${doc.chunkCount} indexed chunks.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: ZephyrColors.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed && mounted) {
      await context.read<DocumentsViewModel>().deleteDocument(doc.id);
    }
  }

  void _showContextMenu(DocumentModel doc) {
    final vm = context.read<DocumentsViewModel>();
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 200,
        100,
        16,
        0,
      ),
      items: [
        PopupMenuItem(
          value: 'retry',
          enabled: doc.status == DocumentStatus.failed,
          child: Row(
            children: [
              const Icon(
                Icons.refresh_rounded,
                color: ZephyrColors.accentPurpleLight,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text('Retry Indexing'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(
                Icons.delete_outline_rounded,
                color: ZephyrColors.error,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text('Delete Document'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'retry') {
        vm.retryIndexing(doc.id);
      } else if (value == 'delete') {
        _confirmDelete(doc);
      }
    });
  }
}

// ── Import Source Bottom Sheet ─────────────────────────────────────

class _ImportSourceSheet extends StatelessWidget {
  const _ImportSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UIConstants.spacingLg,
        UIConstants.spacingMd,
        UIConstants.spacingLg,
        UIConstants.spacingXl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar.
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ZephyrColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Import Documents',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: ZephyrColors.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how you want to add documents',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ZephyrColors.textMuted,
                ),
          ),
          const SizedBox(height: 24),

          // File Picker option.
          _ImportOptionTile(
            icon: Icons.folder_open_rounded,
            title: 'File Picker',
            subtitle: 'Browse files on your device',
            source: ImportSource.file_picker,
            onTap: () => Navigator.of(context).pop(ImportSource.file_picker),
          ),
          const SizedBox(height: 4),

          // Share Intent option.
          _ImportOptionTile(
            icon: Icons.share_rounded,
            title: 'Share from another app',
            subtitle: 'Import via system share sheet',
            source: ImportSource.share_intent,
            onTap: () => Navigator.of(context).pop(ImportSource.share_intent),
          ),
          const SizedBox(height: 4),

          // Clipboard option (coming soon).
          _ImportOptionTile(
            icon: Icons.content_paste_rounded,
            title: 'Clipboard',
            subtitle: 'Paste from clipboard',
            source: ImportSource.clipboard,
            isDisabled: true,
            onTap: () {},
          ),
          const SizedBox(height: 4),

          // Camera option (coming soon).
          _ImportOptionTile(
            icon: Icons.camera_alt_rounded,
            title: 'Camera / Scanner',
            subtitle: 'Scan a physical document',
            source: ImportSource.camera,
            isDisabled: true,
            onTap: () {},
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ImportOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ImportSource source;
  final bool isDisabled;
  final VoidCallback onTap;

  const _ImportOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.source,
    this.isDisabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(UIConstants.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UIConstants.spacingMd,
            vertical: UIConstants.spacingMd,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDisabled
                      ? ZephyrColors.bgTertiary.withOpacity(0.5)
                      : ZephyrColors.accentPurple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(UIConstants.radiusSm),
                ),
                child: Icon(
                  icon,
                  color: isDisabled
                      ? ZephyrColors.textMuted.withOpacity(0.5)
                      : ZephyrColors.accentPurpleLight,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDisabled
                            ? ZephyrColors.textMuted.withOpacity(0.5)
                            : ZephyrColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDisabled
                            ? ZephyrColors.textMuted.withOpacity(0.4)
                            : ZephyrColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDisabled)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: ZephyrColors.textMuted,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}