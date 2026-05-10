Backfill selectedLanguage for /leaderboard docs

This folder contains an admin script to populate missing `selectedLanguage` fields
in the `/leaderboard` collection by copying the value from `/users/{uid}`.

Prereqs
- Install Python 3.8+
- `pip install google-cloud-firestore`
- Create a GCP service account JSON key with Firestore access
- Set `GOOGLE_APPLICATION_CREDENTIALS` to the key file path

Dry-run (recommended first):

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
python tools/backfill_leaderboard_selected_language.py --dry-run --limit 500
```

Apply changes:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
python tools/backfill_leaderboard_selected_language.py --limit 500
```

Notes
- Use `--limit 0` to scan all leaderboard docs (may be slow/expensive).
- The script updates only leaderboard docs where `selectedLanguage` is missing/empty
  and where `users/{uid}` contains a non-empty `selectedLanguage`.
- Run from a secure environment — service account keys are sensitive.
