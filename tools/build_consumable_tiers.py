#!/usr/bin/env python3
"""
Build data/consumable_tiers.lua: the healing and mana potion lines and the
bandage line, weakest to strongest, so MakeSpace can name the best one for you.

Nothing here is ranked by hand. Every number comes from the game's own tables
for one build: what an item restores (its use spell), whether it can be traded,
the level it needs. A potion tier is the potions that share a name ("Greater
Healing Potion"), so the several item IDs a tier can have (crafted, vendor,
a new Forever version) all count as that tier.

Rules that keep it safe to show a suggestion:
  - Only items that are not bind-on-pickup. A potion you cannot trade is not a
    suggestion you can act on.
  - A tier's level is the highest level any of its items needs, so a tier is only
    suggested once every version of it is usable.
  - Bandages must need no level (so PvP battleground bandages are out) and have a
    recipe, which is how MakeSpace knows whether you have learned it.
  - The lines must get stronger tier by tier. If they do not, nothing is written.

Usage:
    python3 tools/build_consumable_tiers.py --build 1.60.1.70862 --cache-dir tools/source
    python3 tools/build_consumable_tiers.py --selftest        (no network)

--cache-dir keeps the downloaded tables (one folder per build). The report it
prints lists every item in every tier, so odd data shows up before it ships.

Requirements: Python 3.8+, stdlib only.
"""

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_reagent_professions as base  # noqa: E402
import build_mana_consumables as mana  # noqa: E402

TABLES = ["Item", "ItemSparse", "ItemEffect", "SpellEffect", "SkillLineAbility"]
OPTIONAL_TABLES = ["ItemXItemEffect"]

CONSUMABLE_CLASS = 0
FIRST_AID_SKILL_LINE = 129
BIND_ON_PICKUP = 1
EFFECT_HEAL = 10
EFFECT_ENERGIZE = 30
EFFECT_APPLY_AURA = 6
AURA_PERIODIC_HEAL = 8

# Weakest to strongest. A potion with no prefix sits between Lesser and Greater.
POTION_PREFIXES = ["Minor", "Lesser", "", "Greater", "Superior", "Major"]
POTION_NAME_RE = re.compile(r"^(?:(Minor|Lesser|Greater|Superior|Major) )?(Healing|Mana) Potion$")
BANDAGE_NAME_RE = re.compile(r"^(?:(?:Heavy )?(?:Linen|Wool|Silk|Mageweave|Runecloth)|Dense Runecloth) Bandage$")
BANDAGE_MIN_COUNT = 6   # the ten classic bandages; fewer means the data is off
OUT_FILE = os.path.join("data", "consumable_tiers.lua")


class Unsorted(Exception):
    pass


def parse_effect_amounts(rows):
    """Return {spellID: {"heal": (low, high), "mana": (low, high), "tick": amount}}.

    heal and mana are instant restores; tick is what one tick of a periodic heal
    (a bandage) gives, enough to put bandages in order.
    """
    spell = mana.find_column(rows, "SpellEffect", "SpellID")
    effect = mana.find_column(rows, "SpellEffect", "Effect")
    aura = mana.find_column(rows, "SpellEffect", "EffectAura", required=False)
    points = mana.find_column(rows, "SpellEffect", "EffectBasePoints", "EffectBasePointsF")
    sides = mana.find_column(rows, "SpellEffect", "EffectDieSides", required=False)
    difficulty = mana.find_column(rows, "SpellEffect", "DifficultyID", required=False)
    result = {}
    for row in rows:
        if difficulty and mana.to_int(row.get(difficulty)) != 0:
            continue
        spell_id = mana.to_int(row.get(spell))
        if spell_id <= 0:
            continue
        kind = mana.to_int(row.get(effect))
        floor = mana.to_int(row.get(points)) + 1
        ceiling = mana.to_int(row.get(points)) + max(mana.to_int(row.get(sides)) if sides else 0, 1)
        entry = result.setdefault(spell_id, {})
        if kind == EFFECT_HEAL:
            entry["heal"] = (floor, ceiling)
        elif kind == EFFECT_ENERGIZE:
            entry["mana"] = (floor, ceiling)
        elif kind == EFFECT_APPLY_AURA and aura and mana.to_int(row.get(aura)) == AURA_PERIODIC_HEAL:
            entry["tick"] = floor
    return result


