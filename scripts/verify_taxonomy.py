#!/usr/bin/env python3
"""
Détecte les classifications suspectes dans exercise_taxonomy.json.
Ne prétend pas tout savoir — vise à faire remonter les cas douteux
pour inspection manuelle.
"""
import json
import re
from pathlib import Path
from collections import Counter

TAX = Path("assets/exercises/exercise_taxonomy.json")
EXS = Path("assets/exercises/exercises.json")

taxonomy = json.load(TAX.open())
exercises = json.load(EXS.open())

# Index par id
by_id = {ex["id"]: ex for ex in exercises}


def slug(s):
    s = s.lower()
    s = re.sub(r"[^a-z0-9\s]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


suspicious = []

for ex_id, t in taxonomy.items():
    ex = by_id.get(ex_id)
    if not ex:
        continue
    name = ex["name"]
    lower = slug(name)
    bp = slug(ex["body_part"])

    # ─── Règle 1 : "curl" mais movementPattern pas pull ───
    if "curl" in lower and t["movementPattern"] != "pull":
        suspicious.append((ex_id, name, "curl→devrait être pull",
                           t["movementPattern"]))

    # ─── Règle 2 : "deadlift/hinge" mais movementPattern pas hinge ───
    if any(k in lower for k in ["deadlift", "romanian", "rdl", "swing"]) \
            and t["movementPattern"] != "hinge":
        suspicious.append((ex_id, name, "deadlift/swing→hinge",
                           t["movementPattern"]))

    # ─── Règle 3 : "squat" mais movementPattern pas squat ───
    if "squat" in lower and "split squat" not in lower \
            and t["movementPattern"] != "squat":
        suspicious.append((ex_id, name, "squat→squat",
                           t["movementPattern"]))

    # ─── Règle 4 : "row" mais movementPattern pas pull ───
    if "row" in lower and "rowing machine" not in lower \
            and "row erg" not in lower \
            and t["movementPattern"] != "pull":
        suspicious.append((ex_id, name, "row→pull",
                           t["movementPattern"]))

    # ─── Règle 5 : "raise" mais movementPattern pas push/pull ───
    if "raise" in lower and t["movementPattern"] not in ("push", "pull"):
        suspicious.append((ex_id, name, "raise→push/pull",
                           t["movementPattern"]))

    # ─── Règle 6 : "extension" mais movementPattern pas push ───
    if "extension" in lower and "back extension" not in lower \
            and "hip extension" not in lower \
            and t["movementPattern"] != "push":
        suspicious.append((ex_id, name, "extension→push",
                           t["movementPattern"]))

    # ─── Règle 7 : "press" mais movementPattern pas push ───
    if "press" in lower and "push press" not in lower \
            and t["movementPattern"] != "push":
        suspicious.append((ex_id, name, "press→push",
                           t["movementPattern"]))

    # ─── Règle 8 : "fly/flye" mais movementPattern pas push ───
    if any(k in lower for k in ["fly", "flye"]) \
            and "rear delt" not in lower \
            and "reverse" not in lower \
            and t["movementPattern"] != "push":
        suspicious.append((ex_id, name, "fly→push",
                           t["movementPattern"]))

    # ─── Règle 9 : "lunge" mais movementPattern pas lunge ───
    if "lunge" in lower and t["movementPattern"] != "lunge":
        suspicious.append((ex_id, name, "lunge→lunge",
                           t["movementPattern"]))

    # ─── Règle 10 : mobility classé en autre chose que core ───
    if "stretch" in lower and t["category"] != "mobility":
        suspicious.append((ex_id, name, "stretch→mobility",
                           t["category"]))

    # ─── Règle 11 : cardio classé en autre chose que cardio ───
    if any(k in lower for k in ["jump rope", "treadmill", "elliptical",
                                 "stationary bike", "rowing machine",
                                 "stepmill", "skierg", "bear crawl"]):
        if t["category"] != "cardio":
            suspicious.append((ex_id, name, "cardio keywords",
                               t["category"]))

# ─── Rapport ───
print("═" * 70)
print(f"⚠️  {len(suspicious)} cas suspects sur {len(taxonomy)}")
print("═" * 70)

# Regroupe par type de suspicion
by_reason = Counter(r for _, _, r, _ in suspicious)
for reason, count in by_reason.most_common():
    print(f"  {count:4d}  {reason}")

print()
print("─" * 70)
print("Détail (premier 80) :")
print("─" * 70)
for ex_id, name, reason, actual in suspicious[:80]:
    print(f"  [{ex_id}] {name[:45]:45s}  {reason:25s} → actuel: {actual}")

# Écrit la liste complète dans un fichier
out = Path("assets/exercises/taxonomy_suspicious.json")
out.write_text(json.dumps([
    {"id": eid, "name": n, "reason": r, "actual": a}
    for eid, n, r, a in suspicious
], ensure_ascii=False, indent=2))
print()
print(f"📄 Liste complète écrite dans {out}")