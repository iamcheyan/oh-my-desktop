#!/usr/bin/env python3
"""Generate static store pages for the Sumika Shell website.

Reads registry.json and writes:
  - extensions/<id>.html  (one detail page per extension)
  - store.html            (store grid, static HTML + JS enhancement)
  - index.html            (injects theme gallery between THEMES markers)

Pure stdlib. Output is fully static: works over HTTP and file://.
Run from website/: python3 tools/build.py
"""
import json
import pathlib
import html as H

ROOT = pathlib.Path(__file__).resolve().parent.parent
REG = json.loads((ROOT / "registry.json").read_text())

CATEGORY_LABELS = {
    "input": "Input",
    "hardware": "Hardware",
    "utilities": "Utilities",
    "system": "System",
    "appearance": "Appearance",
}
ICONS = {
    "keyboard_voice": "🎙️", "mic": "🎤", "translate": "かな", "keyboard": "⌨️",
    "screenshot_monitor": "📸", "cloud_upload": "☁️", "desktop_windows": "🪟",
    "palette": "🎨", "window": "🪟",
}

def nav(prefix: str, active: str) -> str:
    def link(href, label, key):
        cls = ' class="active"' if key == active else ""
        return f'<a href="{prefix}{href}"{cls}>{label}</a>'
    return f'''<nav class="nav"><div class="nav-inner">
  <a class="brand" href="{prefix}index.html"><span class="brand-mark"></span>Sumika Shell</a>
  <div class="nav-links">
    {link("index.html", "Home", "home")}
    {link("store.html", "Extensions", "store")}
    <a href="https://github.com/iamcheyan/oh-my-desktop">GitHub</a>
    <a class="nav-cta" href="{prefix}store.html">Get Started</a>
  </div>
</div></nav>'''

FOOTER = '''<footer><div class="container">
  <div>Sumika Shell — modular desktop shell for Hyprland, built with Quickshell.</div>
  <div><a href="https://github.com/iamcheyan/oh-my-desktop">GitHub</a> · <a href="store.html">Extensions</a> · <a href="https://github.com/iamcheyan/sasayaki">Sasayaki</a></div>
</div></footer>'''

def page(title: str, body: str, prefix: str = "", active: str = "home") -> str:
    return f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{H.escape(title)} · Sumika Shell</title>
<meta name="description" content="Sumika Shell — a modular, extension-driven desktop shell for Hyprland built with Quickshell.">
<link rel="stylesheet" href="{prefix}assets/css/style.css">
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'><rect width='32' height='32' rx='8' fill='%2320b2aa'/></svg>">
</head>
<body>
{nav(prefix, active)}
{body}
{FOOTER.replace('store.html', prefix + 'store.html')}
<script src="{prefix}assets/js/store.js" defer></script>
</body>
</html>
'''

def icon_for(ext) -> str:
    return ICONS.get(ext.get("icon", ""), "🧩")

def ext_card(e, prefix="") -> str:
    repo = f'<a href="{e["repo"]}" class="tag" onclick="event.stopPropagation()">repo ↗</a>' if e.get("repo") else ""
    return f'''<div class="ext-card" data-href="{prefix}extensions/{e['id']}.html" data-category="{e['category']}" data-name="{H.escape((e['name'] + ' ' + e.get('nameZh', '') + ' ' + e['summary']).lower())}">
  <a class="ext-top" href="{prefix}extensions/{e['id']}.html" style="color:inherit;text-decoration:none">
    <div class="ext-icon">{icon_for(e)}</div>
    <div>
      <div class="ext-title">{H.escape(e['name'])}</div>
      <div class="ext-namezh">{H.escape(e.get('nameZh', ''))}</div>
    </div>
  </a>
  <p class="ext-desc">{H.escape(e['summary'])}</p>
  <div class="ext-meta">
    <span class="tag">v{e['version']}</span>
    <span class="tag">{CATEGORY_LABELS[e['category']]}</span>
    <span>{e['size']}</span>
    {repo}
  </div>
