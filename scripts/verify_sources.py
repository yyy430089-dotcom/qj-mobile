"""校验源码基线和公共源数据；不读取本机输入法用户目录。"""
import hashlib
import json
import pathlib

root = pathlib.Path(__file__).resolve().parent.parent
manifest = json.loads((root / 'UPSTREAM.json').read_text(encoding='utf-8'))
for name, expected in manifest['sha256'].items():
    actual = hashlib.sha256((root / 'DataSource' / name).read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f'Source checksum mismatch: {name}')
dictionary = {line.split('\t')[0] for line in (root / 'DataSource/dict.tsv').read_text(encoding='utf-8').splitlines() if line and not line.startswith('#')}
glossary = [line for line in (root / 'DataSource/glossary-en.tsv').read_text(encoding='utf-8').splitlines() if line and not line.startswith('#')]
assert len(dictionary) == manifest['dictionary_words']
assert len(glossary) == manifest['glossary_entries']
assert all(line.split('\t')[0] in dictionary for line in glossary)
print(f"Verified upstream {manifest['tag']} @ {manifest['commit']}; {len(dictionary)} words, {len(glossary)} glosses")