def parse_item_facts(item_rows, sparse_rows):
    """Return {itemID: {"name", "class", "level", "bonding"}} for every item."""
    item_id = mana.find_column(item_rows, "Item", "ID")
    klass = mana.find_column(item_rows, "Item", "ClassID")
    classes = {mana.to_int(r.get(item_id)): mana.to_int(r.get(klass)) for r in item_rows}

    sparse_id = mana.find_column(sparse_rows, "ItemSparse", "ID")
    name = mana.find_column(sparse_rows, "ItemSparse", "Display_lang", "Display")
    level = mana.find_column(sparse_rows, "ItemSparse", "RequiredLevel")
    bonding = mana.find_column(sparse_rows, "ItemSparse", "Bonding")
    facts = {}
    for row in sparse_rows:
        iid = mana.to_int(row.get(sparse_id))
        if iid <= 0 or iid not in classes:
            continue
        facts[iid] = {"name": row.get(name) or "", "class": classes[iid],
                      "level": mana.to_int(row.get(level)), "bonding": mana.to_int(row.get(bonding))}
    return facts


def potion_tiers(facts, item_effects, amounts):
    """{"health": [tier, ...], "mana": [tier, ...]} with each tier
    {"name", "level", "ids", "average", "items": [(id, level, low, high), ...]}."""
    found = {"Healing": {}, "Mana": {}}
    for item_id, spells in item_effects.items():
        info = facts.get(item_id)
        if not info or info["class"] != CONSUMABLE_CLASS or info["bonding"] == BIND_ON_PICKUP:
            continue
        match = POTION_NAME_RE.match(info["name"])
        if not match:
            continue
        prefix, line = match.group(1) or "", match.group(2)
        heal = mana_amount = None
        for spell_id in spells:
            entry = amounts.get(spell_id, {})
            heal = heal or entry.get("heal")
            mana_amount = mana_amount or entry.get("mana")
        # A Healing Potion restores health only, a Mana Potion mana only.
        restore = heal if line == "Healing" else mana_amount
        other = mana_amount if line == "Healing" else heal
        if not restore or other:
            continue
        found[line].setdefault(prefix, []).append((item_id, info["level"], restore[0], restore[1]))

    lines = {}
    for line, key in (("Healing", "health"), ("Mana", "mana")):
        tiers = []
        for prefix in POTION_PREFIXES:
            items = sorted(found[line].get(prefix, []))
            if not items:
                continue
            name = ("%s %s Potion" % (prefix, line)).replace("  ", " ").strip()
            average = max((low + high) / 2.0 for _, _, low, high in items)
            tiers.append({"name": name, "level": max(level for _, level, _, _ in items),
                          "ids": [i for i, _, _, _ in items], "average": average, "items": items})
        check_rising(tiers, key)
        lines[key] = tiers
    return lines


def bandage_line(facts, item_effects, amounts, recipes):
    """The bandages weakest to strongest: {"name", "id", "recipe", "tick"}.

    recipes: {itemID: recipe spell ID} for First Aid recipes.
    """
    bandages = []
    for item_id, spells in item_effects.items():
        info = facts.get(item_id)
        if not info or info["class"] != CONSUMABLE_CLASS or info["bonding"] == BIND_ON_PICKUP:
            continue
        if info["level"] != 0 or not BANDAGE_NAME_RE.match(info["name"]):
            continue
        tick = max((amounts.get(s, {}).get("tick", 0) for s in spells), default=0)
        recipe = recipes.get(item_id)
        if tick <= 0 or not recipe:
            continue
        bandages.append({"name": info["name"], "id": item_id, "recipe": recipe, "tick": tick})
    bandages.sort(key=lambda b: (b["tick"], b["id"]))
    check_rising(bandages, "bandage", value="tick")
    return bandages


