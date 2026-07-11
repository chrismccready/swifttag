import csv
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "Docs" / "Analysis"))

import analyze_swifttag_project as analysis


def commit_record(commit_hash="a" * 40, subject="feat(core): add behavior"):
    metadata = analysis.parse_conventional_metadata(subject)
    return {
        "full_hash": commit_hash,
        "short_hash": commit_hash[:7],
        "author_date": "2026-01-01T00:00:00+00:00",
        "committer_date": "2026-01-01T00:00:00+00:00",
        "subject": subject,
        "body": "",
        "type": metadata["type"],
        "scope": metadata["scope"],
        "description": metadata["description"],
        "breaking": metadata["breaking"],
        "breaking_footers": metadata["breaking_footers"],
        "body_subject_aliases": metadata["body_subject_aliases"],
        "conventional_parse_status": metadata["parse_status"],
        "changed_files": "SwiftTag/Core.swift",
        "code_line_count": 10,
        "test_line_count": 2,
        "docs_line_count": 1,
        "plan_line_count": 0,
    }


class TranscriptParserTests(unittest.TestCase):
    def test_timestamped_turns_and_atomic_durations(self):
        text = """# Conversation Transcript

Date: 2026-06-18
Reference Type: Plan
References: 33-AddTrackFileRename.md

## User 2026-06-18T10:00:00Z

Request one.

## Assistant 2026-06-18T10:00:10Z

Response one.

[ 2026-06-18T10:01:10Z (1m since Assistant start) ]

## User 2026-06-18T11:01:10Z

Request two.

## Assistant 2026-06-18T11:01:20Z

Response two.

[ 2026-06-18T11:02:20Z (1m since Assistant start) ]
"""
        transcript, turns, warnings = analysis.parse_transcript_text(text, "sample", "sample.md")
        self.assertEqual(transcript["turn_count"], 4)
        self.assertEqual(transcript["back_and_forth_count"], 2)
        self.assertEqual(turns[1]["assistant_processing_seconds"], 60)
        self.assertEqual(turns[2]["user_response_seconds"], 3600)
        segments = analysis.build_transcript_segments(transcript, turns)
        self.assertEqual(len(segments), 2)
        self.assertEqual(segments[0]["assistant_processing_seconds"], 60)
        self.assertEqual(segments[0]["user_response_seconds"], 3600)
        self.assertEqual(segments[0]["valid_atomic_elapsed_seconds"], 3660)
        self.assertFalse([warning for warning in warnings if warning.category.startswith("invalid_")])

    def test_orphan_and_consecutive_turn_segments_are_stable(self):
        text = """# Conversation Transcript

## Assistant

Leading response.

## User

First request.

## User

Second request.

## Assistant

Final response.
"""
        transcript, turns, warnings = analysis.parse_transcript_text(text, "sample", "sample.md")
        segments = analysis.build_transcript_segments(transcript, turns)
        self.assertEqual(len(segments), 3)
        self.assertTrue(segments[0]["orphan"])
        self.assertEqual(segments[2]["turn_indexes"], [3, 4])
        self.assertIn("same_speaker_continuity", {warning.category for warning in warnings})

    def test_normalized_digest_ignores_cr_and_zero_width_characters(self):
        left = "A\r\nB\u200b\r\n"
        right = "A\nB\n"
        self.assertEqual(analysis.normalized_digest(left), analysis.normalized_digest(right))

    def test_untimestamped_transcript_keeps_counts_and_null_timing(self):
        transcript, turns, warnings = analysis.parse_transcript_text(
            "# Conversation Transcript\n\n## User\n\nRequest.\n\n## Assistant\n\nResponse.\n",
            "untimed",
            "untimed.md",
        )
        self.assertEqual(transcript["turn_count"], 2)
        self.assertEqual(transcript["back_and_forth_count"], 1)
        self.assertIsNone(transcript["elapsed_seconds"])
        self.assertIsNone(transcript["valid_atomic_elapsed_seconds"])
        self.assertIn("missing_transcript_duration", {warning.category for warning in warnings})
        self.assertEqual(len(analysis.build_transcript_segments(transcript, turns)), 1)

    def test_known_untimestamped_warnings_are_documented(self):
        transcript, _, warnings = analysis.parse_transcript_text(
            "# Conversation Transcript\n\n## User\n\nRequest.\n",
            "transcript-2026-02-27-1-1-FLACBridgeExecution",
            "Docs/Plans/Transcripts/transcript-2026-02-27-1-1-FLACBridgeExecution.md",
        )
        active = analysis.suppress_documented_transcript_warnings(transcript, warnings)
        self.assertGreater(transcript["documented_warning_count"], 0)
        self.assertFalse([warning for warning in active if warning.category == "missing_turn_timestamp"])


