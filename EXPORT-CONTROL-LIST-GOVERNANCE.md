# Export-control blocked-jurisdiction list — governance (CZID-322)

How the blocked-jurisdiction list is owned, structured, changed, and validated. The list is the foundation
of the whole geofence (every layer keys off it), so its governance is deliberately strict.

> **Ownership boundary:** the **compliance office / counsel own the list *content*** — which jurisdictions are
> blocked is an OFAC/EAR legal determination. **Engineering owns the *mechanism*** — one source, consumed by
> every layer, validated, versioned, and re-tested on change. This doc is the engineering process; it does not
> decide what's on the list.

---

## The single source

`terraform/export-control/blocked-jurisdictions.json` is the **one** authoritative file. Both enforcement
layers read it — the Layer-1 WAF geo rule (Terraform `jsondecode`, dev/staging/prod) and the Layer-2 edge
Lambda (bundled by `build.sh`). There is no second copy; a change here propagates everywhere.

Structure:

| Field | Meaning |
|---|---|
| `blocked_country_codes` | the **enforced** set — what the WAF + Lambda actually block (the consumers' contract) |
| `rationale` | per-enforced-code `basis` + `note` — why each is blocked (design-doc baseline, **pending counsel confirmation**) |
| `staged_for_counsel` | candidate jurisdictions **not yet enforced** — awaiting a counsel decision |
| `list_version`, `owner`, `last_reviewed` | provenance for the audit trail |

`enforced` and `staged` are disjoint by rule (validated). "Staged" lets counsel stage a candidate (e.g.
Belarus) without it taking effect until they ratify it and it moves into `blocked_country_codes`.

## Changing the list (the procedure)

A list change is a governed event, not a code edit:

1. **Counsel decides** the change (add/remove a jurisdiction, ratify a staged one). Engineering does not.
2. **Edit `blocked_country_codes`** (and `rationale` / `staged_for_counsel`), bump `list_version` + `last_reviewed`.
3. **Validate:** `python3 tools/validate-blocked-jurisdictions.py` — must pass (well-formed codes, every
   enforced code justified, staged disjoint). This runs in the pre-push hook and should be a **required CI check**.
4. **Re-plan** the WAF (`tofu plan` per env) and **rebuild the Lambda** (`terraform/modules/edge-ip-intel/lambda/build.sh`)
   so the bundled list matches.
5. **Re-run the evasion harness** (CZID-333) against the change — confirm the new set is enforced and nothing
   regressed.
6. **Counsel sign-off** on the change (CZID-335), then apply canary → dev → staging → prod (bucket-b).
7. The change + its evidence are retained (CZID-331).

## Validation gate

`tools/validate-blocked-jurisdictions.py` proves the file is **well-formed**, not legally correct:

- each code is a 2-letter uppercase code, no duplicates;
- every enforced code has a written `rationale.basis`;
- `staged_for_counsel` never overlaps the enforced set;
- with the optional `pycountry` package installed, codes are checked against the official ISO-3166-1 alpha-2
  set (otherwise format-only — the codes are counsel-ratified regardless).

Making this check **required on the branch** is a repo-admin setting (same category as the `main` branch
protection) — engineering can't flip it.

## Review cadence

Tied to the IR runbook (CZID-334): on every counsel list change, and at the quarterly control-effectiveness
review, re-validate the file, re-run the harness, and re-confirm the enforced set still matches counsel's
current determination. The list drifts as sanctions change — periodic re-confirmation is part of the
"reasonable measures" standard.

## What still needs a person

- **Counsel:** the list content + each `basis`; ratifying staged entries; the go-live/list-change sign-off (CZID-335).
- **Repo admin:** make the validator a required CI status check on the branch.
- **Engineering:** keeps the single source + validator + re-test loop working (this doc).
