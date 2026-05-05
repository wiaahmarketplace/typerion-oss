#!/usr/bin/env python3
"""
Hacky-targeted parser : Cal.com schema.prisma → Typerion SimpleIR.

Scope :
  - Models only (skip enums — SimpleIR doesn't model enums)
  - Scalar fields and foreign-key columns (skip relation fields, which
    would all read as excludeFromSql=true and flood the output)
  - Maps Prisma types to SimpleIR types : String/String?→string,
    Int/BigInt/Float/Decimal→number, Boolean→boolean,
    DateTime→date, Json→json, ENUM/MODEL→string (since SimpleIR
    doesn't differentiate), arrays → skip

Output : SimpleIR-compatible JSON with all parsed entities.
"""

import json
import re
import sys
from pathlib import Path

PRISMA_TO_SIMPLE = {
    "String":   "string",
    "Int":      "number",
    "BigInt":   "number",
    "Float":    "number",
    "Decimal":  "number",
    "Boolean":  "boolean",
    "DateTime": "date",
    "Json":     "json",
    "Bytes":    "string",
}

# Heuristic : ENUM names start with uppercase but are not in the prisma
# scalar set. We collect enum names first so we can map them to "string".
def collect_enum_names(text):
    return set(re.findall(r"^enum\s+(\w+)\s*\{", text, re.M))

# Heuristic : a relation field has @relation(...) on the same line.
# A scalar foreign-key column does not.
RELATION_RE = re.compile(r"@relation\(")

# Match a field line within a model :
#   "  fieldName  Type  @attr1 @attr2..."
# Group 1 : field name
# Group 2 : type (with optional ? or [])
# Group 3 : rest of line (attributes)
FIELD_RE = re.compile(r"^\s+(\w+)\s+([\w\[\]\?]+)(.*)$")

# Match @map("xxx") or @map(name: "xxx")
MAP_RE = re.compile(r'@map\(\s*(?:name\s*:\s*)?"([^"]+)"\s*\)')


def parse_model_block(name, lines, enum_names):
    """Parse the lines inside a `model X { ... }` block into SimpleIR fields.

    Returns a list of field dicts compatible with Typerion SimpleIR.
    """
    fields = []
    for line in lines:
        line = line.rstrip()
        if not line.strip():
            continue
        if line.strip().startswith("//"):
            continue
        if line.strip().startswith("@@"):
            continue  # composite key / index / unique — model-level

        m = FIELD_RE.match(line)
        if not m:
            continue

        field_name, raw_type, rest = m.group(1), m.group(2), m.group(3)

        # Skip array fields (e.g. `eventTypes EventType[]`) — these are
        # always relations or scalar lists which Postgres handles via
        # arrays ; SimpleIR doesn't model arrays.
        if raw_type.endswith("[]"):
            continue

        # Skip relation fields (they're TS-only references, not SQL columns).
        # We keep the foreign-key column itself (e.g. `userId Int`).
        if RELATION_RE.search(rest):
            continue

        # Strip `?` for nullable inspection (SimpleIR doesn't track nullability).
        base_type = raw_type.rstrip("?")

        # Map Prisma type to SimpleIR type.
        if base_type in PRISMA_TO_SIMPLE:
            simple_type = PRISMA_TO_SIMPLE[base_type]
        elif base_type in enum_names:
            simple_type = "string"  # SimpleIR doesn't model enums
        else:
            # An unknown UpperCase type — could be a model reference (a
            # scalar reference column would have been caught upstream by
            # the relation-skip ; this branch is unreachable in practice
            # but defensive).
            simple_type = "string"

        field_obj = {"name": field_name, "type": simple_type}

        # Detect @map for SQL-side column-name override.
        map_match = MAP_RE.search(rest)
        if map_match:
            field_obj["sqlName"] = map_match.group(1)

        fields.append(field_obj)

    return fields


def parse_schema(path):
    text = Path(path).read_text(encoding="utf-8")
    enum_names = collect_enum_names(text)

    entities = []

    # Find each model block
    model_pattern = re.compile(r"^model\s+(\w+)\s*\{$", re.M)
    for match in model_pattern.finditer(text):
        model_name = match.group(1)
        start = match.end()
        # Find matching closing brace at column 0
        end_match = re.search(r"^\}\s*$", text[start:], re.M)
        if not end_match:
            continue
        block = text[start : start + end_match.start()]
        block_lines = block.splitlines()
        fields = parse_model_block(model_name, block_lines, enum_names)
        if fields:  # only keep models with at least one parsed field
            entities.append({"name": model_name, "fields": fields})

    return entities


def main():
    if len(sys.argv) < 2:
        print("usage: parse-prisma.py <schema.prisma>", file=sys.stderr)
        sys.exit(64)

    entities = parse_schema(sys.argv[1])
    total_fields = sum(len(e["fields"]) for e in entities)
    fields_with_map = sum(
        1 for e in entities for f in e["fields"] if "sqlName" in f
    )

    print(
        f"Parsed {len(entities)} entities, "
        f"{total_fields} scalar fields total, "
        f"{fields_with_map} with @map (sqlName divergence).",
        file=sys.stderr,
    )

    payload = {
        "baseline": {
            "kind": "lossy-inline",
            "value": {"entities": []},
        },
        "candidate": {
            "kind": "lossy-inline",
            "value": {"entities": entities},
        },
    }
    print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    main()
