// lib/engines/workout_engine/selectors/movement_family.dart

/// Extracts a coarse "movement family" key from an exercise name.
///
/// Groups exercises that are essentially the same movement with
/// different equipment, angle, or grip — e.g. all of these belong
/// to the same `press` family:
///   • Barbell Bench Press
///   • Dumbbell Bench Press
///   • Neutral Grip Dumbbell Press
///   • Single Arm Dumbbell Press
///   • Machine Chest Press
///   • Plate-Loaded Chest Press
///
/// Two exercises in the same family should not both appear in the
/// same workout if alternatives exist.
///
/// Returns null if no known family matches (treated as unique).
String? movementFamilyOf(String name) {
  final lower = name.toLowerCase();

  final angle = _angleOf(lower);
  final base = _baseArchetypeOf(lower);

  if (base == null) return null;

  // Only the "angle-sensitive" bases get a prefixed key so that
  // Incline Press and Flat Press stay in different families.
  const angleSensitive = {
    'press',
    'ohp',
    'squat',
    'deadlift',
    'fly',
    'row-generic',
  };

  if (angleSensitive.contains(base) && angle != null) {
    return '$base-$angle';
  }

  return base;
}

String? _angleOf(String lower) {
  if (lower.contains('incline')) return 'incline';
  if (lower.contains('decline')) return 'decline';
  if (lower.contains('close-grip') || lower.contains('close grip'))
    return 'close';
  if (lower.contains('wide-grip') || lower.contains('wide grip')) return 'wide';
  return null;
}

