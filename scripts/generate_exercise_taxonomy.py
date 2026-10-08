#!/usr/bin/env python3
"""
generate_exercise_taxonomy.py (v3)

Corrections vs v2 :
  * Réordonne les priorités de mouvement : lunge > squat > olympic > hinge
    > pull > push > rotation > core > cardio
  * Distingue "twisting/twisted" (adjectif) de "twist/pallof/woodchop" (nom)
  * Cas spéciaux : pallof press, leg press, calf press, squat row
  * "clean-grip front squat" reste squat, "squat jerk" devient push
  * "leg raise / knee raise" → core avant rotation
  * Sur-ensemble OVERRIDES pour les rares cas exotiques
"""

import json
import re
from pathlib import Path

SOURCE_JSON = Path("data_source/exercises.json")
OUT_DIR = Path("assets/exercises")
KEEP_LANGUAGES = ["en", "fr"]


# ─────────────────────────────────────────────────────────────────────────
# MAPPINGS ÉQUIPEMENT — inchangés depuis v2
# ─────────────────────────────────────────────────────────────────────────

EQUIPMENT_MAP = {
    "body weight": "bodyweight", "bodyweight": "bodyweight",
    "assisted": "bodyweight", "weighted": "bodyweight",
    "balance board": "fitnessMat", "stability ball": "fitnessMat",
    "bosu ball": "fitnessMat", "medicine ball": "homemadeWeights",
    "resistance band": "resistanceBands", "band": "resistanceBands",
    "rope": "resistanceBands", "jump rope": "jumpRope",
    "wheel roller": "abWheel", "roller": "abWheel", "ab wheel": "abWheel",
    "dumbbell": "dumbbells", "kettlebell": "kettlebell",
    "ez barbell": "barbellAndPlates", "barbell": "barbellAndPlates",
    "olympic barbell": "barbellAndPlates", "trap bar": "barbellAndPlates",
    "hammer": "gymMachinesSelectorized",
    "pull-up bar": "pullUpBarAccessible",
    "dip bar": "dipStationOrParallelBars",
    "smith machine": "smithMachine",
    "cable": "cableMachinePulley",
    "lever": "gymMachinesSelectorized", "machine": "gymMachinesSelectorized",
    "leverage machine": "gymMachinesSelectorized",
    "sled": "legPressMachine", "sled machine": "legPressMachine",
    "tire": "openSpaceForRunningSprints",
    "skierg": "cardioRowingMachine", "skierg machine": "cardioRowingMachine",
    "stationary bike": "cardioStationaryBike",
    "elliptical": "cardioElliptical", "elliptical machine": "cardioElliptical",
    "treadmill": "cardioTreadmill",
    "rowing machine": "cardioRowingMachine",
    "upper body ergometer": "cardioStationaryBike",
    "stepmill": "stairsOrStep", "stepmill machine": "stairsOrStep",
}

MUSCLE_MAP = {
    "pectorals": "chest", "chest": "chest", "serratus anterior": "chest",
    "lats": "back", "latissimus dorsi": "back", "back": "back",
    "upper back": "back", "rhomboids": "back",
    "traps": "traps", "trapezius": "traps",
    "lower back": "back", "spine": "back", "erector spinae": "back",
    "delts": "shoulders", "deltoids": "shoulders",
    "front deltoids": "shoulders", "rear deltoids": "shoulders",
    "shoulders": "shoulders", "rotator cuff": "shoulders",
    "biceps": "biceps", "brachialis": "biceps",
    "triceps": "triceps",
    "quads": "quadriceps", "quadriceps": "quadriceps",
    "hamstrings": "hamstrings", "glutes": "glutes",
    "calves": "calves", "soleus": "calves",
    "adductors": "adductors", "abductors": "glutes",
    "hip flexors": "quadriceps", "inner thighs": "adductors",
    "abs": "absCore", "abdominals": "absCore", "core": "absCore",
    "obliques": "absCore", "waist": "absCore", "lower abs": "absCore",
    "forearms": "forearms", "wrist flexors": "forearms",
    "wrist extensors": "forearms", "grip": "forearms",
    "cardiovascular system": "quadriceps",
}

