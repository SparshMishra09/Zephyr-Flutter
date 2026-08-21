/// A card widget that displays a single document's metadata and status.
///
/// Shows the document title, type icon, file size, chunk count, and a
/// status badge. Supports swipe actions (delete, retry) via the parent
/// [Slidable] widget and long-press context menus.
library;

import 'package:flutter/material.dart';

import '../../../../core/models/document_model.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../theme/zephyr_theme.dart';

/// A card displaying a document's information.
class DocumentCard extends StatelessWidget {
  /// The document to display.
  final DocumentModel document;

  /// Optional progress value (0.0 – 1.0) for indexing documents.
  final double? progress;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  /// Called when the card is long-pressed.
  final VoidCallback? onLongPress;

  const DocumentCard({
    super.key,
    required this.document,
    this.progress,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(document.status);

    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: const BorderRadius.all(Radius.circular(UIConstants.radiusMd)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: UIConstants.spacingMd,
                vertical: UIConstants.spacingMd,
              ),
              child: Row(
                children: [
                  // ── Type icon ────────────────────────────────────
                  _buildTypeIcon(),
                  const SizedBox(width: 14),

                  // ── Title + metadata ─────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title.
                        Text(
                          document.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ZephyrColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Metadata row.
                        Row(
                          children: [
                            _buildMetadataChip(
                              icon: Icons.insert_drive_file_rounded,
                              label: _formatFileSize(document.fileSize),
                            ),
                            const SizedBox(width: 8),
                            _buildMetadataChip(
                              icon: Icons.puzzle_piece_rounded,
                              label: '${document.chunkCount} chunks',
                            ),
                            const SizedBox(width: 8),
                            _buildMetadataChip(
                              icon: Icons.schedule_rounded,
                              label: _formatDate(document.updatedAt),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Status badge ─────────────────────────────────
                  _buildStatusBadge(statusColor),
                ],
              ),
            ),

            // ── Progress bar (for indexing documents) ─────────────
            if (document.status == DocumentStatus.indexing)
              LinearProgressIndicator(
                value: progress ?? 0.0,
                minHeight: 3,
                backgroundColor: ZephyrColors.bgTertiary,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(UIConstants.radiusMd),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Type Icon ────────────────────────────────────────────────────

  Widget _buildTypeIcon() {
    final iconData = _getTypeIcon();
    final iconColor = _getTypeColor();

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(UIConstants.radiusSm),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 22,
      ),
    );
  }

  IconData _getTypeIcon() {
    switch (document.mimeType) {
      case MimeTypes.pdf:
        return Icons.picture_as_pdf_rounded;
      case MimeTypes.docx:
        return Icons.description_rounded;
      case MimeTypes.xlsx:
        return Icons.table_chart_rounded;
      case MimeTypes.pptx:
        return Icons.slideshow_rounded;
      case MimeTypes.csv:
        return Icons.grid_on_rounded;
      case MimeTypes.json:
        return Icons.code_rounded;
      case MimeTypes.xml:
        return Icons.xml_rounded;
      case MimeTypes.html:
        return Icons.language_rounded;
      case MimeTypes.markdown:
        return Icons.markdown_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getTypeColor() {
    switch (document.mimeType) {
      case MimeTypes.pdf:
        return ZephyrColors.error;
      case MimeTypes.docx:
        return ZephyrColors.accentBlue;
      case MimeTypes.xlsx:
        return ZephyrColors.success;
      case MimeTypes.pptx:
        return ZephyrColors.warning;
      default:
        return ZephyrColors.accentPurpleLight;
    }
  }

  // ── Status Badge ─────────────────────────────────────────────────

  Widget _buildStatusBadge(Color color) {
    final label = _getStatusLabel(document.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(UIConstants.radiusFull),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status dot.
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.indexed:
        return ZephyrColors.success;
      case DocumentStatus.indexing:
        return ZephyrColors.warning;
      case DocumentStatus.failed:
        return ZephyrColors.error;
    }
  }

  String _getStatusLabel(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.indexed:
        return 'Indexed';
      case DocumentStatus.indexing:
        return 'Indexing';
      case DocumentStatus.failed:
        return 'Failed';
    }
  }

  // ── Metadata Chips ───────────────────────────────────────────────

  Widget _buildMetadataChip({
    required IconData icon,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: ZephyrColors.textMuted,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: ZephyrColors.textMuted,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Formatting helpers ───────────────────────────────────────────

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.month}/${date.day}/${date.year}';
  }
}