String? _baseArchetypeOf(String lower) {
  // Order matters — most specific first.
  const families = <String, String>{
    // ── Push-ups ────────────────────────────────────────────────
    'push-up': 'pushup',
    'push up': 'pushup',
    'pushup': 'pushup',

    // ── Dips ────────────────────────────────────────────────────
    'dip': 'dip',

    // ── Overhead press (before generic 'press') ─────────────────
    'overhead barbell press': 'ohp',
    'kettlebell overhead press': 'ohp',
    'dumbbell overhead press': 'ohp',
    'band overhead press': 'ohp',
    'shoulder press': 'ohp',
    'overhead press': 'ohp',
    'military press': 'ohp',
    'arnold press': 'ohp',
    'push press': 'ohp',
    'bottoms-up press': 'ohp',

    // ── Specific chest presses ──────────────────────────────────
    'floor press': 'floor-press',
    'spoto press': 'spoto-press',
    'squeeze press': 'squeeze-press',

    // ── Bench / chest press (angle-agnostic) ────────────────────
    'bench press': 'press',
    'chest press': 'press',

    // ── Generic press (fallback) ────────────────────────────────
    'press': 'press',

    // ── Fly / crossover / pullover ──────────────────────────────
    'crossover': 'crossover',
    'pec deck': 'fly',
    'flye': 'fly',
    'fly': 'fly',
    'pullover': 'pullover',

    // ── Squats ──────────────────────────────────────────────────
    'goblet squat': 'squat',
    'front squat': 'squat',
    'back squat': 'squat',
    'barbell squat': 'squat',
    'bodyweight squat': 'squat',
    'hack squat': 'squat',
    'jump squat': 'squat',
    'sumo squat': 'squat',
    'split squat': 'squat',
    'pistol squat': 'squat',
    'squat': 'squat',

    // ── Lunges / Step-ups ───────────────────────────────────────
    'lunge': 'lunge',
    'step-up': 'stepup',
    'step up': 'stepup',

    // ── Leg press / hip thrust / glute bridge ───────────────────
    'leg press': 'legpress',
    'hip thrust': 'hipthrust',
    'glute bridge': 'glutebridge',

    // ── Deadlifts ───────────────────────────────────────────────
    'romanian deadlift': 'rdl',
    'sumo deadlift': 'deadlift',
    'rack pull': 'deadlift',
    'deadlift': 'deadlift',

    // ── Swing ───────────────────────────────────────────────────
    'swing': 'swing',

    // ── Leg curl / extension / calf ─────────────────────────────
    'leg curl': 'legcurl',
    'leg extension': 'legext',
    'calf raise': 'calfraise',

    // ── Hip abduct / adduct ─────────────────────────────────────
    'hip abduction': 'hipabduct',
    'hip adduction': 'hipabduct',

    // ── Other leg movements ─────────────────────────────────────
    'glute kickback': 'glute-kick',
    'box jump': 'boxjump',
    'lateral walk': 'lateral-walk',
    'clamshell': 'clamshell',
    'pull-through': 'pullthrough',
    'pull through': 'pullthrough',

    // ── Pull-ups / pulldowns ────────────────────────────────────
    'pull-up': 'pullup',
    'pull up': 'pullup',
    'chin-up': 'pullup',
    'chin up': 'pullup',
    'pullup': 'pullup',
    'lat pulldown': 'pulldown',
    'pulldown': 'pulldown',

    // ── Rows (raffinés par variante) ────────────────────────────
    // Most specific patterns FIRST.
    'incline dumbbell row': 'row-incline',
    'incline row': 'row-incline',
    'chest-supported row': 'row-incline',
    'chest supported row': 'row-incline',

    'bent-over row': 'row-bent-over',
    'bent over row': 'row-bent-over',
    'pendlay row': 'row-bent-over',

    'single-arm row': 'row-single-arm',
    'single arm row': 'row-single-arm',
    'dumbbell row': 'row-single-arm',
    'kettlebell row': 'row-single-arm',
    'one arm row': 'row-single-arm',
    'one-arm row': 'row-single-arm',

    'inverted row': 'row-inverted',
    'table row': 'row-inverted',
    'door frame row': 'row-inverted',
    'towel row': 'row-inverted',
    'feet-elevated inverted row': 'row-inverted',
    'smith machine inverted row': 'row-inverted',

    't-bar row': 'row-tbar',

    'seated row': 'row-seated',
    'cable row': 'row-seated',
    'machine row': 'row-seated',

    // Fallback générique — only matches bare "row".
    'row': 'row-generic',

    // ── Face pull / shrug ───────────────────────────────────────
    'face pull': 'facepull',
    'shrug': 'shrug',

    // ── Curls ───────────────────────────────────────────────────
    'hammer curl': 'hammer-curl',
    'preacher curl': 'preacher-curl',
    'concentration curl': 'conc-curl',
    'reverse curl': 'reverse-curl',
    'zottman curl': 'zottman-curl',
    'wrist curl': 'wrist-curl',
    'bicep curl': 'curl',
    'barbell curl': 'curl',
    'dumbbell curl': 'curl',
    'cable curl': 'curl',
    'kettlebell curl': 'curl',
    'band curl': 'curl',
    'curl': 'curl',

    // ── Triceps ─────────────────────────────────────────────────
    'skull crusher': 'skullcrusher',
    'overhead tricep extension': 'tricep-ext',
    'tricep extension': 'tricep-ext',
    'pushdown': 'pushdown',
    'kickback': 'kickback',

    // ── Raises ──────────────────────────────────────────────────
    'lateral raise': 'lateral-raise',
    'front raise': 'front-raise',
    'raise': 'raise',

    // ── Upright row ─────────────────────────────────────────────
    'upright row': 'upright-row',

    // ── Handstand / pike / wall ─────────────────────────────────
    'handstand push-up': 'hspu',
    'pike push-up': 'pike-pushup',
    'wall walk': 'wallwalk',
    'wall handstand hold': 'wall-handstand',

    // ── Carry ───────────────────────────────────────────────────
    'carry': 'carry',

    // ── Core ────────────────────────────────────────────────────
    'plank shoulder tap': 'plank',
    'shoulder tap': 'plank',
    'side plank': 'side-plank',
    'plank': 'plank',
    'mountain climber': 'mountainclimber',
    'bicycle crunch': 'bicycle-crunch',
    'reverse crunch': 'reverse-crunch',
    'crunch': 'crunch',
    'sit-up': 'situp',
    'sit up': 'situp',
    'leg raise': 'legraise',
    'russian twist': 'twist',
    'oblique twist': 'twist',
    'side bend': 'sidebend',
    'v-up': 'vup',
    'v up': 'vup',
    'hollow body': 'hollow',
    'ab wheel': 'abwheel',
    'dead bug': 'deadbug',
    'bird dog row': 'birddog',
    'bird dog': 'birddog',
    'heel touch': 'heeltouch',
    'toe touch': 'toetouch',
    'hanging knee raise': 'hanging-legraise',
    'hanging leg raise': 'hanging-legraise',
    'toes-to-bar': 'toes2bar',
    'toes to bar': 'toes2bar',
    'windshield wiper': 'wiper',
    'l-sit': 'l-sit',
    'pallof press': 'pallof',
    'woodchop': 'woodchop',

    // ── Superman / snow angel / prone ───────────────────────────
    'superman': 'superman',
    'snow angel': 'snowangel',
    'pull-apart': 'pullapart',
    'pull apart': 'pullapart',
    'scapular push-up': 'scapular-pushup',

    // ── Prone raises (I-Y-T-W) ──────────────────────────────────
    'prone i-raise': 'prone-raise',
    'prone y-raise': 'prone-raise',
    'prone t-raise': 'prone-raise',
    'prone w-raise': 'prone-raise',
    'prone i-y-t': 'prone-raise',
    'prone raise': 'prone-raise',
  };

  for (final entry in families.entries) {
    if (lower.contains(entry.key)) {
      return entry.value;
    }
  }

  return null;
}
