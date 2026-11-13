# Outside text sources for the column-aware evaluation corpus

Research for [Evaluating column-aware repair without real patient data](https://github.com/epabarker/r-ftfy/issues/15). Licences checked against each source's own pages on 2026-11-13. Facts only; the licence rule they are judged against was decided in the ticket: public domain, CC0, MIT/BSD-style and attribution-only (CC-BY, OGL, Unicode licence) are accepted; share-alike, non-commercial, no-derivatives and no-redistribution are excluded.

Field kinds: F1 personal names, F2 streets and towns, F3 free text, F4 coded or categorical values. UNVERIFIED means no primary page could be read.

## Within the rule

| Source | Licence | Covers | Download | Notes |
|---|---|---|---|---|
| Wikidata | CC0 for main, Property and Lexeme namespaces ([licensing](https://www.wikidata.org/wiki/Wikidata:Licensing)) | F1 (given-name and family-name items, native-script labels), F2, F4 (disease labels); all target languages | SPARQL; dated JSON dumps | Other namespaces are CC BY-SA 4.0. No frequencies. Pin a query snapshot. |
| Unicode CLDR | Unicode License V3, `Unicode-3.0` ([LICENSE](https://github.com/unicode-org/cldr/blob/main/LICENSE)) | F4-ish (localised language, territory, month, unit names), quote conventions; all languages | Versioned releases | Keep the notice. UTS #35 spec text excluded. No real personal-name lists. |
| GeoNames | CC BY ([terms](https://www.geonames.org/export/)) | F2 (towns, alternate names in many scripts) | Dumps at download.geonames.org/export/dump | Credit with a link. Dumps change daily and are not versioned: pin and checksum. |
| Tatoeba | CC BY 2.0 FR by default; CC0 1.0 subset ([terms](https://tatoeba.org/en/terms_of_use), [downloads](https://tatoeba.org/en/downloads)) | F3 (short sentences); all languages | Weekly dumps | Attribution per author (usernames). CC0 subset exists for some languages only. Sentences are short. |
| Project Gutenberg | Public domain in the US once the PG licence is stripped ([policy](https://www.gutenberg.org/policy/license.html)) | F3 (long prose with real curly quotes, dashes, ellipses); en, fr, de, es, pt, Nordic, pl, hu, ru, el | Per-book files, stable ebook numbers | Strip all PG references or keep the PG licence (trademark). Check each title is public domain; PG makes no claim outside the US. |
| ONS UK | OGL v3.0 ([licences](https://www.ons.gov.uk/methodology/geography/licences)) | F1 (en baby names) | Versioned spreadsheets | Wording: "Source: Office for National Statistics licensed under the Open Government Licence v.3.0". |
| INSEE France (Fichier des prénoms) | Licence Ouverte v2.0 ([dataset](https://www.data.gouv.fr/fr/datasets/fichier-des-prenoms-depuis-1900/)) | F1 (fr given names) | CSV on data.gouv.fr | |
| SSB Norway | CC BY 4.0 ([licence](https://www.ssb.no/en/diverse/lisens)) | F1 (no) | StatBank API | |
| DST Denmark | Free use with source credit, "equivalent to CC BY 4.0" (search result only, not fetched) | F1 (da) | Statbank | Confirm before use. |
| MeSH (NLM) | NLM terms ([terms](https://www.nlm.nih.gov/databases/download/terms_and_conditions_mesh.html)) | F4 (en descriptors) | Annual XML | Credit NLM and state the MeSH version. Translations excluded from these terms. |

## Outside the rule, or unverified

| Source | Why |
|---|---|
| OpenStreetMap | ODbL 1.0, share-alike; an extracted street list is arguably a derived database. |
| OpenAddresses | Licence varies per source and is not relicensed; some may be share-alike. |
| Wikipedia, Wiktionary lists | CC BY-SA 4.0. |
| Faker (Python) data | Code is MIT, but the underlying lists' provenance is mixed or unstated (de_DE and cs_CZ cite Wikipedia/Wiktionary; fr_FR, tr_TR, el_GR, ru_RU cite nothing). |
| WHO ICD-11 | CC BY-ND 3.0 IGO, no derivatives. |
| WHO ICD-10, SNOMED CT | Restrictive; redistribution not allowed or fees apply. |
| INE Spain | Terms contradict each other (CC BY 4.0, a CC BY-SA footer, and a written-permission clause). |
| Leipzig Corpora | UNVERIFIED: site blocked fetches; reportedly CC BY for downloads, CC BY-NC for other services. |
| UDHR translations | UNVERIFIED: no licence in the repo; per-translation copyright unclear. |
| SCB Sweden | UNVERIFIED: no licence on the names page. |
| Czech MV/CZSO | No open name dataset since 2016. |
| Statistics Poland, Destatis, ELSTAT, TÜİK, Russia | Not found or not checked. |

## Gaps

- **Ward and department names:** no open source found. The ticket allows self-written seed lists for categorical values only.
- **Long free text:** only Gutenberg reliably gives sentences of a few hundred characters with typographic punctuation; Tatoeba is short.
- **Names in pl, cs, hu, el, tr, ru:** only Wikidata covers them under the rule.
