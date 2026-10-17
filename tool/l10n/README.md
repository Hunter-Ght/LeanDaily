# Language catalogs

The app builds from the committed JSON catalogs; no model, Python installation or online translation service is needed at runtime.

- `dart run tool/l10n/extract.dart`: refresh Simplified Chinese source inventory, including built-in content and native errors. Known UI wording transformations are included. Source IDs and saved Chinese values are not translated in storage.
- Edit `reviewed_en.json` for curated English corrections, then run `python3 tool/l10n/apply_reviewed.py`.
- Run `flutter test test/localization_test.dart` for source coverage, placeholder consistency, language switching, food search, small-screen layouts and AI consent checks.
- To add translations for newly extracted messages, use `translate_local.py` with a local CTranslate2 conversion of `Helsinki-NLP/opus-mt-zh-en` and its `source.spm`/`target.spm`. The initial draft used model revision `cf109095479db38d6df799875e34039d4938aaa6`. Python packages: `ctranslate2`, `sentencepiece`, `opencc-python-reimplemented`. Keep local model weights and caches outside Git.

```sh
python3 tool/l10n/translate_local.py --model /path/to/converted-model --sentencepiece /path/to/tokenizers
python3 tool/l10n/apply_reviewed.py
```

`--refresh` regenerates all drafts; otherwise already packaged messages are retained. Marian inputs must include the EOS token `</s>`. The generated cache is ignored. Curated English is reapplied after generation. Traditional Chinese drafts use OpenCC `s2twp`; edit the packaged Traditional Chinese catalog for regional terminology, and preserve those edits when regenerating.

`LText` is an explicit presentation boundary around legacy Chinese display strings. Use ordinary `Text` for user notes, provider output and license text. Avoid adjacent interpolations and build complete messages rather than concatenating fragments. Never use translated strings for IDs, domain comparisons, JSON keys or stored canonical exercise/food names. Tests verify template placeholders; newly added complex messages still require a visual review.
