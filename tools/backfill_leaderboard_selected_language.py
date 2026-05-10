#!/usr/bin/env python3
"""
Backfill `selectedLanguage` in `/leaderboard/{uid}` from `/users/{uid}`.

Usage:
  export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
  python tools/backfill_leaderboard_selected_language.py --dry-run --limit 100

This script will read leaderboard docs (optionally limited), check if
`selectedLanguage` is missing or empty, read the corresponding users/{uid}
doc, and if that has a `selectedLanguage` value, update the leaderboard
doc with the normalized language.

Be careful: run without `--dry-run` to apply changes. Requires Firestore
Admin credentials (service account) with read/write access to the project.
"""
import argparse
import sys
from typing import Optional

from google.cloud import firestore


def normalize_lang(v: Optional[str]) -> Optional[str]:
    if v is None:
        return None
    s = str(v).strip().lower()
    return s if s != "" else None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", help="GCP project id (optional)")
    parser.add_argument("--limit", type=int, default=500, help="Max leaderboard docs to scan (0 = all)")
    parser.add_argument("--dry-run", action="store_true", help="Do not perform writes; show planned updates")
    parser.add_argument("--batch-size", type=int, default=200, help="Writes per batch commit")
    args = parser.parse_args()

    client = firestore.Client(project=args.project) if args.project else firestore.Client()

    print("Connected to Firestore project:", client.project)

    coll = client.collection("leaderboard")
    query = coll.order_by("totalXP", direction=firestore.Query.DESCENDING)
    if args.limit > 0:
        docs = query.limit(args.limit).stream()
    else:
        docs = query.stream()

    updates = []
    count = 0
    for d in docs:
        count += 1
        data = d.to_dict() or {}
        uid = d.id
        lb_lang = normalize_lang(data.get("selectedLanguage"))
        if lb_lang:
            continue

        # try to read users/{uid}
        try:
            user_doc = client.collection("users").document(uid).get()
        except Exception as e:
            print(f"[{uid}] error reading users/{uid}: {e}")
            continue

        if not user_doc.exists:
            print(f"[{uid}] users doc not found; skipping")
            continue

        user_data = user_doc.to_dict() or {}
        user_lang = normalize_lang(user_data.get("selectedLanguage"))
        if not user_lang:
            print(f"[{uid}] users.selectedLanguage empty; skipping")
            continue

        print(f"[{uid}] will set leaderboard.selectedLanguage = {user_lang}")
        updates.append((uid, user_lang))

    if not updates:
        print("No updates needed.")
        return

    print(f"Planned updates: {len(updates)}")
    if args.dry_run:
        print("Dry run mode — no writes performed.")
        return

    # commit in batches
    batch = client.batch()
    committed = 0
    for i, (uid, lang) in enumerate(updates, start=1):
        doc_ref = client.collection("leaderboard").document(uid)
        batch.update(doc_ref, {"selectedLanguage": lang})
        if i % args.batch_size == 0:
            batch.commit()
            committed += args.batch_size
            print(f"Committed {committed} updates...")
            batch = client.batch()

    # commit remainder
    try:
        batch.commit()
        print(f"Committed remaining updates. Total planned: {len(updates)}")
    except Exception as e:
        print("Error committing batch:", e)
        sys.exit(2)


if __name__ == "__main__":
    main()
