from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "audio"))

from phase7_catalog import load_catalog, validate_catalog

EXPECTED_PROMPTS = {
    "stage1_mid": "Original instrumental Japanese night-festival fantasy danmaku stage music, exact 150 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, warm and bright shrine approach, welcoming lantern procession, memorable independent melody, festival flute, koto-like accents, light taiko, restrained electronic rock drums, melodic bass and clear synth support, strictly instrumental, no choir, no vocal, clean game mix leaving spectral room for arcade warning SFX and graze cues",
    "stage1_boss": "Original instrumental Japanese night-festival fantasy danmaku boss music, exact 172 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, agile mischievous festival guide fox duel, memorable independent melody, shamisen-like plucks trading phrases with electronic guitar and festival flute, taiko plus punchy electronic rock drums, fast but readable arrangement, strictly instrumental, no choir, no vocal, preserve short spectral openings for spell and warning SFX",
    "stage2_mid": "Original instrumental Japanese night-festival fantasy danmaku stage music, exact 156 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, lively yokai market gradually becoming unstable, memorable independent melody, wood blocks and abacus-like percussion, koto-like plucks, jumping bass, light taiko and electronic rock groove, colorful stalls and awakened tools, strictly instrumental, no choir, no vocal, uncluttered game mix leaving room for warning SFX",
    "stage2_boss": "Original instrumental Japanese night-festival fantasy danmaku boss music, exact 176 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, forceful oni market merchant leader and supernatural bargain duel, memorable independent melody, heavy bass, sharp synth lead, taiko, metallic abacus percussion and electronic rock guitar, aggressive harmonic motion without chaos, strictly instrumental, no choir, no vocal, preserve cue space for boss hit and laser warning SFX",
    "stage3_mid": "Original instrumental Japanese night-festival fantasy danmaku stage music, exact 148 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, dreamlike mist bamboo corridor, wrong paths and time displacement, memorable independent melody, breathy festival flute, bamboo percussion, delayed koto-like figures, subdued taiko, controlled electronic pulse and warm bass, strictly instrumental, no choir, no vocal, transparent mix leaving warning SFX clearly audible",
    "stage3_boss": "Original instrumental Japanese night-festival fantasy danmaku boss music, exact 174 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, moonlit bamboo illusionist duel, reversed-feeling phrases and unstable harmony, memorable independent melody, fast koto-like arpeggios, flute fragments, electronic bass and focused rock drums, tense but not overfilled, strictly instrumental, no choir, no vocal, maintain room for spell and warning SFX",
    "stage4_mid": "Original instrumental Japanese night-festival fantasy danmaku stage music, exact 166 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, high-speed tengu mountain ascent and aerial pursuit, memorable independent melody, running festival flute, snare propulsion, paper and feather percussion, wind-like synth motion, taiko accents and electronic rock bass, strictly instrumental, no choir, no vocal, clear game mix leaving warning SFX unmasked",
    "stage4_boss": "Original instrumental Japanese night-festival fantasy danmaku boss music, exact 184 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, direct mountain wind tengu aerial duel, memorable independent melody, tremolo shamisen-like plucks, forceful taiko, fast electronic rock guitar, driving bass and sharp but controlled synth lead, strictly instrumental, no choir, no vocal, preserve transient space for laser warning and player hit SFX",
    "stage5_mid": "Original Japanese night-festival fantasy danmaku stage music, exact 170 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, dangerous oni banquet and rhythm bullets, memorable independent melody, layered taiko polyrhythm, deep bass, shamisen-like accents, electronic rock drums and restrained low-mixed wordless festival shouts only, no lyrics, no speech, keep voices behind the instruments, leave clear space for warning SFX and resource cues",
    "stage5_boss": "Original Japanese night-festival fantasy danmaku boss music, exact 188 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, heavy intoxicated oni princess duel, memorable independent melody, massive taiko, aggressive electronic rock guitar, strong bass and background wordless festival calls only, no lyrics, no speech, calls remain low in the mix, protect cue windows for spell announcements, player hit and laser warning SFX",
    "stage6_mid": "Original Japanese night-festival fantasy danmaku final-stage music, exact 176 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, sacred river of ten thousand lanterns becoming overwhelming, memorable independent melody, wide synth layers, festival flute, koto-like lantern accents, taiko, electronic rock rhythm and low-mixed wordless choir only, no lyrics, no speech, preserve clarity for dense final-stage warning SFX",
    "stage6_boss": "Original Japanese night-festival fantasy danmaku final-boss music, exact 194 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, divine god of the unending night festival, memorable independent final melody, forceful taiko, electronic rock guitar and bass, festival flute, shamisen-like plucks, brilliant synth lead and restrained wordless choir only, no lyrics, no speech, dramatic but clean mix with explicit transient space for spell, laser warning, deathbomb and player hit SFX",
}

FORBIDDEN_TOKENS = ("touhou", "zun", "\u6771\u65b9", "\u535a\u9e97", "\u5e7b\u60f3\u90f7")


class Phase7BgmCatalogTests(unittest.TestCase):
    def setUp(self) -> None:
        self.path = ROOT / "audio" / "production" / "phase7_bgm_jobs.json"
        self.data = load_catalog(self.path)

    def clone_data(self) -> dict:
        return json.loads(json.dumps(self.data))

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
        self.assertIs(True, self.data["defaults"]["free_models"])

    def test_prompts_match_authoritative_plan_exactly(self) -> None:
        self.assertEqual(EXPECTED_PROMPTS, {track["key"]: track["prompt"] for track in self.data["tracks"]})
        for track in self.data["tracks"]:
            combined = (track["prompt"] + " " + self.data["negative_prompt"]).lower()
            for token in FORBIDDEN_TOKENS:
                self.assertNotIn(token.lower(), combined)
            self.assertIn(f"exact {track['bpm']} bpm", track["prompt"].lower())

    def test_validate_catalog_rejects_non_object_track_entry(self) -> None:
        data = self.clone_data()
        data["tracks"][0] = "stage1_mid"

        with self.assertRaisesRegex(ValueError, r"tracks\[0\] must be an object"):
            validate_catalog(data)

    def test_validate_catalog_rejects_missing_track_key(self) -> None:
        data = self.clone_data()
        data["tracks"][0].pop("key")

        with self.assertRaisesRegex(ValueError, r"tracks\[0\]\.key must be a non-empty string"):
            validate_catalog(data)

    def test_validate_catalog_rejects_invalid_track_prompt_type(self) -> None:
        data = self.clone_data()
        data["tracks"][0]["prompt"] = ["not", "a", "string"]

        with self.assertRaisesRegex(ValueError, r"stage1_mid\.prompt must be a non-empty string"):
            validate_catalog(data)

    def test_validate_catalog_requires_free_models_true(self) -> None:
        data = self.clone_data()
        data["defaults"]["free_models"] = False

        with self.assertRaisesRegex(ValueError, r"defaults\.free_models must be true"):
            validate_catalog(data)


if __name__ == "__main__":
    unittest.main()