def check_rising(tiers, label, value="average"):
    """Each tier must restore more than the one before, or the order is wrong."""
    for before, after in zip(tiers, tiers[1:]):
        if not after[value] > before[value]:
            raise Unsorted("%s line is not rising: %s (%s) is not above %s (%s)"
                           % (label, after["name"], after[value], before["name"], before[value]))


def recipe_spells(ability_rows, spell_products):
    """{itemID: spellID} for the First Aid recipes that make an item."""
    skill = mana.find_column(ability_rows, "SkillLineAbility", "SkillLine")
    spell = mana.find_column(ability_rows, "SkillLineAbility", "Spell")
    result = {}
    for row in ability_rows:
        if mana.to_int(row.get(skill)) != FIRST_AID_SKILL_LINE:
            continue
        spell_id = mana.to_int(row.get(spell))
        item_id = spell_products.get(spell_id)
        if item_id:
            result[item_id] = spell_id
    return result


def render_lua(potions, bandages, build):
    out = [
        "-- MakeSpace: the healing and mana potion lines and the bandage line, weakest to",
        "-- strongest, so a hint can name the best one you can use.",
        "-- Generated by tools/build_consumable_tiers.py from game data build %s." % build,
        "-- Do not edit by hand.",
        "--",
        "-- Potions: one entry per tier. A tier is every tradeable item sharing the name,",
        "-- and `level` is the highest level any of them needs.",
        "-- Bandages: `recipe` is the First Aid recipe spell, which is how the addon knows",
        "-- whether you have learned it.",
        "",
        "MakeSpace      = MakeSpace or {}",
        "MakeSpace.Data = MakeSpace.Data or {}",
        "",
        "MakeSpace.Data.ConsumableTiers = {",
        "  potions = {",
    ]
    for key in ("health", "mana"):
        out.append("    %s = {" % key)
        for tier in potions[key]:
            out.append('      { name = "%s", level = %d, ids = { %s } },'
                       % (tier["name"], tier["level"], ", ".join(str(i) for i in tier["ids"])))
        out.append("    },")
    out.append("  },")
    out.append("  bandages = {")
    for b in bandages:
        out.append('    { name = "%s", id = %d, recipe = %d },' % (b["name"], b["id"], b["recipe"]))
    out.append("  },")
    out.append("}")
    out.append("")
    return "\n".join(out)


def report(potions, bandages):
    lines = []
    for key in ("health", "mana"):
        lines.append("%s potions:" % key)
        for tier in potions[key]:
            lines.append("  %-22s needs level %-3d" % (tier["name"], tier["level"]))
            for item_id, level, low, high in tier["items"]:
                lines.append("      %-8d level %-3d restores %d to %d" % (item_id, level, low, high))
    lines.append("bandages:")
    for b in bandages:
        lines.append("  %-26s id %-7d recipe spell %-7d heals %d a tick" % (b["name"], b["id"], b["recipe"], b["tick"]))
    return "\n".join(lines)


