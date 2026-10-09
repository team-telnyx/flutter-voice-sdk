import unittest

from update_flutter_release import classify_pr


class ClassifyPrTest(unittest.TestCase):
    def test_labels_take_priority(self):
        self.assertEqual(classify_pr("add thing", "bug,enhancement"), "Bug Fixing")
        self.assertEqual(classify_pr("fix crash", "feature"), "Enhancement")

    def test_false_positive_words_do_not_match(self):
        for title in ("non-breaking cleanup", "debug logging", "prefix workflow", "workflow_dispatch support"):
            self.assertEqual(classify_pr(title, ""), "Enhancement")

    def test_fix_and_breaking_titles_match(self):
        self.assertEqual(classify_pr("fix(flutter-sdk): handle push", ""), "Bug Fixing")
        self.assertEqual(classify_pr("feat!: change release flow", ""), "Breaking")


if __name__ == "__main__":
    unittest.main()
