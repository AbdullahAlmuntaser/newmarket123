/// Name normalization utility for smart customer search
/// Handles Arabic text normalization for consistent matching
class NameNormalizer {
  /// Normalizes a customer name for database storage and search
  ///
  /// Rules:
  /// - Removes extra whitespace
  /// - Converts to lowercase
  /// - Removes Arabic diacritics (tashkeel)
  /// - Normalizes Arabic characters:
  ///   - أ, إ, آ → ا
  ///   - ة → ه
  ///   - ى → ي
  static String normalize(String name) {
    if (name.isEmpty) return '';

    // Trim and remove extra spaces
    String normalized = name.trim().replaceAll(RegExp(r'\s+'), ' ');

    // Convert to lowercase
    normalized = normalized.toLowerCase();

    // Remove Arabic diacritics (tashkeel)
    normalized = _removeDiacritics(normalized);

    // Normalize Arabic characters
    normalized = _normalizeArabicCharacters(normalized);

    return normalized;
  }

  /// Remove Arabic diacritics (tashkeel)
  static String _removeDiacritics(String text) {
    // Arabic diacritics range: \u064B-\u065F
    return text.replaceAll(RegExp(r'[\u064B-\u065F]'), '');
  }

  /// Normalize Arabic characters:
  /// - أ (hamza above) → ا
  /// - إ (hamza below) → ا
  /// - آ (hamza + alef) → ا
  /// - ة (taa marbuta) → ه
  /// - ى (alef maksura) → ي
  static String _normalizeArabicCharacters(String text) {
    String result = text;

    // أ, إ, آ → ا
    result = result.replaceAll(RegExp('[أإآ]'), 'ا');

    // ة → ه
    result = result.replaceAll('ة', 'ه');

    // ى → ي
    result = result.replaceAll('ى', 'ي');

    return result;
  }

  /// Calculate similarity between two normalized names
  /// Returns a value between 0.0 and 1.0
  static double calculateSimilarity(String normalized1, String normalized2) {
    if (normalized1.isEmpty || normalized2.isEmpty) return 0.0;
    if (normalized1 == normalized2) return 1.0;

    // Check if one contains the other
    if (normalized1.contains(normalized2) ||
        normalized2.contains(normalized1)) {
      final shorter = normalized1.length < normalized2.length
          ? normalized1
          : normalized2;
      final longer = normalized1.length < normalized2.length
          ? normalized2
          : normalized1;
      return shorter.length / longer.length;
    }

    // Levenshtein distance based similarity
    final distance = _levenshteinDistance(normalized1, normalized2);
    final maxLength = normalized1.length > normalized2.length
        ? normalized1.length
        : normalized2.length;

    return 1.0 - (distance / maxLength);
  }

  /// Calculate Levenshtein distance between two strings
  static int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> previousRow = List<int>.generate(s2.length + 1, (i) => i);
    List<int> currentRow = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      currentRow[0] = i + 1;

      for (int j = 0; j < s2.length; j++) {
        final cost = s1[i] == s2[j] ? 0 : 1;
        currentRow[j + 1] = [
          currentRow[j] + 1, // deletion
          previousRow[j + 1] + 1, // insertion
          previousRow[j] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }

      final temp = previousRow;
      previousRow = currentRow;
      currentRow = temp;
    }

    return previousRow[s2.length];
  }

  /// Check if two normalized names match with given threshold
  /// threshold: 0.0 to 1.0 (default 0.8 for fuzzy match)
  static bool isMatch(
    String normalized1,
    String normalized2, {
    double threshold = 0.8,
  }) {
    // Exact match
    if (normalized1 == normalized2) return true;

    // Fuzzy match
    final similarity = calculateSimilarity(normalized1, normalized2);
    return similarity >= threshold;
  }
}
