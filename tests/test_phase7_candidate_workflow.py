from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW_DOC = ROOT / "docs" / "audio" / "phase7_candidate_workflow.md"
PLAN_DOC = ROOT / "docs" / "superpowers" / "plans" / "2026-07-10-phase7a-bgm-candidate-production.md"


class Phase7CandidateWorkflowDocsTests(unittest.TestCase):
    def test_get_content_json_commands_require_utf8_encoding(self) -> None:
        for path in (WORKFLOW_DOC, PLAN_DOC):
            with self.subTest(path=path):
                lines = path.read_text(encoding="utf-8").splitlines()
                matching = [
                    line for line in lines
                    if "Get-Content" in line and "ConvertFrom-Json" in line
                ]
                self.assertTrue(matching, f"{path.name} should document at least one JSON parse command")
                for line in matching:
                    self.assertIn("-Encoding UTF8", line, line)

    def test_workflow_doc_names_reports_and_gate_counts(self) -> None:
        content = WORKFLOW_DOC.read_text(encoding="utf-8")
        self.assertIn("generation_manifest.json", content)
        self.assertIn("candidate_qa.json", content)
        self.assertIn("Expected 24 generated jobs", content)
        self.assertIn("failure_count -ne 0", content)
        self.assertIn("Expected 24 QA passes", content)
        self.assertIn("Expected 0 QA failures", content)


if __name__ == "__main__":
    unittest.main()
