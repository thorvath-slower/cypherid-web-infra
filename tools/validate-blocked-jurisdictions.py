#!/usr/bin/env python3
"""CZID-322 — validate export-control/blocked-jurisdictions.json (governance gate).

Proves the single-source blocked-jurisdiction list (consumed by the Layer-1 WAF and the Layer-2 Lambda)
is well-formed and internally consistent. Run it before committing a list change and in CI; a non-zero
exit means the file is invalid and must not be enforced.

Checks:
  - required fields present: schema_version, list_version, owner, blocked_country_codes;
  - each code is 2 uppercase ASCII letters; no duplicates in the enforced set;
  - every enforced code has a rationale with a non-empty 'basis' (each blocked country is justified);
  - staged_for_counsel codes are well-formed and DISJOINT from the enforced set (staged != enforced).

ISO-3166 membership: if the optional 'pycountry' package is installed, codes are additionally checked
against the official ISO-3166-1 alpha-2 set; otherwise the run is format-only. This gate proves the file
is well-formed — it does NOT decide the list content, which is counsel-owned (CZID-322).
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT = os.path.normpath(
    os.path.join(HERE, "..", "terraform", "export-control", "blocked-jurisdictions.json")
)
CODE_RE = re.compile(r"^[A-Z]{2}$")


def iso_alpha2():
    """Official ISO-3166-1 alpha-2 set from pycountry, or None if it isn't installed."""
    try:
        import pycountry
        return {c.alpha_2 for c in pycountry.countries}
    except Exception:
        return None


def main(path):
    with open(path) as f:
        d = json.load(f)
    errors = []
    iso = iso_alpha2()

    for field in ("schema_version", "list_version", "owner", "blocked_country_codes"):
        if field not in d:
            errors.append(f"missing required field: {field}")

    enforced = d.get("blocked_country_codes") or []
    if not isinstance(enforced, list) or not enforced:
        errors.append("blocked_country_codes must be a non-empty list")
        enforced = enforced if isinstance(enforced, list) else []

    seen = set()
    for c in enforced:
        if not isinstance(c, str) or not CODE_RE.match(c):
            errors.append(f"enforced code not 2 uppercase letters: {c!r}")
            continue
        if c in seen:
            errors.append(f"duplicate enforced code: {c}")
        seen.add(c)
        if iso is not None and c not in iso:
            errors.append(f"enforced code not a valid ISO-3166-1 alpha-2: {c}")

    rationale = d.get("rationale", {})
    for c in enforced:
        r = rationale.get(c)
        if not isinstance(r, dict) or not r.get("basis"):
            errors.append(f"enforced code {c} has no rationale.basis (every enforced country must be justified)")

    staged = d.get("staged_for_counsel", {})
    for c in staged:
        if not CODE_RE.match(c):
            errors.append(f"staged code not 2 uppercase letters: {c!r}")
            continue
        if c in seen:
            errors.append(f"{c} is in BOTH staged_for_counsel and blocked_country_codes — staged must not be enforced")
        if iso is not None and c not in iso:
            errors.append(f"staged code not a valid ISO-3166-1 alpha-2: {c}")

    if iso is None:
        print("warning: pycountry not installed — ISO-3166 membership not checked (format-only). "
              "`pip install pycountry` for the full check.")

    if errors:
        print(f"INVALID {path}:")
        for e in errors:
            print(f"  - {e}")
        return 1

    print(f"OK {path}")
    print(f"  enforced ({len(enforced)}): {', '.join(enforced)}")
    print(f"  staged   ({len(staged)}): {', '.join(staged) or '(none)'}")
    print(f"  version {d.get('list_version')} | owner {d.get('owner')} | "
          f"ISO check: {'on (pycountry)' if iso else 'format-only'}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else DEFAULT))