def run(tables, build, out_path):
    amounts = parse_effect_amounts(tables["SpellEffect"])
    item_effects = mana.parse_item_effects(tables["ItemEffect"], tables.get("ItemXItemEffect"))
    facts = parse_item_facts(tables["Item"], tables["ItemSparse"])
    recipes = recipe_spells(tables["SkillLineAbility"], base.parse_spell_products(tables["SpellEffect"]))

    potions = potion_tiers(facts, item_effects, amounts)
    bandages = bandage_line(facts, item_effects, amounts, recipes)
    print(report(potions, bandages))
    for key in ("health", "mana"):
        if len(potions[key]) < 4:
            raise Unsorted("only %d %s potion tiers found, the data looks wrong" % (len(potions[key]), key))
    if len(bandages) < BANDAGE_MIN_COUNT:
        raise Unsorted("only %d bandages found, the data looks wrong" % len(bandages))
    out_dir = os.path.dirname(out_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    with open(out_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(render_lua(potions, bandages, build))
    print("Wrote %s" % out_path)
    return potions, bandages


def selftest():
    """Run the logic on a small made-up dataset. No network."""
    def sp(spell, effect, base_points, sides=0, aura=0):
        return {"SpellID": spell, "Effect": effect, "EffectBasePoints": base_points, "EffectDieSides": sides,
                "EffectAura": aura, "EffectItemType": 0, "DifficultyID": 0, "EffectMiscValue_0": 0,
                "EffectTriggerSpell": 0}

    def create(spell, item):
        return dict(sp(spell, 24, 0), EffectItemType=item)

    spell_effect = [
        sp(1, EFFECT_HEAL, 69, 21), sp(2, EFFECT_HEAL, 139, 41), sp(3, EFFECT_HEAL, 279, 81),
        sp(4, EFFECT_HEAL, 1349, 301),                       # a stronger, bind-on-pickup Major
        sp(5, EFFECT_HEAL, 1049, 701),                       # the tradeable Major
        sp(6, EFFECT_ENERGIZE, 139, 41), sp(7, EFFECT_ENERGIZE, 279, 81),
        sp(8, EFFECT_HEAL, 99, 1), sp(8, EFFECT_ENERGIZE, 99, 1),   # rejuvenation: both
        sp(10, EFFECT_APPLY_AURA, 9, 1, AURA_PERIODIC_HEAL),
        sp(11, EFFECT_APPLY_AURA, 17, 1, AURA_PERIODIC_HEAL),
        sp(12, EFFECT_APPLY_AURA, 22, 1, AURA_PERIODIC_HEAL),
        sp(13, EFFECT_APPLY_AURA, 22, 1, AURA_PERIODIC_HEAL),
        create(101, 1100), create(102, 1101), create(103, 1102),
    ]

    def item(item_id, name, level=0, bonding=0, klass=0):
        return ({"ID": item_id, "ClassID": klass},
                {"ID": item_id, "Display_lang": name, "RequiredLevel": level, "Bonding": bonding})

    rows = [item(1, "Minor Healing Potion", 1), item(2, "Lesser Healing Potion", 3),
            item(3, "Healing Potion", 12), item(4, "Major Healing Potion", 40, bonding=1),
            item(5, "Major Healing Potion", 45), item(15, "Major Healing Potion", 20),
            item(6, "Minor Mana Potion", 5), item(7, "Lesser Mana Potion", 14),
            item(8, "Minor Rejuvenation Potion", 5), item(9, "Healing Potion", 12, klass=7),
            item(1100, "Linen Bandage"), item(1101, "Heavy Linen Bandage"),
            item(1102, "Warsong Gulch Linen Bandage", 25), item(1103, "Wool Bandage"),
            item(1104, "Silk Bandage", 0, bonding=1)]
    item_rows = [r[0] for r in rows]
    sparse_rows = [r[1] for r in rows]
    item_effect = [{"ParentItemID": 1, "SpellID": 1}, {"ParentItemID": 2, "SpellID": 2},
                   {"ParentItemID": 3, "SpellID": 3}, {"ParentItemID": 4, "SpellID": 4},
                   {"ParentItemID": 5, "SpellID": 5}, {"ParentItemID": 15, "SpellID": 5},
                   {"ParentItemID": 6, "SpellID": 6}, {"ParentItemID": 7, "SpellID": 7},
                   {"ParentItemID": 8, "SpellID": 8}, {"ParentItemID": 9, "SpellID": 3},
                   {"ParentItemID": 1100, "SpellID": 10}, {"ParentItemID": 1101, "SpellID": 11},
                   {"ParentItemID": 1102, "SpellID": 12}, {"ParentItemID": 1103, "SpellID": 12},
                   {"ParentItemID": 1104, "SpellID": 13}]
    ability = [{"SkillLine": FIRST_AID_SKILL_LINE, "Spell": 101}, {"SkillLine": FIRST_AID_SKILL_LINE, "Spell": 102},
               {"SkillLine": 164, "Spell": 103}]

    amounts = parse_effect_amounts(spell_effect)
    assert amounts[1]["heal"] == (70, 90) and amounts[6]["mana"] == (140, 180), amounts
    assert amounts[10]["tick"] == 10, amounts[10]
    facts = parse_item_facts(item_rows, sparse_rows)
    effects = mana.parse_item_effects(item_effect)
    potions = potion_tiers(facts, effects, amounts)
    health = [(t["name"], t["level"], t["ids"]) for t in potions["health"]]
    # the bind-on-pickup Major and the wrong-class "Healing Potion" are out; the
    # tier takes the highest level any tradeable version needs
    assert health == [("Minor Healing Potion", 1, [1]), ("Lesser Healing Potion", 3, [2]),
                      ("Healing Potion", 12, [3]), ("Major Healing Potion", 45, [5, 15])], health
    assert [t["name"] for t in potions["mana"]] == ["Minor Mana Potion", "Lesser Mana Potion"]
    # a potion that restores health and mana is no part of either line
    assert all(8 not in t["ids"] for line in potions.values() for t in line)

    recipes = recipe_spells(ability, {101: 1100, 102: 1101, 103: 1102})
    assert recipes == {1100: 101, 1101: 102}, recipes
    # the PvP bandage (needs a level), the one with no recipe and the bind-on-pickup one are out
    bandages = bandage_line(facts, effects, amounts, recipes)
    assert [b["name"] for b in bandages] == ["Linen Bandage", "Heavy Linen Bandage"], bandages
    assert bandages[0]["recipe"] == 101

    # a line that does not get stronger refuses to be written
    bad = [{"name": "Lesser", "average": 100.0}, {"name": "Greater", "average": 90.0}]
    try:
        check_rising(bad, "health")
    except Unsorted:
        pass
    else:
        raise AssertionError("an unsorted line was accepted")

    lua = render_lua(potions, bandages, "selftest")
    assert '{ name = "Major Healing Potion", level = 45, ids = { 5, 15 } },' in lua, lua
    assert '{ name = "Linen Bandage", id = 1100, recipe = 101 },' in lua, lua

    # newer builds link items to effects through ItemXItemEffect
    linked = mana.parse_item_effects(
        [{"ID": 71, "SpellID": 1}], [{"ID": 1, "ItemID": 1, "ItemEffectID": 71}])
    assert linked == {1: [1]}, linked
    print("build_consumable_tiers selftest ok")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--build", help="exact build (default: latest Forever build)")
    ap.add_argument("--cache-dir", help="keep downloaded tables here (one folder per build)")
    ap.add_argument("--output", "-o", default=OUT_FILE, help="where to write the Lua file")
    ap.add_argument("--selftest", action="store_true", help="check the logic offline")
    args = ap.parse_args()
    if args.selftest:
        selftest()
        return

    build = args.build or base.resolve_build("forever")
    print("Build: %s" % build)
    tables = {name: base.fetch_csv_table(name, build, args.cache_dir) for name in TABLES}
    for name in OPTIONAL_TABLES:
        try:
            tables[name] = base.fetch_csv_table(name, build, args.cache_dir)
        except SystemExit:
            print("  %s is not available for this build, continuing without it." % name)
    try:
        run(tables, build, args.output)
    except (mana.MissingColumns, Unsorted) as err:
        print("\nStopped, nothing written: %s" % err)
        print("Send this message back and it gets fixed.")
        sys.exit(1)


if __name__ == "__main__":
    main()
