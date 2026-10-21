#!/usr/bin/env python3
"""Export the standalone stealth game without changing 4th Heaven's main scene.
Usage: python3 tools/build_stealth.py /path/to/godot [output-directory]
Requires Godot 4.3 and its Web export templates.
"""
import pathlib
import shutil
import subprocess
import sys
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
godot = shutil.which(sys.argv[1]) or str(pathlib.Path(sys.argv[1]).resolve())
out = pathlib.Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else root / 'build/stealth'
out.mkdir(parents=True, exist_ok=True)
template_dir = pathlib.Path.home() / '.local/share/godot/export_templates/4.3.stable'
export_mode = '--export-release' if (template_dir / 'web_nothreads_release.zip').exists() else '--export-debug'
with tempfile.TemporaryDirectory(prefix='doodle-covert-') as temp:
    stage = pathlib.Path(temp) / 'project'
    stage.mkdir()
    shutil.copy2(root / 'project.godot', stage / 'project.godot')
    for folder in ['scripts/stealth', 'assets/characters', 'assets/stealth']:
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
    subprocess.run([godot, '--headless', '--path', str(stage), export_mode, 'Stealth Web', str(out / 'index.html')], check=True)
    launch = subprocess.run([godot, '--headless', '--main-pack', str(out / 'index.pck'), '--quit-after', '120'], capture_output=True, text=True, cwd=temp, timeout=30)
    if launch.returncode or 'ERROR:' in launch.stderr:
        raise RuntimeError(launch.stdout + launch.stderr)
    for name in ['index.html', 'index.js', 'index.wasm', 'index.pck']:
        assert (out / name).stat().st_size > 0, f'Missing export: {name}'
print(f'Stealth Web exported to {out}')
