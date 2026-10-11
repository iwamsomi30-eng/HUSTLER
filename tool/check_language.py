#!/usr/bin/env python3
"""Ukaguzi wa lugha sanifu (Hatua ya 6).

Hakikisha kwamba kamusi ya lugha (lib/core/i18n.dart):
  1. ina funguo zilezile kwa Kiswahili (sw) na Kiingereza (en);
  2. maandishi ya Kiswahili hayana maneno ya Kiingereza yaliyochanganywa;
  3. maandishi ya Kiingereza hayana maneno ya Kiswahili yaliyochanganywa.

Matumizi:  python3 tool/check_language.py
Inarudisha msimbo 1 ikiwa kuna kosa (inafaa kwa CI).
"""
import re
import sys
from pathlib import Path

SRC = Path(__file__).resolve().parent.parent / 'lib' / 'core' / 'i18n.dart'
text = SRC.read_text(encoding='utf8')

i_sw = text.index("'sw': {")
i_en = text.index("'en': {")
ENTRY = re.compile(r"'([a-z0-9_]+)':\s*'((?:\\.|[^'\\])*)'")


def parse(block):
    return {k: v for k, v in ENTRY.findall(block)}


sw, en = parse(text[i_sw:i_en]), parse(text[i_en:])

# Vifupisho na majina maalum vinavyoruhusiwa katika lugha zote mbili.
ALLOWED = {'PDF', 'Excel', 'PIN', 'SMS', 'OTP', 'TZS', 'QR', 'AES', 'GCM', 'TAG',
           'SHALOM', 'KIBAMBA', 'TEMPO', 'HOSPITAL', 'FUNGU', 'Fungu', 'MCH',
           'STK', 'KE', 'ME', 'MFUKO', 'mfuko', 'Supabase', 'F', 'M', 'Q'}

ENGLISH_IN_SW = r"""dashboard refresh records record export share filters filter details
detail category categories trend offline online internet account email password login
logout cloud sync synchronize synchronization device devices package server app build
update deletion conflicts conflict audit voucher receipt input step local pairing
checksum bundle computer permission data key secret security authentication
membership level row ok yes no download upload""".split()

SWAHILI_IN_EN = r"""ujumbe taarifa michango mchango makusanyo matumizi salio mtoaji
mchangiaji risiti kiasi tarehe ibada hifadhi futa hariri tafuta jina kifaa vifaa
mtandao akaunti kanisa ukurasa mistari mstari kipindi mwaka mwezi wiki leo hadi
kuanzia chagua weka tuma pokea sawazisha ingia toka msimamizi""".split()


def words(value):
    return re.findall(r"[A-Za-z][A-Za-z\-']*", value)


errors = []
for k in sorted(set(sw) ^ set(en)):
    errors.append(f"Ufunguo '{k}' upo kwenye lugha moja tu.")

for k, v in sw.items():
    for w in words(v):
        if w in ALLOWED:
            continue
        if w.lower() in ENGLISH_IN_SW:
            errors.append(f"[sw] {k}: neno la Kiingereza '{w}' -> {v}")

for k, v in en.items():
    for w in words(v):
        if w in ALLOWED:
            continue
        if w.lower() in SWAHILI_IN_EN:
            errors.append(f"[en] {k}: neno la Kiswahili '{w}' -> {v}")

print(f"Funguo: sw={len(sw)}, en={len(en)}")
if errors:
    print(f"\nMakosa {len(errors)}:")
    print('\n'.join(errors))
    sys.exit(1)
print('Lugha sanifu: hakuna kuchanganya lugha.')
