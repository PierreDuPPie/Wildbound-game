"""Prepare the exported static files for Sites without modifying the game pack."""
import gzip
import hashlib
import json
from pathlib import Path

project = Path(__file__).resolve().parents[1]
site = project.parent / "sites" / "wildbound-play"
dist = site / "dist"
wasm = dist / "index.wasm"
if wasm.exists():
    payload = wasm.read_bytes()
    compressed = gzip.compress(payload, compresslevel=9, mtime=0)
    (dist / "index.wasm.gz").write_bytes(compressed)
    # Only remove this generated export after its replacement round-trips.
    if gzip.decompress(compressed) != payload:
        raise RuntimeError("Engine compression did not round-trip")
    wasm.unlink()
else:
    payload = gzip.decompress((dist / "index.wasm.gz").read_bytes())

(dist / "manifest.webmanifest").write_text(json.dumps({
    "name": "Wildbound", "short_name": "Wildbound", "start_url": "./",
    "scope": "./", "display": "standalone", "orientation": "landscape",
    "background_color": "#172d27", "theme_color": "#172d27",
    "icons": [{"src": "wildbound.svg", "sizes": "any", "type": "image/svg+xml", "purpose": "any"}],
}, indent=2) + "\n", encoding="utf-8")
(dist / "wildbound.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" width="192" height="192" viewBox="0 0 192 192"><rect width="192" height="192" rx="32" fill="#172d27"/><path d="M34 48l26 98 36-68 36 68 26-98" fill="none" stroke="#dfbd75" stroke-width="13" stroke-linejoin="round"/><path d="M96 19v17M96 156v17" stroke="#7b9a78" stroke-width="3"/></svg>\n', encoding="utf-8")
html = (dist / "index.html").read_text(encoding="utf-8")
html = html.replace('rel="icon" type="image/png" href="index.icon.png"', 'rel="icon" type="image/svg+xml" href="wildbound.svg"')
html = html.replace('  <title>Wildbound — Play</title>', '  <link rel="icon" href="wildbound.svg" type="image/svg+xml">\n  <title>Wildbound — Play</title>')
(dist / "index.html").write_text(html, encoding="utf-8")
for asset in dist.iterdir():
    if asset.is_file() and asset.stat().st_size > 25 * 1024 * 1024:
        raise RuntimeError(f"Static file exceeds host limit: {asset.name}")
metadata = {"engine_version": "4.7.2.stable", "engine_sha256": hashlib.sha256(payload).hexdigest(), "game_pack_sha256": hashlib.sha256((dist / "index.pck").read_bytes()).hexdigest(), "engine_gzip_bytes": (dist / "index.wasm.gz").stat().st_size, "game_pack_bytes": (dist / "index.pck").stat().st_size}
(site / "build-info.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
print(json.dumps(metadata))