class PlanParserTests(unittest.TestCase):
    def test_numeric_plan_family_identity_and_versions(self):
        source, _ = analysis.parse_plan_text(
            "# Multi Picture\n\n## Goal\n\nWork.",
            "11-v4-AddMultiPicturePerTrackSupport",
            "Docs/Plans/11-v4-AddMultiPicturePerTrackSupport.md",
        )
        self.assertEqual(source["family_id"], "11")
        self.assertEqual(source["numeric_order"], 11)
        self.assertEqual(source["version"], 4)

    def test_versioned_sources_group_and_same_slug_numbers_do_not(self):
        sources = []
        for plan_id in (
            "11-v1-AddMultiPicturePerTrackSupport",
            "11-v4-AddMultiPicturePerTrackSupport",
            "19-AddSwiftTagDocumentSaveOptions",
            "20-AddSwiftTagDocumentSaveOptions",
            "22-AddSwiftTagDocumentSaveOptions",
        ):
            source, _ = analysis.parse_plan_text(f"# {plan_id}\n", plan_id, f"Docs/Plans/{plan_id}.md")
            sources.append(source)
        families = analysis.build_plan_families(sources)
        self.assertEqual({family["plan_id"] for family in families}, {"11", "19", "20", "22"})
        plan11 = next(family for family in families if family["plan_id"] == "11")
        self.assertEqual(plan11["version_count"], 2)
        self.assertEqual(plan11["current_source_id"], "11-v4-AddMultiPicturePerTrackSupport")

    def test_lookup_expands_rename_and_md_md_aliases(self):
        keys = analysis.plan_filename_lookup_keys(
            "Docs/Plans/{ContentViewReorganizationPlan.md => 2-ContentViewReorganizationPlan.md}"
        )
        self.assertIn("ContentViewReorganizationPlan.md", keys)
        self.assertIn("2-ContentViewReorganizationPlan.md", keys)
        self.assertIn("ContentViewReorganizationPlan", analysis.plan_filename_lookup_keys("x/ContentViewReorganizationPlan.md.md"))


