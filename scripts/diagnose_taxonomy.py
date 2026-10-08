#!/usr/bin/env python3
"""Liste les valeurs uniques qui ne sont PAS dans nos maps."""
import json
from collections import Counter
from pathlib import Path

SOURCE = Path("data_source/exercises.json")
dataset = json.load(SOURCE.open())

# Dupliquer ici les maps du script principal
KNOWN_EQUIPMENT = {
    "body weight","bodyweight","assisted","resistance band","band","jump rope",
    "stability ball","bosu ball","medicine ball","dumbbell","kettlebell",
    "ez barbell","barbell","olympic barbell","trap bar","pull-up bar","dip bar",
    "smith machine","cable","lever","machine","sled","skierg","stationary bike",
    "elliptical","treadmill","rowing machine","stepmill","wheel roller","hammer",
}

# Pattern "connu" = au moins un de ces mots apparaît dans le nom
KNOWN_MOVEMENT_HINTS = [
    "press","push-up","push up","dip","fly","flye","raise","extension",
    "overhead","bench press","pushdown","crossover","pec deck","kickback",
    "row","pull-up","pull up","chin-up","chin up","pulldown","curl",
    "face pull","shrug","deadlift","pullover","pull-through","pull apart",
    "squat","hack squat","leg press","goblet","lunge","step-up","step up",
    "split squat","bulgarian","romanian","rdl","hip thrust","glute bridge",
    "swing","good morning","hyperextension","carry","farmer","suitcase",
    "twist","rotation","woodchop","chop","russian twist","oblique",
    "side bend","pallof","windshield","plank","crunch","sit-up","sit up",
    "leg raise","hollow","dead bug","bird dog","ab wheel","v-up","bicycle",
    "mountain climber","toe touch","heel touch","scissor","flutter",
    "toes-to-bar","l-sit","hanging","run","sprint","jump rope","burpee",
    "jumping jack","high knees","bike","rowing","elliptical","treadmill",
    "stepmill","clean","snatch","jerk","thruster","push press",
]

def slug(s):
    import re
    s = s.lower()
    s = re.sub(r"[^a-z0-9\s]", " ", s)
    return re.sub(r"\s+", " ", s).strip()

# ─── Équipements inconnus ───
unknown_eq = Counter()
for ex in dataset:
    eq = slug(ex["equipment"])
    if eq not in KNOWN_EQUIPMENT:
        unknown_eq[ex["equipment"]] += 1

print("═" * 60)
print("🔴 ÉQUIPEMENTS INCONNUS")
print("═" * 60)
for eq, cnt in unknown_eq.most_common():
    print(f"  {cnt:4d}  '{eq}'")

# ─── Mouvements inconnus ───
unknown_mv = []
for ex in dataset:
    name = slug(ex["name"])
    if not any(hint in name for hint in KNOWN_MOVEMENT_HINTS):
        unknown_mv.append((ex["id"], ex["name"], ex["body_part"]))

print()
print("═" * 60)
print(f"🔴 MOUVEMENTS INCONNUS ({len(unknown_mv)}) — premier 60")
print("═" * 60)
for ex_id, name, bp in unknown_mv[:60]:
    print(f"  [{ex_id}] {name:45s}  (bp={bp})")

# ─── Distribution des body_part pour les inconnus ───
print()
print("═" * 60)
print("📊 BODY_PARTS DES MOUVEMENTS INCONNUS")
print("═" * 60)
bp_counter = Counter(bp for _, _, bp in unknown_mv)
for bp, cnt in bp_counter.most_common():
    print(f"  {cnt:4d}  '{bp}'")