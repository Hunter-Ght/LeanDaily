"""Generate local translation drafts; no app text is sent to an online service.
Requires ctranslate2, sentencepiece, opencc-python-reimplemented.
Drafts must be reviewed; curated overrides live in reviewed.json.
"""
import argparse,json,re,time
from pathlib import Path
import ctranslate2,sentencepiece
from opencc import OpenCC
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--model',required=True,type=Path,help='Converted CTranslate2 model directory')
parser.add_argument('--sentencepiece',required=True,type=Path,help='Directory containing source.spm and target.spm')
parser.add_argument('--refresh',action='store_true',help='Regenerate all drafts instead of only new messages')
args=parser.parse_args()
model=args.model
spm=args.sentencepiece
source=sentencepiece.SentencePieceProcessor(model_file=str(spm/'source.spm'))
target=sentencepiece.SentencePieceProcessor(model_file=str(spm/'target.spm'))
translator=ctranslate2.Translator(str(model),device='cpu',compute_type='int8',inter_threads=1,intra_threads=4)
values=json.loads(Path('tool/l10n/source.json').read_text())

cache=Path('tool/l10n/draft_en.json')
translations={} if args.refresh else json.loads((cache if cache.exists() else Path('assets/l10n/en.json')).read_text())
cc=OpenCC('s2twp')
traditional={} if args.refresh else json.loads(Path('assets/l10n/zh_Hant.json').read_text())
for s in values: traditional.setdefault(s,cc.convert(s))
Path('assets/l10n/zh_Hant.json').write_text(json.dumps(traditional,ensure_ascii=False,indent=2)+'\n')
remaining=[s for s in values if s not in translations]
# Translate placeholder-free fragments to keep every variable byte-for-byte.
# Curated whole-message overrides restore natural word order for UI templates.
fragments=list(dict.fromkeys(part for s in remaining for part in re.split(r'(\{p\d+\})',s) if re.search('[\u4e00-\u9fff]',part)))
fragment_map={}
for start in range(0,len(fragments),24):
 batch=fragments[start:start+24]
 encoded=[source.encode(s,out_type=str)+['</s>'] for s in batch]
 results=translator.translate_batch(encoded,beam_size=3,max_decoding_length=220)
 for s,r in zip(batch,results): fragment_map[s]=target.decode(r.hypotheses[0])
 for s in remaining:
  parts=re.split(r'(\{p\d+\})',s)
  if all(not re.search('[\u4e00-\u9fff]',p) or p in fragment_map for p in parts):
   translations[s]=''.join(fragment_map.get(p,p) for p in parts)
 cache.write_text(json.dumps(translations,ensure_ascii=False,indent=2)+'\n')
 print(f'{min(start+24,len(fragments))}/{len(fragments)} fragments; {len(translations)}/{len(values)} messages',flush=True)
translations.update(json.loads(Path('tool/l10n/reviewed_en.json').read_text()))
Path('assets/l10n/en.json').write_text(json.dumps(translations,ensure_ascii=False,indent=2)+'\n')
