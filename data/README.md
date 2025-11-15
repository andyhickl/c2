CSV schema for concept2-season-2026.csv

Place CSV files in the repository (e.g. `concept2-season-2026.csv` or under `data/`) and open `new.html` from a server so the page can fetch the CSV and seed the calendar.

Expected columns (header row, case-insensitive):

- date: required. Date of the workout. Prefer ISO format `YYYY-MM-DD`. Other common formats (e.g. `MM/DD/YYYY`) may be parsed but ISO is recommended.
- distance: required. Distance in meters (e.g. `10000` or `10,000`). Other column names accepted: `m`, `meters`, `distance(m)`.
- time / duration / total time: required. Total time for the workout in `hh:mm:ss`, `mm:ss`, or seconds. Column header examples: `time`, `duration`, `total time`, `total_time`.
- threshold: optional. Threshold split in `mm:ss` (per 500m) if available.

Behavior

- When `new.html` loads, it will attempt to fetch `concept2-season-2026.csv` from the site root and seed the calendar.
- Seeding replaces any existing entries whose dates fall inside the CSV's min..max date range.
- Rows without a valid `date`, or missing `distance` or `time` values, will be skipped.
- Existing entries with dates outside the CSV's range are preserved.

Example CSV (header + one row):

```
date,distance,time,threshold
2026-03-01,10000,0:51:11,2:34
```

Notes

- To test locally, serve the folder (so `fetch` can load the CSV) e.g.:

```bash
python3 -m http.server 8000
# then open http://localhost:8000/new.html
```

- If you prefer merging instead of replacing on load, edit `new.html` and change the seed behavior to use `replaceRange: false`.
