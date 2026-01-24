const String kPetTitleSeparator = ' / ';
const int kMaxPetImages = 6;
const int kMaxPetVideos = 2;
const String kPetPlaceholderImage = 'assets/images/pet_placeholder.jpg';

final RegExp _titleSplitPattern =
    RegExp('\\s*(?:/|•|\u0007|\u2022|�|\uFFFD|[-–—])\\s*');

/// Normalizes pet titles such as `Cat • Persian` or `Dog - Labrador`
/// into the consistent `Cat / Persian` format used across the UI.
String normalizePetTitle(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  final parts = trimmed
      .split(_titleSplitPattern)
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) return trimmed;
  return parts.join(kPetTitleSeparator);
}

/// Splits a title into `(species, breed)` pairs using the normalized form.
(String, String) splitPetTitle(String raw) {
  final normalized = normalizePetTitle(raw);
  if (normalized.isEmpty) return ('', '');

  final parts = normalized.split(kPetTitleSeparator);
  if (parts.length < 2) return (normalized, '');

  final species = parts.first.trim();
  final breed = parts.sublist(1).join(kPetTitleSeparator).trim();
  return (species, breed);
}