BODY_PART_TO_SPLITS = {
    "chest": ["Chest", "Chest & Triceps", "Push", "Upper Body"],
    "back": ["Back", "Back & Biceps", "Pull", "Upper Body"],
    "shoulders": ["Shoulders", "Push", "Upper Body"],
    "upper arms": ["Arms", "Back & Biceps", "Chest & Triceps", "Pull", "Push"],
    "lower arms": ["Arms"],
    "waist": ["Core"],
    "upper legs": ["Legs", "Lower Body"],
    "lower legs": ["Legs", "Lower Body"],
    "cardio": ["Cardio"],
    "neck": ["Shoulders"],
}

BODY_PART_FALLBACK_MOVEMENT = {
    "upper legs": "squat", "lower legs": "squat",
    "waist": "core", "chest": "push", "back": "pull",
    "shoulders": "push", "upper arms": "pull", "lower arms": "pull",
    "cardio": "cardio", "neck": "pull",
}


# ─────────────────────────────────────────────────────────────────────────
# KEYWORDS — réorganisés
# ─────────────────────────────────────────────────────────────────────────

MOBILITY_KEYWORDS = ["stretch", "mobility", "range of motion", "flexibility"]

# Carries
CARRY_KEYWORDS = ["carry", "farmer", "suitcase", "waiter", "overhead carry"]

# Lunges — before rotation and squat
LUNGE_KEYWORDS = [
    "lunge", "step-up", "step up", "split squat", "bulgarian",
]

# Squats (checked BEFORE olympic to catch "clean-grip front squat")
SQUAT_KEYWORDS = [
    "squat", "hack squat", "leg press", "goblet", "sit to stand",
]

# Olympic — checked AFTER squat but with exceptions
OLYMPIC_WORDS = ["clean", "snatch", "jerk", "thruster"]

# Hinge (before generic push because "hyperextension" contains "extension")
HINGE_KEYWORDS = [
    "deadlift", "romanian", "rdl", "hip thrust", "glute bridge",
    "swing", "good morning", "hyperextension", "back extension",
    "pull-through", "pull through", "hip lift",
]

# Pull — must come BEFORE push to catch "pullover", "row", "curl"
PULL_KEYWORDS = [
    "row", "pull-up", "pull up", "chin-up", "chin up", "pulldown",
    "pull down", "curl", "face pull", "shrug", "deadlift",
    "pullover", "pull-through", "pull through", "pull apart",
    "pull-apart", "rear delt", "rear-delt", "back lever", "front lever",
    "high pull", "upright row", "judo flip",
]

# Push — before generic rotation, but NOT when preceded by "leg"/"calf"
PUSH_KEYWORDS = [
    "press", "push-up", "push up", "dip", "fly", "flye", "raise",
    "extension", "overhead", "bench press", "pushdown", "push down",
    "crossover", "cross-over", "pec deck", "kickback", "skullcrusher",
    "skull crusher", "iron cross", "thruster",
]

# Rotation as NOUN — the movement itself
ROTATION_AS_NOUN = [
    "twist", "woodchop", "wood chop", "chop", "pallof",
    "windshield", "windmill", "judo flip", "russian twist",
    "side bend",
]

# Rotation as ADJECTIVE — just a modifier, should not force rotation
ROTATION_AS_ADJECTIVE = [
    "twisting", "twisted", "rotational", "rotating",
]

CORE_KEYWORDS = [
    "plank", "crunch", "sit-up", "sit up", "situp",
    "hollow", "dead bug", "bird dog", "ab wheel",
    "v-up", "v up", "bicycle", "mountain climber",
    "toe touch", "heel touch", "scissor", "flutter",
    "toes-to-bar", "l-sit", "hanging",
    "rollout", "roll-out", "roll out", "cocoons", "butt-ups", "butt ups",
    "bottoms-up", "back and forth step", "knee tuck",
    "reverse crunch", "ab rollout", "jackknife", "hip roll",
]

# Core raises — checked early because "oblique knee raise" shouldn't become rotation
CORE_RAISE_KEYWORDS = ["leg raise", "knee raise", "leg lift", "hip raise"]

CARDIO_KEYWORDS = [
    "run", "sprint", "jump rope", "burpee", "jumping jack",
    "high knees", "bike", "rowing", "row erg", "elliptical",
    "treadmill", "stepmill", "bear crawl", "battling ropes",
    "astride jumps", "backward jump", "forward jump",
    "cycle cross trainer", "skierg", "assault bike", "air bike",
    "cross trainer", "climber", "box jump", "jump squat",
]