class CommitMetadataTests(unittest.TestCase):
    def test_breaking_subject_and_footers(self):
        metadata = analysis.parse_conventional_metadata(
            "refactor(applescript)!: remove command",
            "BREAKING-CHANGE: command was removed\n\nfix(tags): retain alias",
        )
        self.assertEqual(metadata["type"], "refactor")
        self.assertEqual(metadata["scope"], "applescript")
        self.assertTrue(metadata["breaking"])
        self.assertEqual(metadata["breaking_footers"], ["command was removed"])
        self.assertEqual(metadata["body_subject_aliases"], ["fix(tags): retain alias"])

    def test_non_conventional_subject_remains_normal_metadata(self):
        metadata = analysis.parse_conventional_metadata("Initial commit")
        self.assertEqual(metadata["parse_status"], "unparsed")
        self.assertEqual(metadata["description"], "Initial commit")

    def test_one_commit_creates_one_canonical_feature(self):
        commit = commit_record()
        feature = analysis.create_feature_from_commit(commit)
        self.assertEqual(feature["feature_id"], commit["full_hash"])
        self.assertEqual(feature["linked_commit_ids"], [commit["full_hash"]])
        self.assertEqual(feature["display_name"], commit["subject"])

    def test_path_classification_separates_plan_and_transcript_lines(self):
        self.assertEqual(analysis.classify_path("Docs/Plans/2-Plan.md"), "plans")
        self.assertEqual(analysis.classify_path("Docs/Plans/Transcripts/t.md"), "transcripts")
        self.assertEqual(analysis.classify_path("SwiftTag/App.swift"), "app_code")

    def test_commit_history_plot_payload_uses_initial_and_covered_commits(self):
        first = commit_record("a" * 40, "feat(core): add first")
        second = commit_record("b" * 40, "feat(core): add second")
        first["sequence"] = 0
        second["sequence"] = 1
        first_feature = analysis.create_feature_from_commit(first)
        second_feature = analysis.create_feature_from_commit(second)
        first_feature["difficulty_score"] = 10
        second_feature["difficulty_score"] = 20
        data = {
            "report_commit_range": {
                "start_commit": first["full_hash"],
                "end_commit": second["full_hash"],
            },
            "commits": [first, second],
            "features": [first_feature, second_feature],
            "plans": [{
                "plan_id": "1",
                "display_title": "Sample",
                "creation_commit_id": first["full_hash"],
                "associated_feature_ids": [second["full_hash"], first["full_hash"]],
            }],
            "transcripts": [{
                "transcript_id": "transcript-sample",
                "archive_commit_ids": [second["full_hash"], first["full_hash"]],
                "associated_feature_ids": [second["full_hash"]],
            }],
        }
        payload = analysis.commit_history_plot_payload(data)
        self.assertEqual(payload["start_commit"], first["full_hash"])
        self.assertEqual(payload["end_commit"], second["full_hash"])
        self.assertEqual(payload["plans"][0]["initial_commit"], first["full_hash"])
        self.assertEqual(
            payload["plans"][0]["covered_commits"],
            [first["full_hash"], second["full_hash"]],
        )
        self.assertEqual(payload["transcripts"][0]["initial_commit"], first["full_hash"])
        self.assertEqual(payload["transcripts"][0]["covered_commits"], [second["full_hash"]])


