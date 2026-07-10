from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "audio"))

from phase7_catalog import load_catalog


class Phase7BgmCatalogTests(unittest.TestCase):
    def setUp(self) -> None:
        self.path = ROOT / "audio" / "production" / "phase7_bgm_jobs.json"
        self.data = load_catalog(self.path)

    def test_catalog_has_exact_track_order(self) -> None:
        expected = [
            "stage1_mid", "stage1_boss",
            "stage2_mid", "stage2_boss",
            "stage3_mid", "stage3_boss",
            "stage4_mid", "stage4_boss",
            "stage5_mid", "stage5_boss",
            "stage6_mid", "stage6_boss",
        ]
        self.assertEqual(expected, [track["key"] for track in self.data["tracks"]])

    def test_every_track_has_two_distinct_fixed_candidates(self) -> None:
        for track in self.data["tracks"]:
            self.assertEqual(["A", "B"], [item["variant"] for item in track["candidates"]])
            seeds = [item["seed"] for item in track["candidates"]]
            self.assertEqual(2, len(set(seeds)))
            self.assertTrue(all(isinstance(seed, int) and 0 < seed < 2_147_483_647 for seed in seeds))

    def test_voice_policy_matches_stage_rules(self) -> None:
        for track in self.data["tracks"]:
            if track["stage"] <= 4:
                self.assertEqual("instrumental_only", track["voice_policy"])
                self.assertIn("strictly instrumental", track["prompt"].lower())
            else:
                self.assertEqual("restrained_wordless_only", track["voice_policy"])
                self.assertIn("wordless", track["prompt"].lower())

    def test_defaults_match_approved_generation_contract(self) -> None:
        self.assertEqual(30.0, self.data["defaults"]["seconds"])
        self.assertEqual(8, self.data["defaults"]["steps"])
        self.assertEqual(2.0, self.data["defaults"]["cfg"])
        self.assertEqual("medium", self.data["defaults"]["dit"])
        self.assertEqual("same-l", self.data["defaults"]["decoder"])

    def test_prompts_are_original_and_gameplay_aware(self) -> None:
        forbidden = ("touhou", "zun", "東方", "博麗", "幻想郷")
        for track in self.data["tracks"]:
            combined = (track["prompt"] + " " + self.data["negative_prompt"]).lower()
            for token in forbidden:
                self.assertNotIn(token.lower(), combined)
            self.assertIn("warning sfx", track["prompt"].lower())
            self.assertIn(f"exact {track['bpm']} bpm", track["prompt"].lower())


if __name__ == "__main__":
    unittest.main()