UNILATERAL_KEYWORDS = [
    "single-arm", "single arm", "single-leg", "single leg",
    "one-arm", "one arm", "one-leg", "one leg",
    "unilateral", "pistol", "archer", "staggered", "offset",
]
ALTERNATING_KEYWORDS = [
    "alternating", "alternate", "walking lunge", "bicycle",
    "mountain climber", "flutter", "scissor", "russian twist",
    "windshield", "circles",
]
FRONTAL_KEYWORDS = [
    "lateral", "side", "abduction", "adduction", "sumo",
    "side bend", "side lunge", "clamshell", "hip abduction",
    "hip adduction", "cable lateral", "cross-over",
]
TRANSVERSE_KEYWORDS = [
    "twist", "twisting", "rotation", "woodchop", "chop", "pallof",
    "crossover", "cross-over", "fly", "flye", "rear delt fly",
    "reverse fly", "face pull", "pull apart", "pull-apart",
    "russian twist", "oblique", "judo flip", "iron cross",
]
CLOSED_CHAIN_HINTS = [
    "push-up", "push up", "pull-up", "pull up", "chin-up", "chin up",
    "dip", "plank", "squat", "lunge", "step-up", "step up",
    "hip thrust", "glute bridge", "deadlift", "burpee",
    "mountain climber", "bear crawl",
]
ADVANCED_KEYWORDS = [
    "pistol", "archer", "handstand", "muscle-up", "one-arm",
    "one arm", "single-arm", "single leg", "single-leg",
    "front lever", "planche", "advanced", "weighted",
    "back lever", "oly", "clean", "snatch", "jerk",
]
BEGINNER_KEYWORDS = [
    "machine", "assisted", "band", "smith", "goblet",
    "cable", "wall", "incline push", "chair", "stretch",
    "circles", "mobility",
]


# ─────────────────────────────────────────────────────────────────────────
# OVERRIDES — pour les cas exotiques restants
# ─────────────────────────────────────────────────────────────────────────

MOVEMENT_OVERRIDES = {
    # Barbell pullover to press → still primarily pull (pullover)
    "0022": "pull",
    # Cable lying extension pullover → pull
    "0184": "pull",
    # Lever reverse hyperextension → hinge
    "0593": "hinge",
    # Weighted hyperextension → hinge
    "0835": "hinge",
    # Cable palm rotational row → pull (row wins)
    "1319": "pull",
    # Cable rope extension incline bench row → pull
    "1322": "pull",
    # Dumbbell seated biceps curl to shoulder press → pull (curl is first)
    "3547": "pull",
    # Dumbbell standing alternate hammer curl and press → pull
    "3560": "pull",
    # Dumbbell twisting bench press → push
    "1743": "push",
    # Cable squatting curl → pull (curl wins)
    "1644": "pull",
}


# ─────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────

