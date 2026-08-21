/// Common Dart extensions used throughout the Zephyr codebase.
///
/// Provides convenience methods on [String], [DateTime], and
/// [List<double>] (vector math helpers).
library;

/// Extension methods on [String].
extension StringExtensions on String {
  /// Capitalises the first character of the string.
  ///
  /// ```dart
  /// 'hello'.capitalize(); // 'Hello'
  /// ```
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

/// Extension methods on [DateTime].
extension DateTimeExtensions on DateTime {
  /// Returns a human-friendly relative time string.
  ///
  /// Examples:
  /// * `"2 minutes ago"`
  /// * `"3 hours ago"`
  /// * `"yesterday"`
  /// * `"Jan 15, 2025"` (falls back to a short date)
  String get fromNow {
    final diff = DateTime.now().difference(this);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      final minutes = diff.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (diff.inHours < 24) {
      final hours = diff.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      final days = diff.inDays;
      return '$days days ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final year = (diff.inDays / 365).floor();
      return '$year ${year == 1 ? 'year' : 'years'} ago';
    }
  }
}

/// Extension methods on [List<double>] for vector operations.
extension VectorListExtensions on List<double> {
  /// Computes the **dot product** of this vector with [other].
  ///
  /// Both vectors must have the same length.
  double dotProduct(List<double> other) {
    if (length != other.length) {
      throw ArgumentError(
        'Vectors must have the same length. '
        'Got ${length} and ${other.length}.',
      );
    }

    double sum = 0;
    for (int i = 0; i < length; i++) {
      sum += this[i] * other[i];
    }
    return sum;
  }

  /// Returns the **L2 (Euclidean) norm** of this vector.
  double get norm {
    double sum = 0;
    for (final v in this) {
      sum += v * v;
    }
    return sum.sqrt();
  }

  /// Returns a **unit-normalised** copy of this vector.
  ///
  /// If the vector has zero magnitude, returns the original list.
  List<double> normalize() {
    final n = norm;
    if (n == 0.0) return List.unmodifiable(this);
    return map((v) => v / n).toList(growable: false);
  }

  /// Computes the **cosine similarity** between this vector and [other].
  ///
  /// Returns a value in the range `[-1, 1]` where `1` means the vectors
  /// point in the same direction.
  double cosineSimilarity(List<double> other) {
    if (length != other.length) {
      throw ArgumentError(
        'Vectors must have the same length. '
        'Got ${length} and ${other.length}.',
      );
    }

    final dot = dotProduct(other);
    final normA = norm;
    double normB = 0;
    for (final v in other) {
      normB += v * v;
    }
    normB = normB.sqrt();

    final denominator = normA * normB;
    if (denominator == 0.0) return 0.0;

    return dot / denominator;
  }
}