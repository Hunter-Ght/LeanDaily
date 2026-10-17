"""Merge curated UI copy after generating local drafts. Run from repository root."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
source = json.loads((root / 'tool/l10n/source.json').read_text())
english = json.loads((root / 'assets/l10n/en.json').read_text())
english.update(json.loads((root / 'tool/l10n/reviewed_en.json').read_text()))
(root / 'assets/l10n/en.json').write_text(json.dumps(english, ensure_ascii=False, indent=2) + '\n')
missing = [s for s in source if s not in english]
if missing:
    print(f'Missing English messages: {len(missing)}')
    raise SystemExit(1)
print(f'English catalog: {len(english)} entries, complete source coverage')
