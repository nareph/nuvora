/// Immutable record mirroring one entry in `assets/exercises/exercises.json`.
///
/// This is the *source* data from the external dataset (hasaneyldrm).
/// It contains the raw classification made by the dataset author, plus
/// localized instructions and media references.
///
/// It is NOT the domain model — see [ExercisePoolEntry] for that.
class ExerciseDatasetRecord {
  final String id;
  final String name;
  final String bodyPart;
  final String equipment;
  final String target;
  final String muscleGroup;
  final List<String> secondaryMuscles;

  /// Localized instructions: {"en": "...", "fr": "..."}.
  final Map<String, String> instructions;

  /// Relative asset path (e.g. "images/0001-2gPfomN.jpg").
  final String image;

  /// Relative asset path (e.g. "videos/0001-2gPfomN.gif").
  final String gifUrl;

  final String mediaId;
  final String attribution;

  const ExerciseDatasetRecord({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.equipment,
    required this.target,
    required this.muscleGroup,
    required this.secondaryMuscles,
    required this.instructions,
    required this.image,
    required this.gifUrl,
    required this.mediaId,
    required this.attribution,
  });

  factory ExerciseDatasetRecord.fromJson(Map<String, dynamic> json) {
    return ExerciseDatasetRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      bodyPart: json['body_part'] as String,
      equipment: json['equipment'] as String,
      target: json['target'] as String,
      muscleGroup: json['muscle_group'] as String,
      secondaryMuscles: List<String>.from(
        json['secondary_muscles'] as List? ?? const [],
      ),
      instructions: Map<String, String>.from(
        json['instructions'] as Map? ?? const {},
      ),
      image: json['image'] as String? ?? '',
      gifUrl: json['gif_url'] as String? ?? '',
      mediaId: json['media_id'] as String? ?? '',
      attribution: json['attribution'] as String? ?? '',
    );
  }
}