</div>'''

# ---------- extensions/<id>.html ----------
def detail_page(e) -> str:
    deps = "\n".join(f"<li>{H.escape(d)}</li>" for d in e.get("deps", []))
    feats = "\n".join(f"<li>{H.escape(f)}</li>" for f in e["features"])
    repo_row = (f'<dt>Source</dt><dd><a href="{e["repo"]}">{e["repo"].split("/")[-1]} ↗</a></dd>'
                if e.get("repo") else "")
    note = f'<dt>Note</dt><dd>{H.escape(e["note"])}</dd>' if e.get("note") else ""
    body = f'''<main class="container section">
  <p style="margin:0 0 1rem"><a href="../store.html">← All extensions</a></p>
  <div class="detail-head">
    <div class="ext-icon">{icon_for(e)}</div>
    <div>
      <h1>{H.escape(e['name'])} <span style="font-size:0.9rem;color:var(--fg-faint)">v{e['version']}</span></h1>
      <p class="sub">{H.escape(e.get('nameZh', ''))} — {H.escape(e['summary'])}</p>
    </div>
  </div>
  <div class="detail-cols">
    <div>
      <p>{H.escape(e['description'])}</p>
      <h3 style="margin-top:2rem">Features</h3>
      <ul class="feature-list">{feats}</ul>
      <h3 style="margin-top:2rem">Install</h3>
      <ol class="install-steps">
        <li>Download the archive below (or clone the source repo).</li>
        <li>Extract into <code>~/.local/share/sumika-shell/extensions/{e['id']}/</code></li>
        <li>Run <code>sumika-restart</code> — the module is discovered at startup.</li>
        <li>Open <code>sumika-doctor</code> if anything looks off; core modules always win on ID conflicts.</li>
      </ol>
    </div>
    <aside class="detail-side">
      <div class="card">
        <a class="btn btn-primary" style="width:100%;justify-content:center;margin-bottom:0.9rem" href="../{e['download']}">⬇ Download ({e['size']})</a>
        <dl>
          <dt>Version</dt><dd>{e['version']}</dd>
          <dt>Category</dt><dd>{CATEGORY_LABELS[e['category']]}</dd>
          {repo_row}
          {note}
        </dl>
      </div>
      <div class="card">
        <dt>Dependencies</dt>
        <ul class="feature-list" style="margin-top:0.4rem">{deps}</ul>
      </div>
    </aside>
  </div>
</main>'''
    return page(f"{e['name']} — Extension", body, prefix="../", active="store")

# ---------- store.html ----------
def store_page() -> str:
    cards = "\n".join(ext_card(e) for e in REG["extensions"])
    filters = '<button class="filter-btn active" data-filter="all">All</button>' + "".join(
        f'<button class="filter-btn" data-filter="{cat}">{label}</button>'
        for cat, label in CATEGORY_LABELS.items())
    body = f'''<main class="container section">
  <div class="section-head">
    <div class="kicker">Extension Store</div>
    <h2>Browse extensions</h2>
    <p>Optional modules drop into <code>~/.local/share/sumika-shell/extensions/</code> and are discovered
    at shell startup. Core modules always win on ID conflicts — extensions can never shadow core.</p>
  </div>
  <div class="store-toolbar">
    <input class="search" id="store-search" type="search" placeholder="Search extensions…" aria-label="Search extensions">
    {filters}
  </div>
  <div class="store-grid" id="store-grid">{cards}</div>
  <p class="empty-note hidden" id="store-empty">No extensions match your search.</p>
</main>'''
    return page("Extensions", body, active="store")

# ---------- index.html theme gallery injection ----------
def themes_gallery() -> str:
    cards = []
    for t in REG["themes"]:
        name = t.replace("-", " ").title()
        cards.append(f'''<div class="theme-card"><img src="assets/themes/{t}.webp" alt="{name} theme preview" loading="lazy"><div class="name"><b>{name}</b></div></div>''')
    return "\n".join(cards)

def inject_index() -> None:
    idx = ROOT / "index.html"
    if not idx.exists():
        return
    text = idx.read_text()
    begin = "<!--THEMES:BEGIN-->"
    end = "<!--THEMES:END-->"
    if begin in text and end in text:
        pre, rest = text.split(begin, 1)
        _, post = rest.split(end, 1)
        idx.write_text(f"{pre}{begin}\n{themes_gallery()}\n{end}{post}")

def main() -> None:
    ext_dir = ROOT / "extensions"
    ext_dir.mkdir(exist_ok=True)
    for e in REG["extensions"]:
        (ext_dir / f"{e['id']}.html").write_text(detail_page(e))
    (ROOT / "store.html").write_text(store_page())
    inject_index()
    print(f"generated {len(REG['extensions'])} detail pages, store.html, index injection")

if __name__ == "__main__":
    main()
