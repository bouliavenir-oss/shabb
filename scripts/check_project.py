"""Structural checks only. This script does NOT compile or execute Swift."""
from pathlib import Path
import importlib.util
import plistlib
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('generator', ROOT / 'scripts/generate_project.py')
generator = importlib.util.module_from_spec(spec); spec.loader.exec_module(generator)

class ProjectChecks(unittest.TestCase):
    def test_project_generation_is_reproducible(self):
        files = [ROOT / 'ShabbatTV.xcodeproj/project.pbxproj', ROOT / 'ios/App/Info.plist', ROOT / 'ShabbatTV.xcodeproj/xcshareddata/xcschemes/ShabbatTV.xcscheme']
        before = [p.read_bytes() for p in files]
        generator.generate()
        self.assertEqual(before, [p.read_bytes() for p in files])
    def test_all_sources_are_compiled_once(self):
        objects = generator.generate()
        refs = [v['path'] for v in objects.values() if v['isa'] == 'PBXFileReference' and v.get('lastKnownFileType') == 'sourcecode.swift']
        expected = [p.relative_to(ROOT).as_posix() for p in (ROOT/'ios').rglob('*.swift')]
        self.assertCountEqual(refs, expected)
        self.assertEqual(len(refs), len(set(refs)))
    def test_scene_manifest_and_ipad_target(self):
        info = plistlib.loads((ROOT/'ios/App/Info.plist').read_bytes())
        scenes = info['UIApplicationSceneManifest']['UISceneConfigurations']
        self.assertIn('UIWindowSceneSessionRoleExternalDisplayNonInteractive', scenes)
        self.assertFalse(info['UIApplicationSceneManifest']['UIApplicationSupportsMultipleScenes'])
        self.assertNotIn('UIBackgroundModes', info)
    def test_shared_scheme_targets_existing_app(self):
        objects = generator.generate()
        scheme = ET.parse(ROOT/'ShabbatTV.xcodeproj/xcshareddata/xcschemes/ShabbatTV.xcscheme')
        for ref in scheme.findall('.//BuildableReference'):
            self.assertEqual(objects[ref.attrib['BlueprintIdentifier']]['isa'], 'PBXNativeTarget')
    def test_no_credentials_or_videos(self):
        for path in ROOT.rglob('*'):
            if not path.is_file() or any(x in path.parts for x in ['.git', '.build', 'build', '__pycache__']): continue
            self.assertNotIn(path.suffix.lower(), ['.p8', '.p12', '.mobileprovision', '.mp4', '.mkv', '.mov'])
            if path.suffix in ['.swift', '.yml']:
                content = path.read_text(encoding='utf-8')
                self.assertFalse(re.search(r'-----BEGIN (?:RSA |EC )?PRIVATE KEY-----', content))
    def test_playback_has_no_network_dependency(self):
        for folder in ['Player', 'Scheduler', 'HDMI']:
            for path in (ROOT/'ios'/folder).glob('*.swift'):
                self.assertNotRegex(path.read_text(encoding='utf-8'), r'URLSession|https?://|WKWebView')

if __name__ == '__main__': unittest.main(verbosity=2)
