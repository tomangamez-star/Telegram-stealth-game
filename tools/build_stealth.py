#!/usr/bin/env python3
"""Export the standalone stealth game without changing 4th Heaven's main scene.
Usage: python3 tools/build_stealth.py /path/to/godot [output-directory]
Requires Godot 4.3 and its Web export templates.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
godot = shutil.which(sys.argv[1]) or str(pathlib.Path(sys.argv[1]).resolve())
out = pathlib.Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else root / 'build/stealth'
out.mkdir(parents=True, exist_ok=True)
template_dir = pathlib.Path.home() / '.local/share/godot/export_templates/4.3.stable'
has_release = (template_dir / 'web_nothreads_release.zip').exists() or (template_dir / 'web_dlink_nothreads_release.zip').exists()
has_debug = (template_dir / 'web_debug.zip').exists() or (template_dir / 'web_dlink_nothreads_debug.zip').exists()
export_mode = '--export-release' if has_release else ('--export-debug' if has_debug else None)
with tempfile.TemporaryDirectory(prefix='doodle-covert-') as temp:
    stage = pathlib.Path(temp) / 'project'
    stage.mkdir()
    shutil.copy2(root / 'project.godot', stage / 'project.godot')
    for folder in ['scripts/stealth', 'assets/characters', 'assets/stealth', 'assets/audio']:
        shutil.copytree(root / folder, stage / folder, ignore=shutil.ignore_patterns('*.import'))
    for filename in ['doodle_player.gd', 'doodle_visual.gd', 'doodle_personality.gd', 'doodle_atlas.gd', 'directional_rig_atlas.gd']:
        shutil.copy2(root / 'scripts' / filename, stage / 'scripts' / filename)
    for filename in ['scenes/stealth.tscn', 'tests/stealth_regression.gd']:
        (stage / filename).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / filename, stage / filename)
    project = stage / 'project.godot'
    project.write_text(project.read_text().replace('config/name="4TH HEAVEN"', 'config/name="Doodle Covert"').replace('res://scenes/main.tscn', 'res://scenes/stealth.tscn'))
    (stage / 'export_presets.cfg').write_text('''[preset.0]
name="Stealth Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter=""
export_path="build/stealth/index.html"
exclude_filter="tests/*,tools/*,web/*,build/*"

[preset.0.options]
variant/extensions_support=true
variant/thread_support=false
vram_texture_compression/for_desktop=false
vram_texture_compression/for_mobile=false
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
''')
    subprocess.run([godot, '--headless', '--editor', '--path', str(stage), '--import', '--quit'], check=True)
    subprocess.run([godot, '--headless', '--path', str(stage), '--script', 'tests/stealth_regression.gd'], check=True)
    if export_mode:
        subprocess.run([godot, '--headless', '--path', str(stage), export_mode, 'Stealth Web', str(out / 'index.html')], check=True)
    else:
        # Repack gameplay into an already exported web shell when this machine
        # has Godot but not the large web template bundle.
        if not (out / 'index.html').exists():
            raise RuntimeError('Web templates are missing and no existing docs/index.html shell is available')
        subprocess.run([godot, '--headless', '--path', str(stage), '--export-pack', 'Stealth Web', str(out / 'index.pck')], check=True)
    index = out / 'index.html'
    html = index.read_text().replace('Doodle Covert (DEBUG)', 'Doodle Covert')
    html = re.sub(r'"index\.pck":\d+', f'"index.pck":{(out / "index.pck").stat().st_size}', html)
    # Upgrade older generated shells in place as well as fresh Godot exports.
    html = re.sub(r'<img id="loader-doodle"[^>]*>', '', html)
    html = re.sub(r'#loader-doodle \{[^}]*\}\s*', '', html)
    html = re.sub(r'@keyframes doodle-step \{.*?\}\s*', '', html)
    html = html.replace('#loader-track { position:relative; height:64px; }', '#loader-track { position:relative; height:42px; }')
    if "url('menu_background.png')" not in html:
        html = html.replace('#status-splash { display:none !important; }', "#status-splash { display:none !important; }\n#status { background:linear-gradient(rgba(2,12,18,.67),rgba(2,12,18,.84)),url('menu_background.png') center/cover no-repeat; }")
    loader_css = '''
#status-splash { display:none !important; }
#status { background:linear-gradient(rgba(2,12,18,.67),rgba(2,12,18,.84)),url('menu_background.png') center/cover no-repeat; }
#loader-brand { width:min(78vw,720px); text-align:center; color:#91f1d0; font-family:Arial,sans-serif; }
#loader-title { font-size:clamp(28px,5vw,54px); font-weight:800; letter-spacing:.08em; margin-bottom:42px; }
#loader-track { position:relative; height:42px; }
#status-progress { width:100%; height:15px; margin:38px 0 0; accent-color:#7ce0bf; }
#loader-percent { margin-top:12px; color:#b6c8ce; font-size:20px; font-weight:700; }
'''
    if '#loader-brand' not in html:
        html = html.replace('</style>', loader_css + '\n</style>')
        html = html.replace('<img id="status-splash" src="index.png" alt="">\n\t\t\t<progress id="status-progress"></progress>', '<div id="loader-brand"><div id="loader-title">DOODLE / COVERT</div><div id="loader-track"><progress id="status-progress"></progress></div><div id="loader-percent">0%</div></div>')
        html = html.replace('<script src="index.js"></script>', '<script src="https://telegram.org/js/telegram-web-app.js"></script>\n\t\t<script src="index.js"></script>')
    progress_block = '''let shownProgress = 0;
\t\tlet preparationTimer = null;
\t\tfunction paintProgress(percent) {
\t\t\tshownProgress = Math.max(shownProgress, Math.min(100, percent));
\t\t\tstatusProgress.value = shownProgress;
\t\t\tstatusProgress.max = 100;
\t\t\tdocument.getElementById('loader-percent').textContent = Math.round(shownProgress) + '%';
\t\t}
\t\tfunction beginPreparation() {
\t\t\tif (preparationTimer) return;
\t\t\tpreparationTimer = setInterval(() => {
\t\t\t\tif (shownProgress < 98) paintProgress(shownProgress + 1);
\t\t\t}, 650);
\t\t}
\t\tengine.startGame({
\t\t\t'onProgress': function (current, total) {
\t\t\t\tif (current > 0 && total > 0) {
\t\t\t\t\tpaintProgress(Math.round((current / total) * 82));
\t\t\t\t\tif (current >= total) beginPreparation();
\t\t\t\t}
\t\t\t},
\t\t}).then(() => {
\t\t\tif (preparationTimer) clearInterval(preparationTimer);
\t\t\tpaintProgress(100);
\t\t\tdocument.title = 'Doodle Covert';
\t\t\tsetTimeout(() => setStatusMode('hidden'), 350);
\t\t}, displayFailureNotice);'''
    html = re.sub(r"engine\.startGame\(\{\s*'onProgress': function \(current, total\) \{.*?\}\s*,?\s*\}\)\.then\(\(\) => \{.*?\}, displayFailureNotice\);", progress_block, html, flags=re.S)
    html = re.sub(r'^.*loader-doodle.*\n?', '', html, flags=re.M)
    index.write_text(html)
    shutil.copy2(root / 'assets/stealth/boot_splash.png', out / 'index.png')
    shutil.copy2(root / 'assets/stealth/menu_background.png', out / 'menu_background.png')
    launch = subprocess.run([godot, '--headless', '--main-pack', str(out / 'index.pck'), '--quit-after', '120'], capture_output=True, text=True, cwd=temp, timeout=30)
    if launch.returncode or 'ERROR:' in launch.stderr:
        raise RuntimeError(launch.stdout + launch.stderr)
    for name in ['index.html', 'index.js', 'index.wasm', 'index.pck']:
        assert (out / name).stat().st_size > 0, f'Missing export: {name}'
print(f'Stealth Web exported to {out}')
