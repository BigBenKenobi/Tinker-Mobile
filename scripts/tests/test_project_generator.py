"""Exercise generated Xcode references in disposable copies, never the checkout.

The Python suite checks source/resource membership and repeatability; it cannot
replace Xcode compilation, Simulator execution or visual screenshot acceptance.
"""
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]


class ProjectGeneratorTests(unittest.TestCase):
    """Each test owns a copied project, including nested fixtures and assets."""

    def setUp(self):
        """Copy only generator inputs to keep the production checkout untouched."""
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for folder in ("ios", "scripts", "contracts"):
            shutil.copytree(ROOT / folder, self.root / folder)

    def generate(self):
        """Run the actual script and return the newly emitted project contents."""
        subprocess.run([sys.executable, str(self.root / "scripts/generate_xcode_project.py")],
                       cwd=self.root, check=True, capture_output=True)
        return (self.root / "ios/TinkerCompanion.xcodeproj/project.pbxproj").read_text()

    def test_recursive_sources_assets_and_current_fixture(self):
        """New nested sources/assets must be registered in their correct target."""
        nested = self.root / "ios/TinkerCompanion/TestNested/Deep/New.swift"
        nested.parent.mkdir(parents=True)
        nested.write_text("import Foundation\n")
        asset = self.root / "ios/TinkerCompanion/Resources/Brand.xcassets"
        asset.mkdir(parents=True)
        (asset / "Contents.json").write_text('{"info":{"version":1,"author":"xcode"}}')
        project = self.generate()
        self.assertIn('path = "TestNested/Deep/New.swift"', project)
        self.assertIn('path = "TinkerCompanion/Resources/Brand.xcassets"', project)
        self.assertIn("snapshot-v2.json", project)
        self.assertNotIn("snapshot-v1.json", project)
        self.assertIn("com.apple.product-type.bundle.ui-testing", project)
        self.assertIn("TEST_TARGET_NAME = TinkerCompanion", project)

    def test_deterministic_unique_ids_and_resolved_references(self):
        """Stable output and closed ID references prevent fragile regeneration."""
        first = self.generate()
        self.assertEqual(first, self.generate())
        definitions = re.findall(r"^([A-F0-9]{24}) = ", first, re.M)
        self.assertEqual(len(definitions), len(set(definitions)))
        referenced = set(re.findall(r"\b[A-F0-9]{24}\b", first))
        self.assertEqual(referenced, set(definitions))

    def test_scheme_executes_both_test_targets(self):
        """The shared scheme must include enabled unit and screenshot UI suites."""
        self.generate()
        scheme = ET.parse(self.root / "ios/TinkerCompanion.xcodeproj/xcshareddata/xcschemes/TinkerCompanion.xcscheme")
        tests = scheme.findall(".//TestableReference")
        self.assertEqual(len(tests), 2)
        self.assertTrue(all(test.attrib["skipped"] == "NO" for test in tests))
        names = {test.find("BuildableReference").attrib["BlueprintName"] for test in tests}
        self.assertEqual(names, {"TinkerCompanionTests", "TinkerCompanionUITests"})


if __name__ == "__main__":
    unittest.main()
