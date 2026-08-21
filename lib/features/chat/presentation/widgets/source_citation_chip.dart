/// A chip widget that displays source citations for a RAG response.
///
/// Shows the source document name (looked up from the database) as a
/// small, tappable chip. Tapping a chip could navigate to the source
/// document or show a preview of the cited chunk.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/database/app_database.dart';
import '../../../../theme/zephyr_theme.dart';

/// A compact chip showing a source document citation.
///
/// Looks up the document title from Hive using the chunk ID, and
/// displays it as a rounded chip with a subtle accent tint.
class SourceCitationChip extends StatelessWidget {
  /// The chunk IDs that were used as sources.
  final List<String> sourceIds;

  /// Optional callback when a chip is tapped.
  final void Function(String chunkId)? onTap;

  const SourceCitationChip({
    super.key,
    required this.sourceIds,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (sourceIds.isEmpty) return const SizedBox.shrink();

    // Limit displayed chips to avoid cluttering the UI.
    final displayIds = sourceIds.take(3).toList();
    final hasMore = sourceIds.length > 3;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final chunkId in displayIds)
          _SourceChip(
            chunkId: chunkId,
            onTap: () => onTap?.call(chunkId),
          ),
        if (hasMore)
          _MoreSourcesChip(
            count: sourceIds.length - 3,
          ),
      ],
    );
  }
}

/// A single source chip that looks up the document title from the DB.
class _SourceChip extends StatelessWidget {
  final String chunkId;
  final VoidCallback? onTap;

  const _SourceChip({
    required this.chunkId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Try to resolve the document title asynchronously.
    return FutureBuilder<String?>(
      future: _resolveDocumentTitle(context),
      builder: (context, snapshot) {
        final title = snapshot.data ?? chunkId.substring(0, 8);

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ZephyrColors.accentPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: ZephyrColors.accentPurple.withOpacity(0.25),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.source_rounded,
                  size: 12,
                  color: ZephyrColors.accentPurpleLight,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: ZephyrColors.accentPurpleLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Resolves the document title for a given chunk ID.
  Future<String?> _resolveDocumentTitle(BuildContext context) async {
    try {
      final db = AppDatabase();
      if (!db.isOpen) return null;

      final chunkRaw = db.chunksBox.get(chunkId);
      if (chunkRaw == null) return null;

      final chunkMap = chunkRaw as Map;
      final docId = chunkMap['documentId'] as String?;
      if (docId == null) return null;

      final docRaw = db.documentsBox.get(docId);
      if (docRaw == null) return null;

      final docMap = docRaw as Map;
      return docMap['title'] as String?;
    } catch (_) {
      return null;
    }
  }
}

/// A chip showing "+N more" when there are additional sources.
class _MoreSourcesChip extends StatelessWidget {
  final int count;

  const _MoreSourcesChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ZephyrColors.bgTertiary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: ZephyrColors.divider.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        '+$count more',
        style: const TextStyle(
          color: ZephyrColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}