def slug(s: str) -> str:
    s = s.lower()
    s = re.sub(r"[^a-z0-9\s]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def _any(text: str, keywords: list) -> bool:
    return any(k in text for k in keywords)


def _has_word(text: str, word: str) -> bool:
    return re.search(rf"\b{re.escape(word)}\b", text) is not None


def infer_movement_pattern(name: str, body_part: str, ex_id: str = "") -> str:
    lower = slug(name)

    # 0. Overrides manuels prioritaires
    if ex_id in MOVEMENT_OVERRIDES:
        return MOVEMENT_OVERRIDES[ex_id]

    # 1. Mobility
    if _any(lower, MOBILITY_KEYWORDS):
        return "core"

    # 2. Pallof press → anti-rotation (before generic press)
    if "pallof" in lower:
        return "rotation"

    # 3. Carry
    if _any(lower, CARRY_KEYWORDS):
        return "carry"

    # 4. Lunge / Step-up (before rotation so "lunge with twist" stays lunge)
    if _any(lower, LUNGE_KEYWORDS):
        return "lunge"

    # 5. Core raises (before rotation so "oblique knee raise" stays core)
    if _any(lower, CORE_RAISE_KEYWORDS):
        return "core"

    # 6. "squat row" is a row, not a squat
    if "squat row" in lower or "squatting row" in lower:
        return "pull"

    # 7. Olympic — but only if NOT a squat/clean-grip variant
    if any(_has_word(lower, w) for w in OLYMPIC_WORDS):
        if "front squat" in lower and "clean" in lower:
            return "squat"
        if "clean grip" in lower and "squat" in lower:
            return "squat"
        if "squat jerk" in lower:
            return "push"  # jerk is the primary
        return "push"

    # 8. Squat (normal path)
    if _any(lower, SQUAT_KEYWORDS):
        return "squat"

    # 9. Hinge (before push so "hyperextension" stays hinge)
    if _any(lower, HINGE_KEYWORDS):
        return "hinge"

    # 10. Leg press / calf press — explicit special case
    if "leg press" in lower or "calf press" in lower:
        return "squat"

    # 11. Pull (before push so "pullover" stays pull)
    if _any(lower, PULL_KEYWORDS):
        return "pull"

    # 12. Push — but check exceptions for "leg press"/"calf press" already handled
    if _any(lower, PUSH_KEYWORDS):
        return "push"

    # 13. Rotation as NOUN (now safe — no push/pull/lunge/squat captured)
    if _any(lower, ROTATION_AS_NOUN):
        return "rotation"

    # 14. Rotation as ADJECTIVE (fallback)
    if _any(lower, ROTATION_AS_ADJECTIVE):
        return "rotation"

    # 15. Core
    if _any(lower, CORE_KEYWORDS):
        return "core"

    # 16. Cardio
    if _any(lower, CARDIO_KEYWORDS):
        return "cardio"

    # 17. Fallback par body_part
    return BODY_PART_FALLBACK_MOVEMENT.get(slug(body_part), "unknown")


def infer_laterality(name: str) -> str:
    lower = slug(name)
    if _any(lower, ALTERNATING_KEYWORDS):
        return "alternating"
    if _any(lower, UNILATERAL_KEYWORDS):
        return "unilateral"
    return "bilateral"


def infer_plane(name: str) -> str:
    lower = slug(name)
    if _any(lower, TRANSVERSE_KEYWORDS):
        return "transverse"
    if _any(lower, FRONTAL_KEYWORDS):
        return "frontal"
    return "sagittal"


def infer_mechanics(name: str) -> str:
    return "closedChain" if _any(slug(name), CLOSED_CHAIN_HINTS) else "openChain"


def infer_difficulty(name: str, equipment: str) -> str:
    lower = slug(name)
    if _any(lower, ADVANCED_KEYWORDS):
        return "advanced"
    if _any(lower, BEGINNER_KEYWORDS):
        return "beginner"
    if equipment in ("barbell", "olympic barbell", "ez barbell", "trap bar"):
        return "intermediate"
    return "beginner"


def infer_category(name: str) -> str:
    lower = slug(name)
    if _any(lower, MOBILITY_KEYWORDS):
        return "mobility"
    if _any(lower, CARDIO_KEYWORDS) and not _any(lower, ["box jump", "jump squat"]):
        return "cardio"
    compound_hints = [
        "press", "squat", "deadlift", "row", "pull-up", "pull up",
        "chin-up", "chin up", "dip", "lunge", "clean", "snatch",
        "jerk", "thruster", "push press", "push-up", "push up",
        "bench press", "step-up", "step up", "hip thrust",
    ]
    return "compound" if _any(lower, compound_hints) else "isolation"


def infer_is_timed(name: str) -> bool:
    lower = slug(name)
    return _any(lower, [
        "plank", "hold", "wall sit", "l-sit", "hollow body",
        "isometric", "carry", "jump rope", "run", "sprint",
        "bike", "rowing", "burpee", "mountain climber",
        "stretch", "mobility", "circle", "circles",
    ])


def infer_is_bodyweight(equipment_raw: str) -> bool:
    return equipment_raw in ("body weight", "bodyweight", "assisted", "weighted")


def infer_force_type(name: str, movement: str) -> str:
    lower = slug(name)
    if _any(lower, ["plank", "hold", "isometric", "wall sit",
                     "l-sit", "hollow body", "stretch"]):
        return "isometric"
    if movement == "push":
        return "push"
    if movement in ("pull", "hinge", "carry"):
        return "pull"
    if movement in ("squat", "lunge"):
        return "push"
    return "push"


def map_muscles(target: str, muscle_group: str, secondary: list) -> tuple:
    primary, sec = set(), set()
    for src in [target, muscle_group]:
        if slug(src) in MUSCLE_MAP:
            primary.add(MUSCLE_MAP[slug(src)])
    for src in secondary:
        if slug(src) in MUSCLE_MAP:
            sec.add(MUSCLE_MAP[slug(src)])
    sec -= primary
    if not primary:
        primary = {"absCore"}
    return sorted(primary), sorted(sec)


def map_equipment(raw: str) -> tuple:
    key = slug(raw)
    if key in EQUIPMENT_MAP:
        return EQUIPMENT_MAP[key], False
    return "bodyweight", True


def infer_splits(body_part: str) -> list:
    return BODY_PART_TO_SPLITS.get(slug(body_part), [])


def slim_instructions(instr: dict) -> dict:
    return {lang: instr.get(lang, "") for lang in KEEP_LANGUAGES if lang in instr}


def slim_exercise(ex: dict) -> dict:
    return {
        "id": ex["id"], "name": ex["name"], "body_part": ex["body_part"],
        "equipment": ex["equipment"], "target": ex["target"],
        "muscle_group": ex["muscle_group"],
        "secondary_muscles": ex["secondary_muscles"],
        "instructions": slim_instructions(ex.get("instructions", {})),
        "image": ex["image"], "gif_url": ex["gif_url"],
        "media_id": ex["media_id"], "attribution": ex["attribution"],
    }


# ─────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────

def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with SOURCE_JSON.open("r", encoding="utf-8") as f:
        dataset = json.load(f)

    print(f"📦 {len(dataset)} exercices lus depuis {SOURCE_JSON}")

    slimmed, taxonomy = [], {}
    report = {
        "total": len(dataset), "complete": 0, "needs_review": [],
        "unknown_movement_pattern": 0, "unknown_equipment": 0,
        "classified_as_mobility": 0,
    }

    for ex in dataset:
        ex_id, name = ex["id"], ex["name"]
        body_part = ex["body_part"]
        slimmed.append(slim_exercise(ex))

        equipment_raw = ex["equipment"]
        equipment_mapped, eq_unknown = map_equipment(equipment_raw)

        movement = infer_movement_pattern(name, body_part, ex_id)
        laterality = infer_laterality(name)
        plane = infer_plane(name)
        mechanics = infer_mechanics(name)
        difficulty = infer_difficulty(name, equipment_raw)
        category = infer_category(name)
        force = infer_force_type(name, movement)
        is_timed = infer_is_timed(name)
        is_bw = infer_is_bodyweight(equipment_raw)
        primary, secondary = map_muscles(
            ex["target"], ex["muscle_group"], ex["secondary_muscles"])
        splits = infer_splits(body_part)

        flags = []
        if movement == "unknown":
            flags.append("movement_pattern")
            report["unknown_movement_pattern"] += 1
        if eq_unknown:
            flags.append("equipment")
            report["unknown_equipment"] += 1
        if category == "mobility":
            report["classified_as_mobility"] += 1

        taxonomy[ex_id] = {
            "equipment": equipment_mapped,  
            "category": category, "movementPattern": movement,
            "difficulty": difficulty, "mechanics": mechanics,
            "forceType": force, "laterality": laterality,
            "planeOfMotion": plane, "isBodyweight": is_bw,
            "isTimed": is_timed, "primaryMuscles": primary,
            "secondaryMuscles": secondary, "compatibleSplits": splits,
            "defaultSets": 3,
            "defaultReps": "30s" if is_timed else "8-12",
            "defaultRestSeconds": 60,
        }

        if flags:
            report["needs_review"].append({"id": ex_id, "name": name, "flags": flags})
        else:
            report["complete"] += 1

    with (OUT_DIR / "exercises.json").open("w", encoding="utf-8") as f:
        json.dump(slimmed, f, ensure_ascii=False, indent=2)
    with (OUT_DIR / "exercise_taxonomy.json").open("w", encoding="utf-8") as f:
        json.dump(taxonomy, f, ensure_ascii=False, indent=2)
    with (OUT_DIR / "taxonomy_report.json").open("w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    print(f"✅ exercises.json          : {len(slimmed)} exercices slim")
    print(f"✅ exercise_taxonomy.json  : {len(taxonomy)} entrées")
    print(f"✅ taxonomy_report.json    :")
    print(f"   - complete              : {report['complete']}")
    print(f"   - needs_review          : {len(report['needs_review'])}")
    print(f"   - unknown movement      : {report['unknown_movement_pattern']}")
    print(f"   - unknown equipment     : {report['unknown_equipment']}")
    print(f"   - classified as mobility: {report['classified_as_mobility']}")


if __name__ == "__main__":
    main()