class RangeAndExclusionTests(unittest.TestCase):
    def git(self, root, *args, env=None):
        merged = os.environ.copy()
        if env:
            merged.update(env)
        return subprocess.run(["git", *args], cwd=root, text=True, check=True, stdout=subprocess.PIPE, env=merged).stdout.strip()

    def make_commit(self, root, name, content, date):
        path = pathlib.Path(root) / name
        path.write_text(content, encoding="utf-8")
        self.git(root, "add", name)
        env = {"GIT_AUTHOR_DATE": date, "GIT_COMMITTER_DATE": date}
        self.git(root, "commit", "-m", f"project(test): {content}", env=env)
        return self.git(root, "rev-parse", "HEAD")

    def test_fixed_range_includes_boundaries_and_ignores_head_descendant(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.git(tmp, "init", "-q")
            self.git(tmp, "config", "user.name", "Test")
            self.git(tmp, "config", "user.email", "test@example.com")
            start = self.make_commit(tmp, "a.txt", "one", "2026-01-01T00:00:00Z")
            end = self.make_commit(tmp, "a.txt", "two", "2026-01-02T00:00:00Z")
            descendant = self.make_commit(tmp, "a.txt", "three", "2026-01-03T00:00:00Z")
            ctx = analysis.AnalysisContext(pathlib.Path(tmp), pathlib.Path(tmp) / "out")
            hashes = analysis.report_commit_hashes(ctx, {"enabled": True, "start_commit": start, "end_commit": end})
            self.assertEqual(hashes, [start, end])
            self.assertNotIn(descendant, hashes)
            with self.assertRaises(analysis.AnalysisError):
                analysis.report_commit_hashes(ctx, {"enabled": True, "start_commit": end, "end_commit": start})

    def test_later_dated_ancestor_fails_range_integrity(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.git(tmp, "init", "-q")
            self.git(tmp, "config", "user.name", "Test")
            self.git(tmp, "config", "user.email", "test@example.com")
            start = self.make_commit(tmp, "a.txt", "one", "2026-01-03T00:00:00Z")
            end = self.make_commit(tmp, "a.txt", "two", "2026-01-02T00:00:00Z")
            ctx = analysis.AnalysisContext(pathlib.Path(tmp), pathlib.Path(tmp) / "out")
            with self.assertRaises(analysis.AnalysisError):
                analysis.parse_git_history(ctx, {"enabled": True, "start_commit": start, "end_commit": end})

    def test_control_plan_exclusion_and_dirty_filter_are_exact(self):
        paths = analysis.excluded_plan_paths_config({"excluded_plan_paths": ["Docs/Plans/_SwiftTagProjectAnalysis.md"]})
        self.assertEqual(paths, {analysis.CONTROL_PLAN_PATH})
        status = "?? Docs/Plans/34-SwiftTagProjectAnalysis.md\n?? Docs/Plans/340-SwiftTagProjectAnalysis.md"
        filtered = analysis.filter_dirty_worktree_status(status, paths)
        self.assertNotIn("34-SwiftTagProjectAnalysis.md\n", filtered + "\n")
        self.assertIn("340-SwiftTagProjectAnalysis.md", filtered)


class ConfigurationTests(unittest.TestCase):
    def test_review_input_digest_tracks_plan_evidence_and_method_version(self):
        transcript = {"normalized_content_digest": "t" * 64}
        plan = {"plan_id": "1", "source_plan_ids": ["1-Plan"], "source_content_digests": ["a" * 64], "current_source_line_count": 10}
        first = analysis.review_input_digest(transcript, [], [plan], "v1")
        changed_plan = dict(plan, source_content_digests=["b" * 64])
        self.assertNotEqual(first, analysis.review_input_digest(transcript, [], [changed_plan], "v1"))
        self.assertNotEqual(first, analysis.review_input_digest(transcript, [], [plan], "v2"))

    def test_v1_to_v2_migration_is_pure_and_idempotent(self):
        commit_hash = "a" * 40
        legacy = {
            "feature_definitions": {"legacy": "Legacy"},
            "feature_commits": {"legacy": [commit_hash]},
            "feature_transcripts": {"legacy": [{"transcript_id": "t", "allocation_weight": 1.0}]},
            "feature_plans": {"legacy": ["26-Plan.md"]},
            "exclusive_commit_feature_links": [commit_hash],
        }
        original = json.loads(json.dumps(legacy))
        converted = analysis.migrate_manual_links_v1_to_v2(legacy)
        self.assertEqual(legacy, original)
        self.assertEqual(converted["schema_version"], 2)
        self.assertIn(commit_hash, converted["commit_transcripts"])
        self.assertEqual(converted["commit_plans"][commit_hash][0]["plan_id"], "26")
        self.assertEqual(analysis.migrate_manual_links_v1_to_v2(converted), converted)

    def test_whole_transcript_weight_requires_reason(self):
        commit_hash = "a" * 40
        commits = {commit_hash: {}}
        plans = {"1": {}}
        transcripts = {"t": {}}
        segments = {"t:segment-001": {"transcript_id": "t"}}
        config = {
            "schema_version": 2,
            "review_method_version": "test",
            "transcript_reviews": {
                "t": {
                    "review_status": "reviewed",
                    "reviewed_by": "test",
                    "reviewed_at": "2026-01-01",
                    "feature_unallocated_remainder": 0,
                    "plan_unallocated_remainder": 1,
                    "feature_allocations": [{"commit_hash": commit_hash}],
                }
            },
        }
        with self.assertRaises(analysis.AnalysisError):
            analysis.validate_manual_config(config, commits, plans, transcripts, segments)
        config["transcript_reviews"]["t"]["feature_allocations"][0]["cannot_segment_reason"] = "single inseparable exchange"
        analysis.validate_manual_config(config, commits, plans, transcripts, segments)

    def test_invalid_segment_is_semantic_review_error(self):
        review = {
            "review_status": "reviewed",
            "reviewed_by": "test",
            "reviewed_at": "2026-01-01",
            "feature_unallocated_remainder": 0,
            "plan_unallocated_remainder": 1,
            "feature_allocations": [{"commit_hash": "a" * 40, "segment_ids": ["missing"]}],
        }
        self.assertIn("Invalid segment", analysis.semantic_review_error("t", review, {}))


class InternalLinkValidationTests(unittest.TestCase):
    def test_embedded_script_href_text_and_non_file_uris_are_ignored(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = pathlib.Path(tmp)
            (output / "index.html").write_text(
                """<html><body>
<script>const sample = 'href=\"not-a-real-link.html\"';</script>
<a href="data:application/octet-stream">Download</a>
<a href="https://example.com">External</a>
</body></html>""",
                encoding="utf-8",
            )
            ctx = analysis.AnalysisContext(output, output)
            analysis.validate_internal_links(ctx)
            self.assertEqual(ctx.warnings, [])

    def test_missing_real_html_href_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = pathlib.Path(tmp)
            (output / "index.html").write_text(
                '<html><body><a href="missing.html">Missing</a></body></html>',
                encoding="utf-8",
            )
            ctx = analysis.AnalysisContext(output, output)
            analysis.validate_internal_links(ctx)
            self.assertEqual(len(ctx.warnings), 1)
            self.assertEqual(ctx.warnings[0].category, "broken_internal_link")
            self.assertEqual(ctx.warnings[0].message, "missing.html")


class DifficultyAndThemeTests(unittest.TestCase):
    def test_unavailable_timing_keeps_original_weight_coverage(self):
        feature = analysis.create_feature_from_commit(commit_record())
        feature["total_visible_conversation_elapsed_seconds"] = None
        feature["total_assistant_processing_seconds"] = None
        weights = {"code_lines": 0.3, "transcript_lines": 0.15, "plan_lines": 0.1, "elapsed_time": 0.2, "assistant_processing_time": 0.1, "back_and_forth_count": 0.15}
        analysis.apply_difficulty_scores({feature["feature_id"]: feature}, weights)
        self.assertAlmostEqual(feature["difficulty_weight_coverage"], 0.7)
        self.assertEqual(feature["difficulty_inputs"]["elapsed_time"], None)

    def test_feature_and_plan_difficulty_use_separate_cohorts(self):
        feature = analysis.create_feature_from_commit(commit_record())
        plan = {
            "implementation_code_lines": 1.0, "direct_transcript_lines": 0.0,
            "implementation_transcript_lines": 0.0, "current_source_line_count": 100,
            "total_visible_conversation_elapsed_seconds": None,
            "total_assistant_processing_seconds": None, "back_and_forth_count": 0.0,
        }
        weights = {"code_lines": 0.3, "transcript_lines": 0.15, "plan_lines": 0.1, "elapsed_time": 0.2, "assistant_processing_time": 0.1, "back_and_forth_count": 0.15}
        analysis.apply_difficulty_scores({feature["feature_id"]: feature}, weights)
        analysis.apply_plan_difficulty_scores({"1": plan}, weights)
        self.assertNotEqual(feature["difficulty_inputs"], plan["difficulty_inputs"])
        self.assertEqual(plan["difficulty_inputs"]["plan_lines"], 100)

    def test_negative_theme_edge_wins_without_default(self):
        commit_hash = "a" * 40
        feature = analysis.create_feature_from_commit(commit_record(commit_hash))
        ctx = analysis.AnalysisContext(pathlib.Path("."), pathlib.Path("out"))
        themes, _, coverage = analysis.build_themes(
            ctx,
            {"commit_files": [], "commits": [{"full_hash": commit_hash}], "user_documentation": []},
            {commit_hash: feature},
            {},
            {"project": {"display_name": "Project", "auto_keyword_match": False}},
            {"theme_commits": {"project": {"include": [commit_hash], "exclude": [commit_hash]}}},
        )
        self.assertEqual(themes[0]["child_feature_ids"], [])
        self.assertEqual(coverage[0]["coverage_state"], "missing_theme_assignment")
        self.assertIn("missing_theme_assignment", {warning.category for warning in ctx.warnings})


class MatplotlibAndOutputTests(unittest.TestCase):
    def test_main_report_navigation_links_to_analysis_readme_and_github_pages(self):
        main_page = analysis.html_page("Main", "")
        detail_page = analysis.html_page("Detail", "", "../")
        separator = '<span aria-hidden="true">|</span>'
        analysis_readme = (
            '<a href="https://chrismccready.github.io/swifttag/Docs/Analysis/">'
            'Analysis README</a>'
        )
        github_pages = (
            '<a href="https://chrismccready.github.io/swifttag/">'
            'SwiftTag GitHub Pages</a>'
        )

        self.assertIn(separator, main_page)
        self.assertIn(analysis_readme, main_page)
        self.assertIn(github_pages, main_page)
        self.assertLess(main_page.index(separator), main_page.index(analysis_readme))
        self.assertLess(main_page.index(analysis_readme), main_page.index(github_pages))
        self.assertNotIn(analysis_readme, detail_page)
        self.assertNotIn(github_pages, detail_page)

    def test_matplotlib_svg_is_deterministic_and_no_handwritten_fallback_exists(self):
        with tempfile.TemporaryDirectory() as tmp:
            ctx = analysis.AnalysisContext(pathlib.Path(tmp), pathlib.Path(tmp))
            left = pathlib.Path(tmp) / "left.svg"
            right = pathlib.Path(tmp) / "right.svg"
            rows = [("Zero Theme", 0.0, "")]
            analysis.matplotlib_bar_chart(ctx, "Stable", rows, left, "data/test.csv", "Value", limit=None)
            analysis.matplotlib_bar_chart(ctx, "Stable", rows, right, "data/test.csv", "Value", limit=None)
            self.assertEqual(left.read_bytes(), right.read_bytes())
            self.assertIn("3.11", ctx.matplotlib_version)
            pyplot = analysis.matplotlib_pyplot(ctx)
            self.assertEqual(float(pyplot.rcParams["font.size"]), 11.0)
            self.assertEqual(float(pyplot.rcParams["xtick.labelsize"]), 10.0)
        self.assertFalse(hasattr(analysis, "bar_chart"))
        self.assertFalse(hasattr(analysis, "matrix_chart"))

    def test_ensure_dirs_removes_legacy_feature_and_stale_plan_pages(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = pathlib.Path(tmp)
            for relative in ("features.html", "timelines.html", "features/stale.html", "plans/stale.html", "review-packets/transcripts/stale.json"):
                path = output / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("stale", encoding="utf-8")
            analysis.ensure_dirs(output)
            self.assertFalse((output / "features.html").exists())
            self.assertFalse((output / "timelines.html").exists())
            self.assertFalse((output / "features/stale.html").exists())
            self.assertFalse((output / "plans/stale.html").exists())
            self.assertTrue((output / "sources/commits").is_dir())
            self.assertTrue((output / "review-packets/transcripts").is_dir())


class RepositoryIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ctx = analysis.AnalysisContext(ROOT, ROOT / "Docs/Analysis/output")
        cls.data = analysis.build_cross_references(cls.ctx, analysis.discover_inputs(cls.ctx), review_only=True)

    def test_repository_range_feature_and_plan_invariants(self):
        commits = {commit["full_hash"] for commit in self.data["commits"]}
        features = {feature["feature_id"] for feature in self.data["features"]}
        self.assertEqual(len(commits), 208)
        self.assertEqual(commits, features)
        self.assertEqual(self.data["commits"][0]["full_hash"], analysis.REPORT_START_COMMIT)
        self.assertEqual(self.data["commits"][-1]["full_hash"], analysis.REPORT_END_COMMIT)
        self.assertEqual(len(self.data["plans"]), 33)
        self.assertNotIn("34", {plan["plan_id"] for plan in self.data["plans"]})
        self.assertFalse(any(source["path"] == analysis.CONTROL_PLAN_PATH for source in self.data["plan_sources"]))
        plan11 = next(plan for plan in self.data["plans"] if plan["plan_id"] == "11")
        self.assertEqual(plan11["version_count"], 4)

    def test_repository_review_and_theme_conformance(self):
        self.assertEqual({row["review_status"] for row in self.data["semantic_review_status"]}, {"reviewed"})
        self.assertEqual(
            {theme["theme_id"] for theme in self.data["themes"]},
            {"picture", "swifttag-document", "diff", "applescript", "tags", "save", "settings", "user-docs", "project", "flac-lib"},
        )
        self.assertTrue(all(feature["parent_theme_ids"] or feature["theme_coverage_state"] == "missing_theme_assignment" for feature in self.data["features"]))
        project_hashes = {
            "315dd772a284932ebaf5b599e41c6f6dd911a4e4",
            "d4f65729d1e61f20ac1eaf10d9e5b13db612d6b9",
        }
        project_features = [
            feature for feature in self.data["features"] if feature["feature_id"] in project_hashes
        ]
        self.assertEqual(len(project_features), 2)
        self.assertTrue(all("project" in feature["parent_theme_ids"] for feature in project_features))
        self.assertTrue(all(feature["theme_coverage_state"] == "assigned" for feature in project_features))
        self.assertFalse(any(
            warning.category == "missing_theme_assignment" and warning.source_id in project_hashes
            for warning in self.ctx.warnings
        ))

    def test_applescript_provenance_and_work_are_separate(self):
        relationships = self.data["relationships"]
        archive_hash = "0c2d38575541a8dada750da08698d78e75a4d3f0"
        archive_transcripts = {
            row["right_entity_id"] for row in relationships
            if row["left_entity_id"] == archive_hash
            and row["right_entity_type"] == "transcript"
            and row["role"] == "transcript-archive"
        }
        self.assertEqual(archive_transcripts, {
            "transcript-2026-04-21-1-26-AddAppleScriptSupport",
            "transcript-2026-04-22-1-26-AddAppleScriptSupport",
        })
        self.assertTrue(any(
            row["left_entity_id"] == archive_hash
            and row["right_entity_id"] == "transcript-2026-04-22-1-26-AddAppleScriptSupport"
            and row["role"] == "work"
            and row["included_in_rollup_totals"]
            for row in relationships
        ))
        self.assertTrue(any(
            row["left_entity_id"] == "5866685bcbe463804d3efa4fb258029bf961207a"
            and row["right_entity_id"] == "transcript-2026-04-21-1-26-AddAppleScriptSupport"
            for row in relationships
        ))

    def test_untimestamped_conformance(self):
        records = [item for item in self.data["transcripts"] if item["transcript_id"] in analysis.TRANSCRIPTS_WITHOUT_TIMESTAMPS_IDS]
        self.assertEqual(len(records), 8)
        self.assertTrue(all(item["elapsed_seconds"] is None for item in records))
        self.assertTrue(all(item["turn_count"] > 0 for item in records))

    def test_generated_output_inventory(self):
        output = ROOT / "Docs/Analysis/output"
        required_data = {
            "commits.csv", "plans.csv", "plan_revisions.csv", "transcripts.csv", "turns.csv",
            "transcript_segments.csv", "segment_allocations.csv", "semantic_review_status.csv",
            "commit_files.csv", "commit_references.csv", "plan_references.csv",
            "commit_plan_references.csv", "theme_references.csv", "theme_coverage.csv",
            "relationships.csv", "themes.csv", "user_documentation.csv", "metrics.json",
            "warnings.csv", "run_metadata.json",
        }
        self.assertTrue(required_data.issubset({path.name for path in (output / "data").iterdir()}))
        self.assertFalse((output / "features.html").exists())
        self.assertFalse((output / "features").exists())
        self.assertFalse((output / "timelines.html").exists())
        self.assertFalse((output / "data/features.csv").exists())
        self.assertFalse((output / "data/feature_references.csv").exists())
        self.assertFalse((output / "data/feature_plan_references.csv").exists())
        commit_pages = list((output / "sources/commits").glob("*.html"))
        self.assertEqual(len(commit_pages), 208)
        self.assertTrue(all(re.fullmatch(r"[0-9a-f]{7}", path.stem) for path in commit_pages))
        self.assertEqual(len(list((output / "plans").glob("*.html"))), 33)
        self.assertEqual(len(list((output / "review-packets/transcripts").glob("*.json"))), 81)
        with (output / "data/commits.csv").open(newline="", encoding="utf-8") as handle:
            fields = csv.DictReader(handle).fieldnames or []
        self.assertIn("commit_hash", fields)
        self.assertNotIn("feature_id", fields)

    def test_generated_commit_index_layout_and_order(self):
        page = (ROOT / "Docs/Analysis/output/commits.html").read_text(encoding="utf-8")
        headers = re.findall(r"<th>([^<]+)</th>", page)
        self.assertEqual(headers[:12], [
            "Hash", "Date", "Subject", "Themes", "Difficulty", "Code",
            "Transcript Lines", "Elapsed", "Plans", "Transcripts", "Tests", "Docs",
        ])
        self.assertNotIn(">Features</a>", page)
        self.assertEqual(page.count('href="commits.html">Commits</a>'), 1)
        dates = re.findall(
            r'<tr><td><a href="sources/commits/[0-9a-f]{7}\.html">[0-9a-f]{7}</a></td><td>(\d{4}-\d{2}-\d{2})</td>',
            page,
        )
        self.assertEqual(len(dates), 208)
        self.assertEqual(dates, sorted(dates))

    def test_generated_commit_pages_show_date_before_full_hash(self):
        commits_by_short_hash = {commit["short_hash"]: commit for commit in self.data["commits"]}
        commit_pages = sorted((ROOT / "Docs/Analysis/output/sources/commits").glob("*.html"))

        for page_path in commit_pages:
            page = page_path.read_text(encoding="utf-8")
            commit = commits_by_short_hash[page_path.stem]
            expected_date = analysis.parse_date(commit["author_date"])
            date_markup = f"<p><strong>Commit Date:</strong> {expected_date}</p>"
            hash_markup = f"<p><code>{commit['full_hash']}</code></p>"

            self.assertIn(f"</nav></header><main>\n{date_markup}", page)
            self.assertLess(page.index(date_markup), page.index(hash_markup))

    def test_generated_plan_index_owns_evidence_dates_without_timeline_page(self):
        output = ROOT / "Docs/Analysis/output"
        page = (output / "plans.html").read_text(encoding="utf-8")
        headers = re.findall(r"<th>([^<]+)</th>", page)
        self.assertEqual(headers[-2:], ["First Evidence", "Last Evidence"])
        self.assertNotIn("Warnings", headers)
        self.assertNotIn(">Timelines</a>", page)
        self.assertNotIn('href="timelines.html"', page)
        self.assertFalse((output / "timelines.html").exists())

    def test_generated_difficulty_descriptions_and_index_link(self):
        output = ROOT / "Docs/Analysis/output"
        difficulty_page = (output / "difficulty.html").read_text(encoding="utf-8")
        index_page = (output / "index.html").read_text(encoding="utf-8")

        self.assertIn('<h2 id="commit-difficulty-description">Commit Difficulty</h2>', difficulty_page)
        self.assertIn("relative score from 0 to 100", difficulty_page)
        self.assertIn("Changed application-code lines (30%)", difficulty_page)
        self.assertIn('<h2 id="plan-difficulty-description">Plan Difficulty</h2>', difficulty_page)
        self.assertIn("ranks each Plan only against other Plans", difficulty_page)
        self.assertIn("Implementation code lines (30%)", difficulty_page)
        self.assertIn(
            '<a href="difficulty.html#commit-difficulty-description">'
            "Commit Difficulty derivation and description</a>",
            index_page,
        )

    def test_generated_warning_sources_link_to_report_sources(self):
        page = (ROOT / "Docs/Analysis/output/warnings.html").read_text(encoding="utf-8")
        headers = re.findall(r"<th>([^<]+)</th>", page)
        self.assertEqual(headers, [
            "Source Type", "Source", "Category", "Message", "Commit Difficulty",
            "Plan Difficulty", "Theme Time", "Line",
        ])
        commit_links = re.findall(
            r'<td>commit</td><td><a href="sources/commits/[0-9a-f]{7}\.html">[0-9a-f]{40}</a></td>',
            page,
        )
        transcript_links = re.findall(
            r'<td>transcript</td><td><a href="sources/transcripts/[^\"]+\.html#L1">[^<]+</a></td>',
            page,
        )
        self.assertEqual(len(commit_links), 15)
        self.assertEqual(len(transcript_links), 21)
        self.assertIn(
            "<td>No numbered Plan credibly governs this unnumbered development transcript.</td>"
            "<td>Included</td><td>Excluded</td><td>Commit lens Included; Plan lens Excluded</td>",
            page,
        )
        self.assertNotIn("missing_theme_assignment", page)
        self.assertNotIn("315dd772a284932ebaf5b599e41c6f6dd911a4e4", page)
        self.assertNotIn("d4f65729d1e61f20ac1eaf10d9e5b13db612d6b9", page)


if __name__ == "__main__":
    unittest.main()
