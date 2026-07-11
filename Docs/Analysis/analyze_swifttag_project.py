#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import csv
import datetime as dt
import hashlib
import html
import json
import math
import os
import re
import shutil
import statistics
import subprocess
import sys
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, Iterable


UTC = dt.timezone.utc
REPORT_START_COMMIT = "2c8445cbde7892ceff58fb58780a79278bcf7d6e"
REPORT_END_COMMIT = "1071c2e0ffd3bbc279f2cca6e15509e725518e25"
CONTROL_PLAN_PATH = "Docs/Plans/34-SwiftTagProjectAnalysis.md"
REVIEW_METHOD_VERSION = "plan-34-v1"
DEFAULT_REPORT_COMMIT_RANGE = {
    "enabled": True,
    "start_commit": REPORT_START_COMMIT,
    "end_commit": REPORT_END_COMMIT,
}
DEFAULT_EXCLUDED_PLAN_PATHS = {CONTROL_PLAN_PATH}
EARLY_COMMIT_NOTES_START_HASH = REPORT_START_COMMIT
EARLY_COMMIT_NOTES_END_HASH = "ee7e8faab965a7c2c39bc3ec3f698594d9ce8101"
TRANSCRIPTS_WITHOUT_TIMESTAMPS_IDS = {
    "transcript-2026-02-27-1-1-FLACBridgeExecution",
    "transcript-2026-03-02-1-MiscTagEditorDev",
    "transcript-2026-03-03-1-MiscTagEditorDev",
    "transcript-2026-03-04-1-2-ContentViewReorganizationPlan.md",
    "transcript-2026-03-06-1-4-FlacWriteTagsAndPicturesPlan",
    "transcript-2026-03-07-1-5-AddSaveNotificationsPlan",
    "transcript-2026-03-07-2-6-AgentsTranscriptSkillPlan",
    "transcript-2026-03-12-1-7-AddSaveStatusViewPlan",
}
DOCUMENTED_TRANSCRIPT_WITHOUT_TIMESTAMP_WARNING_CATEGORIES = {
    "missing_turn_timestamp",
    "missing_assistant_completion",
    "missing_transcript_duration",
    "same_speaker_continuity",
}
STOP_WORDS = {
    "add", "and", "are", "for", "fix", "fixed", "feature", "features", "from",
    "implement", "implemented", "implements", "into", "issue", "issues", "plan",
    "plans", "run", "runs", "support", "supported", "supporting", "supports", "test",
    "tests", "the", "this", "that", "update", "updated", "updates", "use", "with",
    "warning", "warnings", "swift", "swifttag",
}


class AnalysisError(RuntimeError):
    """Fatal report-integrity or dependency error."""


@dataclass(frozen=True)
class WarningRecord:
    source_type: str
    source_id: str
    category: str
    message: str
    line: int | None = None


@dataclass
class AnalysisContext:
    repo_root: Path
    output_dir: Path
    warnings: list[WarningRecord] = field(default_factory=list)
    matplotlib_version: str = ""
    plotly_version: str = ""
    require_reviewed_associations: bool = False

    def warn(
        self,
        source_type: str,
        source_id: str,
        category: str,
        message: str,
        line: int | None = None,
    ) -> None:
        warning = WarningRecord(source_type, source_id, category, message, line)
        if warning not in self.warnings:
            self.warnings.append(warning)


def normalize_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    return re.sub("[\u200b\u200c\u200d\ufeff]", "", text)


def normalized_digest(text: str) -> str:
    normalized = normalize_text(text).rstrip() + "\n"
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def stable_json_digest(value: Any) -> str:
    encoded = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def count_lines(text: str) -> int:
    normalized = normalize_text(text)
    return len(normalized.splitlines()) if normalized else 0


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    if len(slug) > 96:
        suffix = hashlib.sha1(slug.encode("utf-8")).hexdigest()[:8]
        slug = slug[:87].rstrip("-") + "-" + suffix
    return slug or "untitled"


def tokenize(value: str) -> set[str]:
    value = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", value)
    return {
        token
        for token in re.findall(r"[A-Za-z0-9]+", value.lower())
        if len(token) > 2 and token not in STOP_WORDS
    }


def parse_datetime(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    cleaned = value.strip()
    if cleaned.endswith("Z"):
        cleaned = cleaned[:-1] + "+00:00"
    try:
        parsed = dt.datetime.fromisoformat(cleaned)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def parse_date(value: str | None) -> str | None:
    match = re.search(r"\d{4}-\d{2}-\d{2}", value or "")
    return match.group(0) if match else None


def seconds_between(start: dt.datetime | None, end: dt.datetime | None) -> float | None:
    if start is None or end is None:
        return None
    seconds = (end - start).total_seconds()
    return seconds if seconds >= 0 else None


def format_seconds(seconds: float | int | None) -> str:
    if seconds is None or seconds == "":
        return "Unavailable"
    total = int(round(float(seconds)))
    hours, remainder = divmod(total, 3600)
    minutes, secs = divmod(remainder, 60)
    if hours:
        return f"{hours}h {minutes}m"
    if minutes:
        return f"{minutes}m {secs}s"
    return f"{secs}s"


def relpath(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def normalize_repo_path(path: str) -> str:
    return Path(path.replace("\\", "/")).as_posix().lstrip("./")


def source_line_for_offset(text: str, offset: int) -> int:
    return text[:offset].count("\n") + 1


def split_references(value: str | None) -> list[str]:
    if not value:
        return []
    return [part.strip().strip("`'\" ") for part in value.split(",") if part.strip().strip("`'\" ")]


def expand_git_rename_path(path: str) -> list[str]:
    brace = re.search(r"\{([^{}]+?) => ([^{}]+?)\}", path)
    if brace:
        prefix, suffix = path[: brace.start()], path[brace.end() :]
        return [prefix + brace.group(1) + suffix, prefix + brace.group(2) + suffix]
    arrow = re.match(r"(.+?)\s+=>\s+(.+)", path)
    return [arrow.group(1), arrow.group(2)] if arrow else [path]


def strip_plan_number_prefix(stem: str) -> str:
    return re.sub(r"^\d+(?:-v\d+)?-", "", stem)


def plan_filename_lookup_keys(path: str) -> set[str]:
    keys: set[str] = set()
    for expanded in expand_git_rename_path(path):
        name = Path(expanded).name
        if not name:
            continue
        names = {name}
        if name.endswith(".md.md"):
            names.add(name[:-3])
        for candidate in names:
            stem = re.sub(r"\.md$", "", candidate)
            unnumbered = strip_plan_number_prefix(stem)
            keys.update({candidate, stem, unnumbered, f"{unnumbered}.md"})
            number = re.match(r"^(\d+)(?:-v\d+)?-", stem)
            if number:
                keys.add(number.group(1))
    return {key for key in keys if key}


def source_html_path_for_plan(plan_id: str) -> str:
    return f"sources/plans/{plan_id}.html"


def source_html_path_for_transcript(transcript_id: str) -> str:
    return f"sources/transcripts/{transcript_id}.html"


def source_html_path_for_doc(doc_id: str) -> str:
    return f"sources/user-documentation/{doc_id}.html"


def source_html_path_for_commit(short_hash: str) -> str:
    return f"sources/commits/{short_hash}.html"


def commit_source_title(commit: dict[str, Any]) -> str:
    date = parse_date(commit.get("author_date")) or parse_date(commit.get("committer_date"))
    return f"Commit Source: {commit['short_hash']}" + (f" ({date})" if date else "")


def parse_transcript_text(
    text: str,
    transcript_id: str = "transcript",
    path: str = "",
) -> tuple[dict[str, Any], list[dict[str, Any]], list[WarningRecord]]:
    normalized = normalize_text(text)
    warnings: list[WarningRecord] = []
    header_fields: dict[str, str] = {}
    header_pattern = re.compile(
        r"(?im)^\s*(Date|Reference Type|References|Agent):\s*(.*?)(?=^\s*(?:Date|Reference Type|References|Agent|Note):|\n\s*## |\Z)",
        re.S,
    )
    for match in header_pattern.finditer(normalized):
        key = match.group(1).lower().replace(" ", "_")
        header_fields[key] = re.sub(r"\n+", " ", match.group(2)).strip()

    references = split_references(header_fields.get("references"))
    turn_pattern = re.compile(
        r"^## (User|Assistant)(?:\s+([0-9]{4}-[0-9]{2}-[0-9]{2}T[^ \n]+))?(?:\s+\((.*?)\))?\s*$",
        re.M,
    )
    matches = list(turn_pattern.finditer(normalized))
    if not matches:
        warnings.append(WarningRecord("transcript", transcript_id, "missing_turns", "No User/Assistant turn headings found"))
    completion_pattern = re.compile(
        r"\[\s*([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.+-]+Z)\s+\(([^)]*since Assistant start[^)]*)\)\s*\]"
    )
    turns: list[dict[str, Any]] = []
    total_source_lines = count_lines(normalized)
    terminal_match = re.search(r"(?m)^End of Transcript(?:ion)?\.?\s*$", normalized)
    terminal_offset = terminal_match.start() if terminal_match else len(normalized)
    terminal_line = source_line_for_offset(normalized, terminal_offset) if terminal_match else total_source_lines + 1
    terminal_content_end_line = terminal_line - 1
    if terminal_match and terminal_match.group(0).startswith("End of Transcript") and not terminal_match.group(0).startswith("End of Transcription"):
        preceding_lines = normalized[:terminal_offset].splitlines()
        if preceding_lines and not preceding_lines[-1].strip():
            terminal_content_end_line -= 1
    for index, match in enumerate(matches):
        body_start = normalized.find("\n", match.end())
        body_start = len(normalized) if body_start == -1 else body_start + 1
        body_end = matches[index + 1].start() if index + 1 < len(matches) else terminal_offset
        body = normalized[body_start:body_end].strip("\n")
        start_line = source_line_for_offset(normalized, match.start())
        end_line = (
            source_line_for_offset(normalized, matches[index + 1].start()) - 1
            if index + 1 < len(matches)
            else min(total_source_lines, terminal_content_end_line)
        )
        timestamp = parse_datetime(match.group(2))
        completion_match = completion_pattern.search(body)
        completion = parse_datetime(completion_match.group(1)) if completion_match else None
        assistant_seconds: float | None = None
        if match.group(1) == "Assistant":
            assistant_seconds = seconds_between(timestamp, completion)
            if timestamp and completion and assistant_seconds is None:
                warnings.append(WarningRecord("transcript", transcript_id, "invalid_assistant_duration", "Assistant completion timestamp precedes heading timestamp", start_line))
                completion = None
            elif assistant_seconds is None:
                warnings.append(WarningRecord("transcript", transcript_id, "missing_assistant_completion", "Assistant turn lacks calculable completion timestamp", start_line))
        if timestamp is None:
            warnings.append(WarningRecord("transcript", transcript_id, "missing_turn_timestamp", f"{match.group(1)} turn lacks heading timestamp", start_line))
        turns.append({
            "transcript_id": transcript_id,
            "turn_id": f"{transcript_id}:turn-{index + 1:03d}",
            "turn_index": index + 1,
            "speaker": match.group(1),
            "source_line_start": start_line,
            "source_line_end": end_line,
            "timestamp": timestamp.isoformat().replace("+00:00", "Z") if timestamp else "",
            "annotation": match.group(3) or "",
            "completion_timestamp": completion.isoformat().replace("+00:00", "Z") if completion else "",
            "body_line_count": count_lines(body),
            "assistant_processing_seconds": assistant_seconds,
            "user_response_seconds": None,
            "timing_confidence": "completion" if assistant_seconds is not None else "unavailable",
            "assistant_completion_valid": assistant_seconds is not None,
            "interrupted": "[ interrupted agent ]" in body.lower() or "<turn_aborted>" in body.lower(),
            "body": body,
        })

    previous_speaker: str | None = None
    last_assistant_completion: dt.datetime | None = None
    back_and_forth = 0
    for turn in turns:
        if previous_speaker == turn["speaker"]:
            warnings.append(WarningRecord("transcript", transcript_id, "same_speaker_continuity", f"Consecutive {turn['speaker']} turns", turn["source_line_start"]))
        if previous_speaker == "User" and turn["speaker"] == "Assistant":
            back_and_forth += 1
        timestamp = parse_datetime(turn["timestamp"])
        if turn["speaker"] == "User" and last_assistant_completion and timestamp:
            response = seconds_between(last_assistant_completion, timestamp)
            if response is None:
                warnings.append(WarningRecord("transcript", transcript_id, "invalid_user_response_duration", "User response timestamp precedes prior Assistant completion", turn["source_line_start"]))
            else:
                turn["user_response_seconds"] = response
                turn["timing_confidence"] = "completion-to-user"
        if turn["speaker"] == "Assistant":
            last_assistant_completion = parse_datetime(turn["completion_timestamp"]) if turn["assistant_completion_valid"] else None
        previous_speaker = turn["speaker"]

    heading_times = [parse_datetime(turn["timestamp"]) for turn in turns if turn["timestamp"]]
    completion_times = [parse_datetime(turn["completion_timestamp"]) for turn in turns if turn["completion_timestamp"]]
    first_time = min((value for value in heading_times if value), default=None)
    last_time = max((value for value in completion_times if value), default=None)
    elapsed_confidence = "completion"
    if last_time is None:
        last_time = max((value for value in heading_times if value), default=None)
        elapsed_confidence = "heading" if last_time else "unavailable"
    wall_elapsed = seconds_between(first_time, last_time)
    if wall_elapsed is None:
        elapsed_confidence = "unavailable"
        warnings.append(WarningRecord("transcript", transcript_id, "missing_transcript_duration", "Transcript lacks calculable elapsed timing"))
    atomic_assistant = sum(float(turn["assistant_processing_seconds"] or 0) for turn in turns)
    atomic_response = sum(float(turn["user_response_seconds"] or 0) for turn in turns)
    record = {
        "transcript_id": transcript_id,
        "path": path,
        "export_date": parse_date(header_fields.get("date")) or parse_date(transcript_id) or "",
        "reference_type": header_fields.get("reference_type", ""),
        "raw_references": ", ".join(references),
        "references": references,
        "agent": header_fields.get("agent", ""),
        "line_count": total_source_lines,
        "turn_count": len(turns),
        "user_turn_count": sum(turn["speaker"] == "User" for turn in turns),
        "assistant_turn_count": sum(turn["speaker"] == "Assistant" for turn in turns),
        "first_timestamp": first_time.isoformat().replace("+00:00", "Z") if first_time else "",
        "last_timestamp": last_time.isoformat().replace("+00:00", "Z") if last_time else "",
        "elapsed_seconds": wall_elapsed,
        "valid_atomic_elapsed_seconds": atomic_assistant + atomic_response if wall_elapsed is not None else None,
        "assistant_processing_seconds": atomic_assistant if wall_elapsed is not None else None,
        "user_response_seconds": atomic_response if wall_elapsed is not None else None,
        "elapsed_confidence": elapsed_confidence,
        "back_and_forth_count": back_and_forth,
        "warning_count": len(warnings),
        "documented_warning_count": 0,
        "documented_warning_categories": "",
        "archive_commit_ids": [],
        "associated_feature_ids": [],
        "associated_plan_ids": [],
        "linked_feature_ids": [],
        "allocation_status": "unreviewed",
        "allocation_total": 0.0,
        "semantic_review_status": "unreviewed",
        "normalized_content_digest": normalized_digest(normalized),
        "review_input_digest": "",
        "match_text": normalized.lower(),
        "match_tokens": sorted(tokenize(transcript_id + " " + path + " " + normalized)),
        "_normalized_text": normalized,
    }
    return record, turns, warnings


def suppress_documented_transcript_warnings(
    transcript: dict[str, Any], warnings: list[WarningRecord]
) -> list[WarningRecord]:
    if transcript["transcript_id"] not in TRANSCRIPTS_WITHOUT_TIMESTAMPS_IDS:
        return warnings
    documented = [w for w in warnings if w.category in DOCUMENTED_TRANSCRIPT_WITHOUT_TIMESTAMP_WARNING_CATEGORIES]
    active = [w for w in warnings if w.category not in DOCUMENTED_TRANSCRIPT_WITHOUT_TIMESTAMP_WARNING_CATEGORIES]
    transcript["documented_warning_count"] = len(documented)
    transcript["documented_warning_categories"] = "; ".join(sorted({w.category for w in documented}))
    transcript["warning_count"] = len(active)
    return active


def build_transcript_segments(
    transcript: dict[str, Any], turns: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    segments: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for turn in turns:
        if turn["speaker"] == "User" or current is None:
            current = {
                "transcript_id": transcript["transcript_id"],
                "segment_id": f"{transcript['transcript_id']}:segment-{len(segments) + 1:03d}",
                "segment_index": len(segments) + 1,
                "source_line_start": turn["source_line_start"],
                "source_line_end": turn["source_line_end"],
                "speaker_start": turn["speaker"],
                "turn_ids": [],
                "turn_indexes": [],
                "body_line_count": 0,
                "source_line_count": 0,
                "assistant_processing_seconds": 0.0,
                "user_response_seconds": 0.0,
                "valid_atomic_elapsed_seconds": 0.0,
                "back_and_forth_count": 0,
                "orphan": turn["speaker"] != "User",
                "interrupted": False,
                "text": "",
            }
            segments.append(current)
        current["turn_ids"].append(turn["turn_id"])
        current["turn_indexes"].append(turn["turn_index"])
        current["source_line_end"] = turn["source_line_end"]
        current["body_line_count"] += turn["body_line_count"]
        current["assistant_processing_seconds"] += float(turn["assistant_processing_seconds"] or 0)
        current["interrupted"] = current["interrupted"] or turn["interrupted"]
        current["text"] += ("\n" if current["text"] else "") + turn["body"]
        indexes = current["turn_indexes"]
        if len(indexes) >= 2:
            previous = turns[indexes[-2] - 1]
            if previous["speaker"] == "User" and turn["speaker"] == "Assistant":
                current["back_and_forth_count"] += 1

    segment_by_turn: dict[int, dict[str, Any]] = {}
    for segment in segments:
        for turn_index in segment["turn_indexes"]:
            segment_by_turn[turn_index] = segment
    for turn in turns:
        if turn["speaker"] != "User" or turn["user_response_seconds"] is None or turn["turn_index"] <= 1:
            continue
        previous_turn = turns[turn["turn_index"] - 2]
        target = segment_by_turn.get(previous_turn["turn_index"])
        if target and previous_turn["speaker"] == "Assistant":
            target["user_response_seconds"] += float(turn["user_response_seconds"])
    for segment in segments:
        segment["source_line_count"] = max(0, segment["source_line_end"] - segment["source_line_start"] + 1)
        segment["valid_atomic_elapsed_seconds"] = (
            segment["assistant_processing_seconds"] + segment["user_response_seconds"]
        )
        segment["candidate_feature_ids"] = []
        segment["candidate_plan_ids"] = []
        segment["review_status"] = "unreviewed"
    return segments


def parse_plan_text(
    text: str, plan_id: str = "plan", path: str = ""
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    normalized = normalize_text(text)
    title_match = re.search(r"^#\s+(.+?)\s*$", normalized, re.M)
    title = title_match.group(1).strip() if title_match else plan_id
    match = re.match(r"(?:(\d+)(?:-v(\d+))?-)?(.+)", plan_id)
    order = int(match.group(1)) if match and match.group(1) else None
    version = int(match.group(2)) if match and match.group(2) else None
    source_slug = re.sub(r"\.md$", "", match.group(3) if match else plan_id)
    family_id = str(order) if order is not None else "draft-" + slugify(source_slug)
    section_matches = list(re.finditer(r"^##\s+(.+?)\s*$", normalized, re.M))
    sections: list[dict[str, Any]] = []
    for index, section_match in enumerate(section_matches):
        next_start = section_matches[index + 1].start() if index + 1 < len(section_matches) else len(normalized)
        body_start = normalized.find("\n", section_match.end())
        body = normalized[body_start + 1 : next_start].strip() if body_start != -1 else ""
        sections.append({
            "plan_source_id": plan_id,
            "plan_id": plan_id,
            "family_id": family_id,
            "heading": section_match.group(1).strip(),
            "slug": slugify(section_match.group(1)),
            "source_line_start": source_line_for_offset(normalized, section_match.start()),
            "source_line_end": source_line_for_offset(normalized, next_start),
            "excerpt": re.sub(r"\s+", " ", body)[:500],
        })
    by_slug = {section["slug"]: section for section in sections}
    record = {
        "plan_source_id": plan_id,
        "plan_id": plan_id,
        "family_id": family_id,
        "path": path,
        "title": title,
        "numeric_order": order,
        "version": version,
        "slug": source_slug,
        "line_count": count_lines(normalized),
        "section_names": "; ".join(section["heading"] for section in sections),
        "goal_excerpt": by_slug.get("goal", {}).get("excerpt", ""),
        "scope_excerpt": by_slug.get("scope", {}).get("excerpt", ""),
        "confirmed_decisions_excerpt": by_slug.get("confirmed-decisions", {}).get("excerpt", ""),
        "test_strategy_excerpt": by_slug.get("test-strategy", {}).get("excerpt", ""),
        "acceptance_criteria_excerpt": by_slug.get("acceptance-criteria", {}).get("excerpt", ""),
        "open_questions_excerpt": by_slug.get("open-questions", {}).get("excerpt", ""),
        "content_digest": normalized_digest(normalized),
        "_normalized_text": normalized,
    }
    return record, sections


def build_plan_families(plan_sources: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = {}
    for source in plan_sources:
        grouped.setdefault(source["family_id"], []).append(source)
    families: list[dict[str, Any]] = []
    for family_id, sources in grouped.items():
        ordered = sorted(
            sources,
            key=lambda source: (
                source["version"] if source["version"] is not None else 0,
                source["path"].lower(),
            ),
        )
        current = ordered[-1]
        families.append({
            "plan_id": family_id,
            "family_id": family_id,
            "display_title": current["title"],
            "title": current["title"],
            "numeric_order": current["numeric_order"],
            "source_plan_ids": [source["plan_source_id"] for source in ordered],
            "source_paths": [source["path"] for source in ordered],
            "source_content_digests": [source["content_digest"] for source in ordered],
            "current_source_id": current["plan_source_id"],
            "current_source_path": current["path"],
            "current_source_line_count": current["line_count"],
            "version_count": len(ordered),
            "section_names": current["section_names"],
            "creation_commit_id": "",
            "revision_commit_ids": [],
            "implementation_commit_ids": [],
            "transcript_archive_commit_ids": [],
            "associated_feature_ids": [],
            "associated_transcript_ids": [],
            "parent_theme_ids": [],
            "revision_additions": 0,
            "revision_deletions": 0,
            "direct_plan_lines": current["line_count"],
            "direct_transcript_lines": 0.0,
            "implementation_transcript_lines": 0.0,
            "implementation_code_lines": 0.0,
            "implementation_test_lines": 0.0,
            "implementation_documentation_lines": 0.0,
            "direct_visible_elapsed_seconds": None,
            "implementation_visible_elapsed_seconds": None,
            "total_visible_conversation_elapsed_seconds": None,
            "total_assistant_processing_seconds": None,
            "total_user_response_seconds": None,
            "back_and_forth_count": 0.0,
            "difficulty_score": 0.0,
            "difficulty_label": "Low",
            "difficulty_weight_coverage": 0.0,
            "first_evidence_date": "",
            "last_evidence_date": "",
            "confidence_score": 1.0,
            "warning_count": 0,
        })
    return sorted(families, key=plan_order_sort_key)


class DocumentationHTMLParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.title = ""
        self.headings: list[dict[str, str]] = []
        self.links: list[dict[str, str]] = []
        self.visible_chunks: list[str] = []
        self._heading: dict[str, str] | None = None
        self._link: dict[str, str] | None = None
        self._hidden = False
        self._title = False

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attrs_dict = {key: value or "" for key, value in attrs}
        if tag in {"script", "style"}:
            self._hidden = True
        elif tag == "title":
            self._title = True
        elif tag in {"h1", "h2", "h3"}:
            self._heading = {"level": tag, "id": attrs_dict.get("id", ""), "text": ""}
        elif tag == "a":
            self._link = {"href": attrs_dict.get("href", ""), "text": ""}

    def handle_endtag(self, tag: str) -> None:
        if tag in {"script", "style"}:
            self._hidden = False
        elif tag == "title":
            self._title = False
        if self._heading and tag == self._heading["level"]:
            self._heading["text"] = re.sub(r"\s+", " ", self._heading["text"]).strip()
            self.headings.append(self._heading)
            self._heading = None
        if tag == "a" and self._link:
            self._link["text"] = re.sub(r"\s+", " ", self._link["text"]).strip()
            self.links.append(self._link)
            self._link = None

    def handle_data(self, data: str) -> None:
        if self._hidden:
            return
        text = re.sub(r"\s+", " ", data).strip()
        if not text:
            return
        if self._title:
            self.title += (" " if self.title else "") + text
        if self._heading:
            self._heading["text"] += " " + text
        if self._link:
            self._link["text"] += " " + text
        self.visible_chunks.append(text)


def parse_documentation_file(path: Path, repo_root: Path) -> dict[str, Any]:
    text = read_text(path)
    parser = DocumentationHTMLParser()
    parser.feed(text)
    relative = relpath(path, repo_root)
    return {
        "documentation_id": slugify(relative),
        "path": relative,
        "title": parser.title.strip() or relative,
        "headings": parser.headings,
        "heading_text": "; ".join(item["text"] for item in parser.headings),
        "links": parser.links,
        "link_count": len(parser.links),
        "visible_text": " ".join(parser.visible_chunks),
        "line_count": count_lines(text),
        "linked_theme_ids": [],
        "linked_feature_ids": [],
    }


def parse_conventional_metadata(subject: str, body: str = "") -> dict[str, Any]:
    match = re.match(r"^([A-Za-z]+)(?:\(([^)]+)\))?(!)?:\s+(.+)$", subject)
    breaking_footers = [
        footer.group(2).strip()
        for footer in re.finditer(r"(?m)^(BREAKING CHANGE|BREAKING-CHANGE):\s*(.+)$", body)
    ]
    aliases = [
        line.strip()
        for line in body.splitlines()
        if re.match(r"^[A-Za-z]+(?:\([^)]+\))?!?:\s+.+$", line.strip())
    ]
    if not match:
        return {
            "type": "", "scope": "", "description": subject, "breaking": bool(breaking_footers),
            "parse_status": "unparsed", "breaking_footers": breaking_footers, "body_subject_aliases": aliases,
        }
    return {
        "type": match.group(1).lower(),
        "scope": match.group(2) or "",
        "description": match.group(4),
        "breaking": bool(match.group(3) or breaking_footers),
        "parse_status": "parsed",
        "breaking_footers": breaking_footers,
        "body_subject_aliases": aliases,
    }


def parse_conventional_subject(subject: str) -> tuple[str, str]:
    metadata = parse_conventional_metadata(subject)
    return metadata["type"], metadata["scope"]


def classify_path(path: str) -> str:
    path = normalize_repo_path(expand_git_rename_path(path)[-1])
    if path.startswith("Docs/Analysis/output"):
        return "generated_analysis"
    if path.startswith(("SwiftTagTests", "SwiftTagUITests")):
        return "tests"
    if path.startswith("Docs/Plans/Transcripts"):
        return "transcripts"
    if path.startswith("Docs/Plans"):
        return "plans"
    if path.startswith("Docs/") or path in {"README.md", "AGENTS.md"}:
        return "docs"
    if path.startswith("SwiftTagTestFiles"):
        return "fixtures"
    if path.startswith("SwiftTag/") or path.endswith(".xcodeproj/project.pbxproj"):
        return "app_code"
    return "other"


def git_result(ctx: AnalysisContext, args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args], cwd=ctx.repo_root, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )


def git(ctx: AnalysisContext, args: list[str]) -> str:
    result = git_result(ctx, args)
    if result.returncode:
        ctx.warn("git", "repository", "git_command_failed", "git " + " ".join(args) + ": " + result.stderr.strip())
        return ""
    return result.stdout


def git_required(ctx: AnalysisContext, args: list[str], purpose: str) -> str:
    result = git_result(ctx, args)
    if result.returncode:
        raise AnalysisError(f"{purpose}: git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout


def resolve_commit_hash(ctx: AnalysisContext, commitish: str) -> str:
    if not commitish:
        return ""
    result = git_result(ctx, ["rev-parse", "--verify", f"{commitish}^{{commit}}"])
    if result.returncode:
        return ""
    resolved = result.stdout.strip().splitlines()
    return resolved[0] if len(resolved) == 1 and re.fullmatch(r"[0-9a-f]{40}", resolved[0]) else ""


def report_commit_range_config(config: dict[str, Any]) -> dict[str, Any]:
    raw = config.get("report_commit_range") or DEFAULT_REPORT_COMMIT_RANGE
    return {
        "enabled": bool(raw.get("enabled", True)),
        "start_commit": raw.get("start_commit") or REPORT_START_COMMIT,
        "end_commit": raw.get("end_commit") or REPORT_END_COMMIT,
    }


def excluded_plan_paths_config(config: dict[str, Any]) -> set[str]:
    configured = config.get("excluded_plan_paths", [])
    paths = {normalize_repo_path(path) for path in configured if path}
    paths.discard("Docs/Plans/_SwiftTagProjectAnalysis.md")
    paths.add(CONTROL_PLAN_PATH)
    return paths


def status_line_path(line: str) -> str:
    payload = line[3:] if len(line) >= 3 else line
    if " -> " in payload:
        payload = payload.split(" -> ", 1)[1]
    return normalize_repo_path(payload.strip().strip('"'))


def filter_dirty_worktree_status(status: str, excluded_paths: set[str]) -> str:
    normalized_exclusions = {normalize_repo_path(path) for path in excluded_paths}
    return "\n".join(
        line for line in status.splitlines()
        if status_line_path(line) not in normalized_exclusions
    )


def report_commit_hashes(ctx: AnalysisContext, range_config: dict[str, Any]) -> list[str]:
    if not range_config.get("enabled", True):
        raise AnalysisError("Report commit range cannot be disabled for Plan 34 analysis")
    start_hash = resolve_commit_hash(ctx, str(range_config.get("start_commit", "")))
    end_hash = resolve_commit_hash(ctx, str(range_config.get("end_commit", "")))
    if not start_hash or not end_hash:
        raise AnalysisError("Configured report commit range boundaries are missing or ambiguous")
    ancestor = git_result(ctx, ["merge-base", "--is-ancestor", start_hash, end_hash])
    if ancestor.returncode != 0:
        raise AnalysisError("Configured report start commit is not an ancestor of end commit")
    if start_hash == end_hash:
        return [start_hash]
    lines = git_required(
        ctx,
        ["rev-list", "--reverse", "--ancestry-path", f"{start_hash}..{end_hash}"],
        "Enumerating fixed report range",
    ).splitlines()
    hashes = [start_hash] + [line.strip() for line in lines if line.strip()]
    if not hashes or hashes[-1] != end_hash or len(hashes) != len(set(hashes)):
        raise AnalysisError("Fixed report range enumeration failed integrity checks")
    return hashes


def commit_hashes_in_range(ctx: AnalysisContext, start_commit: str, end_commit: str) -> set[str]:
    return set(report_commit_hashes(ctx, {"enabled": True, "start_commit": start_commit, "end_commit": end_commit}))


def parse_git_history(
    ctx: AnalysisContext, range_config: dict[str, Any]
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    hashes = report_commit_hashes(ctx, range_config)
    commits: list[dict[str, Any]] = []
    commit_files: list[dict[str, Any]] = []
    for sequence, full_hash in enumerate(hashes):
        meta = git_required(
            ctx,
            ["show", "-s", "--date=iso-strict", "--format=%H%x1f%h%x1f%ad%x1f%cd%x1f%s%x1f%b", full_hash],
            f"Reading commit {full_hash}",
        )
        parts = meta.split("\x1f", 5)
        if len(parts) != 6:
            raise AnalysisError(f"Commit metadata parse failed for {full_hash}")
        canonical, _git_short_hash, author_date, committer_date, subject, body = parts
        canonical = canonical.strip()
        if canonical != full_hash:
            raise AnalysisError(f"Commit identity changed while reading {full_hash}")
        short_hash = canonical[:7]
        subject, body = subject.strip(), body.strip()
        conventional = parse_conventional_metadata(subject, body)
        status_text = git_required(ctx, ["show", "--name-status", "--format=", "--find-renames", full_hash], f"Reading paths for {full_hash}")
        status_rows: list[tuple[str, list[str]]] = []
        for line in status_text.splitlines():
            fields = line.split("\t")
            if len(fields) >= 2:
                status_rows.append((fields[0], fields[1:]))
        numstat = git_required(ctx, ["show", "--numstat", "--format=", "--find-renames", full_hash], f"Reading numstat for {full_hash}")
        additions_total = deletions_total = 0
        class_totals = {key: 0 for key in ("app_code", "tests", "docs", "plans", "transcripts", "fixtures", "other")}
        changed_paths: list[str] = []
        has_binary = False
        for line in numstat.splitlines():
            fields = line.split("\t")
            if len(fields) < 3:
                continue
            additions_raw, deletions_raw, path = fields[0], fields[1], fields[-1]
            binary = additions_raw == "-" or deletions_raw == "-"
            additions = 0 if binary else int(additions_raw)
            deletions = 0 if binary else int(deletions_raw)
            path_class = classify_path(path)
            if path_class == "generated_analysis":
                path_class = "docs"
            class_totals[path_class if path_class in class_totals else "other"] += additions + deletions
            additions_total += additions
            deletions_total += deletions
            has_binary = has_binary or binary
            changed_paths.append(path)
            expanded = expand_git_rename_path(path)
            status = ""
            for candidate_status, candidate_paths in status_rows:
                if any(normalize_repo_path(item) in {normalize_repo_path(value) for value in expanded} for item in candidate_paths):
                    status = candidate_status
                    break
            commit_files.append({
                "commit_hash": full_hash,
                "short_hash": short_hash,
                "path": path,
                "expanded_paths": expanded,
                "status": status,
                "path_class": path_class,
                "additions": additions,
                "deletions": deletions,
                "binary": binary,
            })
        commits.append({
            "sequence": sequence,
            "full_hash": full_hash,
            "feature_id": full_hash,
            "short_hash": short_hash,
            "author_date": author_date.strip(),
            "committer_date": committer_date.strip(),
            "subject": subject,
            "body": body,
            "type": conventional["type"],
            "scope": conventional["scope"],
            "description": conventional["description"],
            "breaking": conventional["breaking"],
            "breaking_footers": conventional["breaking_footers"],
            "body_subject_aliases": conventional["body_subject_aliases"],
            "conventional_parse_status": conventional["parse_status"],
            "changed_files": "; ".join(changed_paths),
            "changed_file_count": len(changed_paths),
            "additions": additions_total,
            "deletions": deletions_total,
            "code_line_count": class_totals["app_code"],
            "test_line_count": class_totals["tests"],
            "docs_line_count": class_totals["docs"],
            "plan_line_count": class_totals["plans"],
            "transcript_line_count": class_totals["transcripts"],
            "fixture_line_count": class_totals["fixtures"],
            "fixture_or_binary_change": has_binary or class_totals["fixtures"] > 0,
            "linked_plan_ids": [],
            "linked_transcript_ids": [],
            "linked_feature_ids": [full_hash],
            "link_confidence": "1.00",
            "link_evidence": "one-commit analytical invariant",
        })
    if len(commits) != len(hashes):
        raise AnalysisError("Not every configured-range commit produced a commit record")
    short_hashes = [commit["short_hash"] for commit in commits]
    if len(set(short_hashes)) != len(short_hashes):
        raise AnalysisError("Seven-character commit hashes are not unique in configured range")
    end = commits[-1]
    end_author = parse_datetime(end["author_date"])
    end_committer = parse_datetime(end["committer_date"])
    for commit in commits:
        if (
            end_author and parse_datetime(commit["author_date"]) and parse_datetime(commit["author_date"]) > end_author
        ) or (
            end_committer and parse_datetime(commit["committer_date"]) and parse_datetime(commit["committer_date"]) > end_committer
        ):
            raise AnalysisError(f"Commit {commit['full_hash']} is dated after configured end commit")
        if commit["conventional_parse_status"] == "unparsed":
            ctx.warn("commit", commit["full_hash"], "non_conventional_subject", "Primary subject does not match conventional commit syntax")
    return commits, commit_files


def load_json(path: Path, fallback: dict[str, Any]) -> dict[str, Any]:
    return json.loads(read_text(path)) if path.exists() else copy.deepcopy(fallback)


def discover_inputs(ctx: AnalysisContext) -> dict[str, Any]:
    manual_path = ctx.repo_root / "Docs/Analysis/config/manual_links.json"
    manual_config = load_json(manual_path, {})
    range_config = report_commit_range_config(manual_config)
    excluded_paths = excluded_plan_paths_config(manual_config)
    plan_sources: list[dict[str, Any]] = []
    plan_sections: list[dict[str, Any]] = []
    plans_root = ctx.repo_root / "Docs/Plans"
    for path in sorted(plans_root.glob("*.md")):
        relative = normalize_repo_path(relpath(path, ctx.repo_root))
        if relative in excluded_paths:
            continue
        source, sections = parse_plan_text(read_text(path), path.stem, relative)
        plan_sources.append(source)
        plan_sections.extend(sections)
    plans = build_plan_families(plan_sources)

    transcripts: list[dict[str, Any]] = []
    turns: list[dict[str, Any]] = []
    segments: list[dict[str, Any]] = []
    for path in sorted((plans_root / "Transcripts").glob("*.md")):
        transcript, parsed_turns, warnings = parse_transcript_text(read_text(path), path.stem, relpath(path, ctx.repo_root))
        warnings = suppress_documented_transcript_warnings(transcript, warnings)
        transcripts.append(transcript)
        turns.extend(parsed_turns)
        segments.extend(build_transcript_segments(transcript, parsed_turns))
        ctx.warnings.extend(warnings)

    documentation: list[dict[str, Any]] = []
    docs_root = ctx.repo_root / "Docs/UserDocumentation"
    if docs_root.exists():
        for path in sorted(docs_root.rglob("*.html")):
            if "assets" not in path.parts:
                documentation.append(parse_documentation_file(path, ctx.repo_root))
    commits, commit_files = parse_git_history(ctx, range_config)
    return {
        "plan_sources": plan_sources,
        "plans": plans,
        "plan_sections": plan_sections,
        "transcripts": transcripts,
        "turns": turns,
        "transcript_segments": segments,
        "user_documentation": documentation,
        "commits": commits,
        "commit_files": commit_files,
        "report_commit_range": {
            "enabled": True,
            "start_commit": commits[0]["full_hash"],
            "end_commit": commits[-1]["full_hash"],
        },
        "excluded_plan_paths": sorted(excluded_paths),
    }


def plan_order_sort_key(plan: dict[str, Any]) -> tuple[int, int, str]:
    order = plan.get("numeric_order")
    version = plan.get("version")
    return (
        int(order) if order is not None else sys.maxsize,
        int(version) if version is not None else 0,
        str(plan.get("plan_id") or plan.get("family_id") or "").lower(),
    )


def add_plan_lookup_key(
    lookup: dict[str, list[dict[str, Any]]], key: str, plan: dict[str, Any]
) -> None:
    bucket = lookup.setdefault(key, [])
    identity = plan.get("family_id") or plan.get("plan_id")
    if all((item.get("family_id") or item.get("plan_id")) != identity for item in bucket):
        bucket.append(plan)


def build_plan_filename_lookup(
    plans: list[dict[str, Any]], plan_sources: list[dict[str, Any]] | None = None
) -> dict[str, list[dict[str, Any]]]:
    lookup: dict[str, list[dict[str, Any]]] = {}
    families = {str(plan.get("family_id") or plan.get("plan_id")): plan for plan in plans}
    if plan_sources is None:
        plan_sources = plans
    for source in plan_sources:
        family_id = str(source.get("family_id") or source.get("plan_id"))
        plan = families.get(family_id, source)
        values = [source.get("path", ""), source.get("plan_source_id", ""), source.get("plan_id", "")]
        for value in values:
            for key in sorted(plan_filename_lookup_keys(str(value))):
                add_plan_lookup_key(lookup, key.lower(), plan)
        if source.get("numeric_order") is not None:
            add_plan_lookup_key(lookup, str(source["numeric_order"]), plan)
    return lookup


def matching_plans_for_path(
    lookup: dict[str, list[dict[str, Any]]], path: str
) -> list[dict[str, Any]]:
    matched: list[dict[str, Any]] = []
    identities: set[str] = set()
    for key in sorted(plan_filename_lookup_keys(path)):
        for plan in lookup.get(key.lower(), []):
            identity = str(plan.get("family_id") or plan.get("plan_id"))
            if identity not in identities:
                matched.append(plan)
                identities.add(identity)
    return matched


def transcript_filename_plan_hint(transcript_id: str) -> str | None:
    cleaned = re.sub(r"\.md$", "", transcript_id)
    match = re.match(r"transcript-\d{4}-\d{2}-\d{2}-\d+-(\d+)-", cleaned)
    return str(int(match.group(1))) if match else None


def create_feature_from_commit(commit: dict[str, Any]) -> dict[str, Any]:
    return {
        "feature_id": commit["full_hash"],
        "short_hash": commit["short_hash"],
        "display_name": commit["subject"],
        "subject": commit["subject"],
        "body": commit["body"],
        "type": commit["type"],
        "scope": commit["scope"],
        "description": commit["description"],
        "breaking": commit["breaking"],
        "breaking_footers": list(commit["breaking_footers"]),
        "conventional_parse_status": commit["conventional_parse_status"],
        "aliases": list(dict.fromkeys([commit["subject"], *commit["body_subject_aliases"]])),
        "author_date": commit["author_date"],
        "committer_date": commit["committer_date"],
        "changed_paths": commit["changed_files"],
        "linked_commit_ids": [commit["full_hash"]],
        "linked_plan_ids": [],
        "linked_transcript_ids": [],
        "parent_theme_ids": [],
        "theme_coverage_state": "unassigned",
        "total_code_lines_changed": float(commit["code_line_count"]),
        "total_test_lines_changed": float(commit["test_line_count"]),
        "total_documentation_lines_changed": float(commit["docs_line_count"]),
        "total_plan_lines": float(commit["plan_line_count"]),
        "total_transcript_lines": 0.0,
        "total_visible_conversation_elapsed_seconds": None,
        "total_assistant_processing_seconds": None,
        "total_user_response_seconds": None,
        "back_and_forth_count": 0.0,
        "allocated_turn_count": 0.0,
        "unavailable_timing_count": 0,
        "difficulty_inputs": {},
        "difficulty_score": 0.0,
        "difficulty_label": "Low",
        "difficulty_weight_coverage": 0.0,
        "confidence_score": 1.0,
        "warning_count": 0,
        "first_evidence_date": parse_date(commit["author_date"]) or "",
        "last_evidence_date": parse_date(commit["author_date"]) or "",
    }


def create_feature(
    features: dict[str, dict[str, Any]], feature_id: str, display_name: str
) -> dict[str, Any]:
    """Compatibility helper; commit hashes remain sole valid analytical identities."""
    if feature_id not in features:
        features[feature_id] = {
            "feature_id": feature_id,
            "short_hash": feature_id[:7],
            "display_name": display_name,
            "subject": display_name,
            "body": "",
            "type": "",
            "scope": "",
            "description": display_name,
            "breaking": False,
            "breaking_footers": [],
            "conventional_parse_status": "unparsed",
            "aliases": [display_name],
            "linked_commit_ids": [feature_id] if re.fullmatch(r"[0-9a-f]{40}", feature_id) else [],
            "linked_plan_ids": [],
            "linked_transcript_ids": [],
            "parent_theme_ids": [],
            "theme_coverage_state": "unassigned",
            "total_code_lines_changed": 0.0,
            "total_test_lines_changed": 0.0,
            "total_documentation_lines_changed": 0.0,
            "total_plan_lines": 0.0,
            "total_transcript_lines": 0.0,
            "total_visible_conversation_elapsed_seconds": None,
            "total_assistant_processing_seconds": None,
            "total_user_response_seconds": None,
            "back_and_forth_count": 0.0,
            "allocated_turn_count": 0.0,
            "unavailable_timing_count": 0,
            "difficulty_score": 0.0,
            "difficulty_label": "Low",
            "difficulty_weight_coverage": 0.0,
            "confidence_score": 1.0,
            "warning_count": 0,
            "first_evidence_date": "",
            "last_evidence_date": "",
        }
    return features[feature_id]


def relationship_key(row: dict[str, Any]) -> tuple[str, ...]:
    return tuple(str(row.get(key, "")) for key in (
        "left_entity_type", "left_entity_id", "right_entity_type", "right_entity_id",
        "role", "evidence_type", "evidence_source", "source_line",
    ))


def append_relationship(rows: list[dict[str, Any]], **values: Any) -> dict[str, Any]:
    row = {
        "left_entity_type": values.get("left_entity_type", ""),
        "left_entity_id": values.get("left_entity_id", ""),
        "right_entity_type": values.get("right_entity_type", ""),
        "right_entity_id": values.get("right_entity_id", ""),
        "role": values.get("role", "membership"),
        "evidence_type": values.get("evidence_type", "structural"),
        "evidence_source": values.get("evidence_source", ""),
        "source_line": values.get("source_line", ""),
        "confidence": float(values.get("confidence", 1.0)),
        "allocation_weight": float(values.get("allocation_weight", 0.0)),
        "included_in_direct_totals": bool(values.get("included_in_direct_totals", False)),
        "included_in_rollup_totals": bool(values.get("included_in_rollup_totals", False)),
        "manual_override_state": values.get("manual_override_state", "automatic"),
        "reviewed_by": values.get("reviewed_by", ""),
        "reviewed_at": values.get("reviewed_at", ""),
        "review_method": values.get("review_method", ""),
        "evidence_note": values.get("evidence_note", ""),
        "source_digest": values.get("source_digest", ""),
        "warning_state": values.get("warning_state", ""),
    }
    key = relationship_key(row)
    for existing in rows:
        if relationship_key(existing) == key:
            return existing
    rows.append(row)
    return row


def migrate_manual_links_v1_to_v2(
    config: dict[str, Any], ctx: AnalysisContext | None = None
) -> dict[str, Any]:
    """Pure, idempotent compatibility conversion. Never writes configuration."""
    if config.get("schema_version") == 2:
        return copy.deepcopy(config)
    converted: dict[str, Any] = {
        "schema_version": 2,
        "review_method_version": REVIEW_METHOD_VERSION,
        "report_commit_range": copy.deepcopy(config.get("report_commit_range", DEFAULT_REPORT_COMMIT_RANGE)),
        "excluded_plan_paths": [CONTROL_PLAN_PATH],
        "commit_transcripts": {},
        "commit_plans": {},
        "plan_transcripts": {},
        "theme_commits": {},
        "theme_plans": {},
        "commit_aliases": {},
        "documented_untimestamped_transcripts": [],
        "transcript_reviews": {},
        "exclusive_transcript_work_commits": {},
        "exclusive_commit_work_transcripts": {},
        "exclusive_commit_plans": {},
        "exclusive_plan_direct_commits": {},
        "exclusive_plan_direct_transcripts": {},
        "suppressed_warning_commit_ranges": copy.deepcopy(config.get("suppressed_warning_commit_ranges", [])),
        "migration_warnings": [],
    }
    for transcript_id in sorted(TRANSCRIPTS_WITHOUT_TIMESTAMPS_IDS):
        logical_id = transcript_id[:-3] if transcript_id.endswith(".md") else transcript_id
        physical_name = transcript_id + ".md"
        converted["documented_untimestamped_transcripts"].append({
            "path": f"Docs/Plans/Transcripts/{physical_name}",
            "logical_id": logical_id,
            "logical_alias": transcript_id,
        })
    feature_hashes: dict[str, set[str]] = {}
    for feature_id, values in config.get("feature_commits", {}).items():
        for value in values if isinstance(values, list) else [values]:
            resolved = resolve_commit_hash(ctx, str(value)) if ctx else str(value)
            if resolved:
                feature_hashes.setdefault(feature_id, set()).add(resolved)
    if ctx:
        for feature_id, ranges in config.get("feature_commit_ranges", {}).items():
            for item in ranges if isinstance(ranges, list) else [ranges]:
                if isinstance(item, dict):
                    feature_hashes.setdefault(feature_id, set()).update(
                        commit_hashes_in_range(ctx, item.get("start_commit", ""), item.get("end_commit", ""))
                    )
    definitions = config.get("feature_definitions", {})
    for feature_id, hashes in feature_hashes.items():
        for commit_hash in sorted(hashes):
            aliases = [feature_id]
            if definitions.get(feature_id):
                aliases.append(definitions[feature_id])
            converted["commit_aliases"].setdefault(commit_hash, [])
            converted["commit_aliases"][commit_hash] = sorted(set(converted["commit_aliases"][commit_hash] + aliases))
    for feature_id, values in config.get("feature_transcripts", {}).items():
        items = values if isinstance(values, list) else [values]
        hashes = feature_hashes.get(feature_id, set())
        if not hashes:
            converted["migration_warnings"].append(f"unresolved legacy transcript Commit: {feature_id}")
        for commit_hash in sorted(hashes):
            for item in items:
                edge = {"transcript_id": item if isinstance(item, str) else item.get("transcript_id", ""),
                        "role": "work", "included_in_totals": False,
                        "review_status": "unreviewed", "evidence_note": "migrated legacy association"}
                if isinstance(item, dict) and item.get("allocation_weight") is not None:
                    edge["legacy_allocation_weight"] = float(item["allocation_weight"])
                if edge["transcript_id"]:
                    converted["commit_transcripts"].setdefault(commit_hash, []).append(edge)
    for feature_id, values in config.get("feature_plans", {}).items():
        for commit_hash in sorted(feature_hashes.get(feature_id, set())):
            for item in values if isinstance(values, list) else [values]:
                plan_value = item if isinstance(item, str) else item.get("plan_id", "")
                match = re.match(r"(\d+)", Path(str(plan_value)).name)
                if match:
                    converted["commit_plans"].setdefault(commit_hash, []).append({
                        "plan_id": str(int(match.group(1))), "roles": ["implementation"],
                        "evidence_note": "migrated legacy Plan association",
                    })
    for commitish in config.get("exclusive_commit_feature_links", []):
        resolved = resolve_commit_hash(ctx, str(commitish)) if ctx else str(commitish)
        if resolved:
            transcript_ids = [edge["transcript_id"] for edge in converted["commit_transcripts"].get(resolved, [])]
            if transcript_ids:
                converted["exclusive_commit_work_transcripts"][resolved] = sorted(set(transcript_ids))
            plan_ids = [edge["plan_id"] for edge in converted["commit_plans"].get(resolved, [])]
            if plan_ids:
                converted["exclusive_commit_plans"][resolved] = sorted(set(plan_ids))
            if not transcript_ids and not plan_ids:
                converted["migration_warnings"].append(f"source-less exclusive legacy commit: {resolved}")
    for feature_id in config.get("replace_feature_transcripts", []):
        hashes = feature_hashes.get(feature_id, set())
        transcript_ids = []
        for value in config.get("feature_transcripts", {}).get(feature_id, []):
            transcript_id = value if isinstance(value, str) else value.get("transcript_id", "")
            if transcript_id:
                transcript_ids.append(transcript_id)
        if hashes and transcript_ids:
            for commit_hash in hashes:
                converted["exclusive_commit_work_transcripts"][commit_hash] = sorted(set(transcript_ids))
        else:
            converted["migration_warnings"].append(f"unresolved replace_feature_transcripts entry: {feature_id}")
    for feature_id in config.get("replace_feature_commits", []):
        if feature_id not in feature_hashes:
            converted["migration_warnings"].append(f"unresolved replace_feature_commits entry: {feature_id}")
    for theme_id, feature_ids in config.get("theme_features", {}).items():
        includes: set[str] = set()
        for feature_id in feature_ids:
            includes.update(feature_hashes.get(feature_id, set()))
        if includes:
            converted["theme_commits"][theme_id] = {"include": sorted(includes), "exclude": []}
    return converted


def resolve_config_hash(commitish: str, commits: dict[str, dict[str, Any]]) -> str:
    if commitish in commits:
        return commitish
    matches = [commit_hash for commit_hash in commits if commit_hash.startswith(commitish)]
    if len(matches) != 1:
        raise AnalysisError(f"Configured commit hash is missing or ambiguous: {commitish}")
    return matches[0]


def validate_manual_config(
    config: dict[str, Any], commits: dict[str, dict[str, Any]], plans: dict[str, dict[str, Any]],
    transcripts: dict[str, dict[str, Any]], segments: dict[str, dict[str, Any]],
    *, strict_semantic: bool = True,
) -> None:
    if config.get("schema_version") != 2:
        raise AnalysisError("manual_links.json schema_version must equal 2")
    if not config.get("review_method_version"):
        raise AnalysisError("manual_links.json requires review_method_version")
    for key in ("commit_transcripts", "commit_plans", "commit_aliases", "exclusive_commit_work_transcripts", "exclusive_commit_plans"):
        for commitish in config.get(key, {}):
            resolve_config_hash(str(commitish), commits)
    for plan_id in config.get("plan_transcripts", {}):
        if str(plan_id) not in plans:
            raise AnalysisError(f"Configured Plan does not exist: {plan_id}")
    for theme_key in ("theme_commits", "theme_plans"):
        for theme_id, raw in config.get(theme_key, {}).items():
            if not isinstance(raw, dict):
                continue
            include_ids = {
                str(item if isinstance(item, str) else item.get("commit_hash") or item.get("plan_id") or item.get("id") or "")
                for item in raw.get("include", [])
            }
            exclude_ids = {
                str(item if isinstance(item, str) else item.get("commit_hash") or item.get("plan_id") or item.get("id") or "")
                for item in raw.get("exclude", [])
            }
            conflicts = (include_ids & exclude_ids) - {""}
            if conflicts:
                raise AnalysisError(f"Theme {theme_id} both includes and excludes: {', '.join(sorted(conflicts))}")
    for transcript_id, review in config.get("transcript_reviews", {}).items():
        if transcript_id not in transcripts:
            raise AnalysisError(f"Configured transcript does not exist: {transcript_id}")
        if not strict_semantic:
            for allocation in review.get("feature_allocations", []):
                resolve_config_hash(str(allocation.get("commit_hash", "")), commits)
            for allocation in review.get("plan_allocations", []):
                if str(allocation.get("plan_id", "")) not in plans:
                    raise AnalysisError(f"Configured Plan does not exist: {allocation.get('plan_id', '')}")
            continue
        if review.get("review_status") not in {"reviewed", "unreviewed"}:
            raise AnalysisError(f"Invalid review_status for {transcript_id}")
        if review.get("review_status") == "reviewed":
            if not review.get("reviewed_by") or not review.get("reviewed_at"):
                raise AnalysisError(f"Reviewed transcript lacks provenance: {transcript_id}")
            if "feature_unallocated_remainder" not in review or "plan_unallocated_remainder" not in review:
                raise AnalysisError(f"Reviewed transcript lacks explicit remainder: {transcript_id}")
        accepted = (
            set(review.get("accepted_feature_candidates", []))
            | set(review.get("accepted_plan_candidates", []))
            | set(review.get("accepted_candidate_commit_ids", []))
            | set(review.get("accepted_candidate_plan_ids", []))
        )
        rejected = (
            set(review.get("rejected_feature_candidates", []))
            | set(review.get("rejected_plan_candidates", []))
            | set(review.get("rejected_candidate_commit_ids", []))
            | set(review.get("rejected_candidate_plan_ids", []))
        )
        if accepted.intersection(rejected):
            raise AnalysisError(f"Review candidate is both accepted and rejected in {transcript_id}")
        for allocation_key, entity_key, entities in (
            ("feature_allocations", "commit_hash", commits),
            ("plan_allocations", "plan_id", plans),
        ):
            for allocation in review.get(allocation_key, []):
                entity_id = str(allocation.get(entity_key, ""))
                if allocation_key == "feature_allocations":
                    resolve_config_hash(entity_id, commits)
                elif entity_id not in entities:
                    raise AnalysisError(f"Configured Plan does not exist: {entity_id}")
                weight = float(allocation.get("allocation_weight", 1.0))
                if not 0 <= weight <= 1:
                    raise AnalysisError(f"Allocation weight outside 0...1 in {transcript_id}")
                segment_ids = allocation.get("segment_ids", [])
                if segment_ids:
                    if allocation.get("cannot_segment_reason"):
                        raise AnalysisError(f"Segment allocation in {transcript_id} also supplies whole-transcript reason")
                    for segment_id in segment_ids:
                        segment = segments.get(segment_id)
                        if not segment or segment["transcript_id"] != transcript_id:
                            raise AnalysisError(f"Invalid segment {segment_id} in {transcript_id}")
                    source_ranges = allocation.get("source_ranges", [])
                    if source_ranges:
                        range_map = {str(item.get("segment_id", "")): item for item in source_ranges}
                        if set(range_map) != set(segment_ids):
                            raise AnalysisError(f"Source ranges do not match segment ids in {transcript_id}")
                        for segment_id in segment_ids:
                            segment = segments[segment_id]
                            item = range_map[segment_id]
                            if int(item.get("source_line_start", -1)) != int(segment["source_line_start"]) or int(item.get("source_line_end", -1)) != int(segment["source_line_end"]):
                                raise AnalysisError(f"Source range does not match {segment_id}")
                elif not allocation.get("cannot_segment_reason"):
                    raise AnalysisError(f"Whole-transcript allocation in {transcript_id} requires cannot_segment_reason")
                has_start = allocation.get("source_line_start") is not None
                has_end = allocation.get("source_line_end") is not None
                if has_start != has_end:
                    raise AnalysisError(f"Allocation source range is incomplete in {transcript_id}")


def semantic_review_error(
    transcript_id: str,
    review: dict[str, Any],
    segments: dict[str, dict[str, Any]],
) -> str:
    if review.get("review_status") != "reviewed":
        return "Review status is not reviewed"
    if not review.get("reviewed_by") or not review.get("reviewed_at"):
        return "Reviewed transcript lacks review provenance"
    if "feature_unallocated_remainder" not in review or "plan_unallocated_remainder" not in review:
        return "Reviewed transcript lacks explicit unallocated remainder"
    accepted = (
        set(review.get("accepted_feature_candidates", []))
        | set(review.get("accepted_plan_candidates", []))
        | set(review.get("accepted_candidate_commit_ids", []))
        | set(review.get("accepted_candidate_plan_ids", []))
    )
    rejected = (
        set(review.get("rejected_feature_candidates", []))
        | set(review.get("rejected_plan_candidates", []))
        | set(review.get("rejected_candidate_commit_ids", []))
        | set(review.get("rejected_candidate_plan_ids", []))
    )
    if accepted.intersection(rejected):
        return "Review candidate is both accepted and rejected"
    for allocation_key in ("feature_allocations", "plan_allocations"):
        for allocation in review.get(allocation_key, []):
            try:
                weight = float(allocation.get("allocation_weight", 1.0))
            except (TypeError, ValueError):
                return "Allocation weight is not numeric"
            if not 0 <= weight <= 1:
                return "Allocation weight is outside 0...1"
            segment_ids = allocation.get("segment_ids", [])
            if segment_ids and allocation.get("cannot_segment_reason"):
                return "Segment allocation also supplies whole-transcript reason"
            if not segment_ids and not allocation.get("cannot_segment_reason"):
                return "Whole-transcript allocation lacks cannot-segment reason"
            for segment_id in segment_ids:
                segment = segments.get(segment_id)
                if not segment or segment["transcript_id"] != transcript_id:
                    return f"Invalid segment reference: {segment_id}"
            source_ranges = allocation.get("source_ranges", [])
            if source_ranges:
                range_map = {str(item.get("segment_id", "")): item for item in source_ranges}
                if set(range_map) != set(segment_ids):
                    return "Source ranges do not match segment ids"
                for segment_id in segment_ids:
                    segment = segments[segment_id]
                    item = range_map[segment_id]
                    if int(item.get("source_line_start", -1)) != int(segment["source_line_start"]) or int(item.get("source_line_end", -1)) != int(segment["source_line_end"]):
                        return f"Source range does not match {segment_id}"
            has_start = allocation.get("source_line_start") is not None
            has_end = allocation.get("source_line_end") is not None
            if has_start != has_end:
                return "Allocation source range is incomplete"
            if has_start and len(segment_ids) != 1:
                return "Single source range requires exactly one segment"
            if has_start:
                segment = segments[segment_ids[0]]
                if int(allocation["source_line_start"]) != int(segment["source_line_start"]) or int(allocation["source_line_end"]) != int(segment["source_line_end"]):
                    return f"Allocation range does not match {segment_ids[0]}"
    return ""


def changed_transcript_id(path: str, transcripts: dict[str, dict[str, Any]]) -> str | None:
    for expanded in expand_git_rename_path(path):
        stem = Path(expanded).stem
        if stem in transcripts:
            return stem
    return None


def candidate_commits_for_transcript(
    transcript: dict[str, Any], commits: list[dict[str, Any]], commit_files: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    files_by_hash: dict[str, list[dict[str, Any]]] = {}
    for row in commit_files:
        files_by_hash.setdefault(row["commit_hash"], []).append(row)
    text = transcript["match_text"]
    tokens = set(transcript["match_tokens"])
    export_date = parse_datetime((transcript.get("export_date") or "") + "T23:59:59Z")
    candidates: list[dict[str, Any]] = []
    for commit in commits:
        score = 0.0
        reasons: list[str] = []
        if commit["full_hash"] in text or commit["short_hash"] in text:
            score += 1.0
            reasons.append("commit hash mentioned")
        changed_paths = [row["path"] for row in files_by_hash.get(commit["full_hash"], [])]
        archive = any(changed_transcript_id(path, {transcript["transcript_id"]: transcript}) for path in changed_paths)
        if archive:
            score += 0.2
            reasons.append("archive provenance only")
        exact_paths = [path for path in changed_paths if path.lower() in text]
        if exact_paths:
            score += min(0.5, 0.2 + 0.1 * len(exact_paths))
            reasons.append("changed path mentioned")
        subject_tokens = tokenize(commit["subject"] + " " + commit["body"])
        overlap = sorted(subject_tokens.intersection(tokens))
        if len(overlap) >= 2:
            score += min(0.5, len(overlap) / 12)
            reasons.append("subject tokens: " + ", ".join(overlap[:6]))
        path_overlap = tokenize(commit["changed_files"]).intersection(tokens)
        if len(path_overlap) >= 2:
            score += min(0.35, len(path_overlap) / 15)
            reasons.append("path/topic overlap")
        commit_time = parse_datetime(commit["author_date"])
        if export_date and commit_time and commit_time <= export_date:
            gap = (export_date - commit_time).total_seconds() / 86400
            if gap <= 1:
                score += 0.25
                reasons.append("commit before transcript within 1d")
            elif gap <= 3:
                score += 0.15
                reasons.append("commit before transcript within 3d")
            elif gap <= 7:
                score += 0.08
                reasons.append("commit before transcript within 7d")
        if score >= 0.18:
            candidates.append({
                "commit_hash": commit["full_hash"],
                "short_hash": commit["short_hash"],
                "subject": commit["subject"],
                "body": commit["body"],
                "changed_paths": changed_paths,
                "code_line_count": commit["code_line_count"],
                "test_line_count": commit["test_line_count"],
                "docs_line_count": commit["docs_line_count"],
                "score": round(min(score, 1.0), 4),
                "reasons": reasons,
                "archive_provenance": archive,
            })
    candidates.sort(key=lambda row: (-row["score"], row["commit_hash"]))
    return candidates[:16]


def review_input_digest(
    transcript: dict[str, Any], candidate_commits: list[dict[str, Any]], candidate_plans: list[dict[str, Any]],
    review_method_version: str,
) -> str:
    evidence = {
        "transcript_digest": transcript["normalized_content_digest"],
        "plans": [
            {
                "plan_id": plan["plan_id"],
                "source_ids": plan["source_plan_ids"],
                "source_content_digests": plan.get("source_content_digests", []),
                "line_count": plan["current_source_line_count"],
            }
            for plan in candidate_plans
        ],
        "commits": [
            {key: candidate[key] for key in ("commit_hash", "subject", "body", "changed_paths", "code_line_count", "test_line_count", "docs_line_count")}
            for candidate in candidate_commits
        ],
        "review_method_version": review_method_version,
    }
    return stable_json_digest(evidence)


def add_seconds(current: float | None, addition: float) -> float:
    return float(current or 0) + float(addition)


def metric_remainders(
    transcript: dict[str, Any], transcript_segments: list[dict[str, Any]], allocations: list[dict[str, Any]]
) -> dict[str, float | None]:
    weight_by_segment: dict[str, float] = {}
    for allocation in allocations:
        weight_by_segment[allocation["segment_id"]] = weight_by_segment.get(allocation["segment_id"], 0.0) + float(allocation["allocation_weight"])
    def remainder(key: str, total: float | None) -> float | None:
        if total is None:
            return None
        denominator = sum(float(segment.get(key, 0) or 0) for segment in transcript_segments)
        if key == "source_line_count":
            denominator = sum(float(segment["source_line_count"]) for segment in transcript_segments)
        if denominator <= 0:
            return 0.0
        allocated = sum(float(segment.get(key, 0) or 0) * min(weight_by_segment.get(segment["segment_id"], 0.0), 1.0) for segment in transcript_segments)
        return round(max(0.0, 1.0 - allocated / denominator), 10)
    return {
        "lines": remainder("source_line_count", float(transcript["line_count"])),
        "assistant_processing": remainder("assistant_processing_seconds", transcript.get("assistant_processing_seconds")),
        "user_response": remainder("user_response_seconds", transcript.get("user_response_seconds")),
        "back_and_forth": remainder("back_and_forth_count", float(transcript["back_and_forth_count"])),
    }


def remainders_match(configured: Any, computed: dict[str, float | None]) -> bool:
    if configured is None:
        return True
    if isinstance(configured, (int, float)):
        return all(value is None or math.isclose(float(configured), value, abs_tol=1e-6) for value in computed.values())
    if not isinstance(configured, dict):
        return False
    return all(
        key not in configured or computed.get(key) is None or math.isclose(float(configured[key]), float(computed[key]), abs_tol=1e-6)
        for key in computed
    )


def build_cross_references(
    ctx: AnalysisContext, data: dict[str, Any], review_only: bool = False
) -> dict[str, Any]:
    config_dir = ctx.repo_root / "Docs/Analysis/config"
    raw_manual = load_json(config_dir / "manual_links.json", {})
    manual = migrate_manual_links_v1_to_v2(raw_manual, ctx) if raw_manual.get("schema_version") != 2 else raw_manual
    theme_config = load_json(config_dir / "feature_themes.json", {"themes": {}}).get("themes", {})
    weights = load_json(config_dir / "difficulty_weights.json", {})

    commits = data["commits"]
    commit_files = data["commit_files"]
    plan_sources = data["plan_sources"]
    plans = data["plans"]
    transcripts = data["transcripts"]
    segments = data["transcript_segments"]
    commits_by_hash = {commit["full_hash"]: commit for commit in commits}
    plans_by_id = {str(plan["plan_id"]): plan for plan in plans}
    transcripts_by_id = {transcript["transcript_id"]: transcript for transcript in transcripts}
    segments_by_id = {segment["segment_id"]: segment for segment in segments}
    segments_by_transcript: dict[str, list[dict[str, Any]]] = {}
    for segment in segments:
        segments_by_transcript.setdefault(segment["transcript_id"], []).append(segment)
    validate_manual_config(
        manual, commits_by_hash, plans_by_id, transcripts_by_id, segments_by_id,
        strict_semantic=False,
    )

    plan_lookup = build_plan_filename_lookup(plans, plan_sources)
    for file_row in commit_files:
        if file_row["path_class"] != "docs" or not matching_plans_for_path(plan_lookup, file_row["path"]):
            continue
        changed_lines = int(file_row["additions"]) + int(file_row["deletions"])
        commit = commits_by_hash[file_row["commit_hash"]]
        commit["docs_line_count"] = max(0, int(commit["docs_line_count"]) - changed_lines)
        commit["plan_line_count"] = int(commit["plan_line_count"]) + changed_lines
        file_row["path_class"] = "plans"

    features = {commit["full_hash"]: create_feature_from_commit(commit) for commit in commits}
    for configured_hash, aliases in manual.get("commit_aliases", {}).items():
        commit_hash = resolve_config_hash(str(configured_hash), commits_by_hash)
        values = aliases if isinstance(aliases, list) else [aliases]
        features[commit_hash]["aliases"] = list(dict.fromkeys([
            *features[commit_hash]["aliases"],
            *(str(value) for value in values if value),
        ]))
    relationships: list[dict[str, Any]] = []
    feature_references: list[dict[str, Any]] = []
    plan_references: list[dict[str, Any]] = []
    feature_plan_references: list[dict[str, Any]] = []
    plan_revisions: list[dict[str, Any]] = []
    segment_allocations: list[dict[str, Any]] = []
    semantic_review_status: list[dict[str, Any]] = []

    for commit in commits:
        append_relationship(
            relationships,
            left_entity_type="feature", left_entity_id=commit["full_hash"],
            right_entity_type="commit", right_entity_id=commit["full_hash"],
            role="identity", evidence_type="canonical-git-identity", evidence_source=commit["full_hash"],
            confidence=1.0, allocation_weight=1.0, included_in_rollup_totals=True,
        )
        feature_references.append({
            "feature_id": commit["full_hash"], "source_type": "commit", "source_id": commit["full_hash"],
            "evidence_type": "canonical-git-identity", "confidence": 1.0, "allocation_weight": 1.0,
            "source_line": "", "included_in_totals": True,
        })

    commit_by_sequence = {commit["full_hash"]: commit["sequence"] for commit in commits}
    plan_change_rows: dict[str, list[tuple[int, dict[str, Any], dict[str, Any]]]] = {}
    for file_row in commit_files:
        if file_row["path_class"] != "plans" or file_row["additions"] + file_row["deletions"] <= 0:
            continue
        if any(normalize_repo_path(path) == CONTROL_PLAN_PATH for path in file_row.get("expanded_paths", [file_row["path"]])):
            continue
        for plan in matching_plans_for_path(plan_lookup, file_row["path"]):
            plan_change_rows.setdefault(str(plan["plan_id"]), []).append(
                (commit_by_sequence[file_row["commit_hash"]], file_row, commits_by_hash[file_row["commit_hash"]])
            )
    for plan_id, rows in plan_change_rows.items():
        plan = plans_by_id[plan_id]
        rows.sort(key=lambda value: (value[0], value[2]["full_hash"], value[1]["path"]))
        creation_assigned = False
        seen_version_paths: set[str] = set()
        for _, file_row, commit in rows:
            roles: list[str] = []
            status = str(file_row.get("status", ""))
            path_key = normalize_repo_path(expand_git_rename_path(file_row["path"])[-1])
            if not creation_assigned and status.startswith("A"):
                roles.append("creation")
                creation_assigned = True
                plan["creation_commit_id"] = commit["full_hash"]
            elif status.startswith("A") and path_key not in seen_version_paths:
                roles.extend(["version-addition", "plan-revision"])
            else:
                roles.append("plan-revision")
            seen_version_paths.add(path_key)
            if not creation_assigned:
                roles.insert(0, "creation")
                creation_assigned = True
                plan["creation_commit_id"] = commit["full_hash"]
                ctx.warn("plan", plan_id, "plan_creation_fallback", "Plan creation inferred from earliest nonzero content change")
            if any(role in {"plan-revision", "version-addition"} for role in roles):
                if commit["full_hash"] not in plan["revision_commit_ids"]:
                    plan["revision_commit_ids"].append(commit["full_hash"])
            plan["revision_additions"] += int(file_row["additions"])
            plan["revision_deletions"] += int(file_row["deletions"])
            if plan_id not in commit["linked_plan_ids"]:
                commit["linked_plan_ids"].append(plan_id)
            feature = features[commit["full_hash"]]
            if plan_id not in feature["linked_plan_ids"]:
                feature["linked_plan_ids"].append(plan_id)
            if commit["full_hash"] not in plan["associated_feature_ids"]:
                plan["associated_feature_ids"].append(commit["full_hash"])
            role_text = ";".join(dict.fromkeys(roles))
            revision = {
                "plan_id": plan_id, "commit_hash": commit["full_hash"], "short_hash": commit["short_hash"],
                "roles": role_text, "path": file_row["path"], "status": status,
                "additions": file_row["additions"], "deletions": file_row["deletions"],
                "author_date": commit["author_date"],
            }
            plan_revisions.append(revision)
            feature_plan_references.append({
                "feature_id": commit["full_hash"], "plan_id": plan_id, "roles": role_text,
                "evidence_type": "plan-file-history", "confidence": 1.0, "allocation_weight": 1.0,
                "included_in_direct_totals": True, "included_in_rollup_totals": False,
            })
            append_relationship(
                relationships,
                left_entity_type="feature", left_entity_id=commit["full_hash"],
                right_entity_type="plan", right_entity_id=plan_id, role=role_text,
                evidence_type="plan-file-history", evidence_source=file_row["path"], confidence=1.0,
                included_in_direct_totals=True,
            )

    for plan in plans:
        if not plan["creation_commit_id"]:
            ctx.warn("plan", plan["plan_id"], "plan_creation_unresolved", "No in-range content creation commit found")

    for transcript in transcripts:
        candidate_plan_ids: set[str] = set()
        for reference in transcript["references"]:
            for plan in matching_plans_for_path(plan_lookup, reference):
                candidate_plan_ids.add(str(plan["plan_id"]))
                plan_references.append({
                    "plan_id": str(plan["plan_id"]), "source_type": "transcript",
                    "source_id": transcript["transcript_id"], "role": "header-reference",
                    "evidence_type": "exact-reference", "confidence": 1.0, "source_line": 4,
                })
        hint = transcript_filename_plan_hint(transcript["transcript_id"])
        if hint and hint in plans_by_id:
            candidate_plan_ids.add(hint)
            plan_references.append({
                "plan_id": hint, "source_type": "transcript", "source_id": transcript["transcript_id"],
                "role": "filename-reference", "evidence_type": "plan-number", "confidence": 0.8, "source_line": 1,
            })
        for plan_id in sorted(candidate_plan_ids, key=lambda value: int(value) if value.isdigit() else sys.maxsize):
            transcript["associated_plan_ids"].append(plan_id)
            plan = plans_by_id[plan_id]
            if transcript["transcript_id"] not in plan["associated_transcript_ids"]:
                plan["associated_transcript_ids"].append(transcript["transcript_id"])
            append_relationship(
                relationships,
                left_entity_type="transcript", left_entity_id=transcript["transcript_id"],
                right_entity_type="plan", right_entity_id=plan_id, role="structural-reference",
                evidence_type="transcript-reference", evidence_source=transcript["path"], confidence=1.0,
                source_line=4,
            )

    for file_row in commit_files:
        if file_row["path_class"] != "transcripts":
            continue
        transcript_id = changed_transcript_id(file_row["path"], transcripts_by_id)
        if not transcript_id:
            continue
        transcript = transcripts_by_id[transcript_id]
        commit = commits_by_hash[file_row["commit_hash"]]
        if commit["full_hash"] not in transcript["archive_commit_ids"]:
            transcript["archive_commit_ids"].append(commit["full_hash"])
        if transcript_id not in commit["linked_transcript_ids"]:
            commit["linked_transcript_ids"].append(transcript_id)
        feature = features[commit["full_hash"]]
        if transcript_id not in feature["linked_transcript_ids"]:
            feature["linked_transcript_ids"].append(transcript_id)
        append_relationship(
            relationships,
            left_entity_type="commit", left_entity_id=commit["full_hash"],
            right_entity_type="transcript", right_entity_id=transcript_id,
            role="transcript-archive", evidence_type="changed-transcript-path", evidence_source=file_row["path"],
            confidence=1.0, allocation_weight=0.0, included_in_direct_totals=False,
            included_in_rollup_totals=False,
        )
        for plan_id in transcript["associated_plan_ids"]:
            plan = plans_by_id[plan_id]
            if commit["full_hash"] not in plan["transcript_archive_commit_ids"]:
                plan["transcript_archive_commit_ids"].append(commit["full_hash"])
            feature_plan_references.append({
                "feature_id": commit["full_hash"], "plan_id": plan_id, "roles": "transcript-archive",
                "evidence_type": "transcript-archive-provenance", "confidence": 1.0,
                "allocation_weight": 0.0, "included_in_direct_totals": False,
                "included_in_rollup_totals": False,
            })
            append_relationship(
                relationships,
                left_entity_type="feature", left_entity_id=commit["full_hash"],
                right_entity_type="plan", right_entity_id=plan_id, role="transcript-archive",
                evidence_type="transcript-archive-provenance", evidence_source=file_row["path"],
                confidence=1.0, allocation_weight=0.0,
            )

    candidate_commits_by_transcript: dict[str, list[dict[str, Any]]] = {}
    candidate_plans_by_transcript: dict[str, list[dict[str, Any]]] = {}
    for transcript in transcripts:
        candidates = candidate_commits_for_transcript(transcript, commits, commit_files)
        candidate_commits_by_transcript[transcript["transcript_id"]] = candidates
        plan_candidates = [plans_by_id[plan_id] for plan_id in transcript["associated_plan_ids"] if plan_id in plans_by_id]
        candidate_plans_by_transcript[transcript["transcript_id"]] = plan_candidates
        transcript["review_input_digest"] = review_input_digest(
            transcript, candidates, plan_candidates, str(manual.get("review_method_version", REVIEW_METHOD_VERSION))
        )
        for segment in segments_by_transcript.get(transcript["transcript_id"], []):
            segment["candidate_feature_ids"] = [candidate["commit_hash"] for candidate in candidates]
            segment["candidate_plan_ids"] = [plan["plan_id"] for plan in plan_candidates]

    for configured_hash, edges in manual.get("commit_transcripts", {}).items():
        commit_hash = resolve_config_hash(str(configured_hash), commits_by_hash)
        for edge in edges if isinstance(edges, list) else [edges]:
            transcript_id = str(edge.get("transcript_id", ""))
            if transcript_id not in transcripts_by_id:
                raise AnalysisError(f"Configured transcript does not exist: {transcript_id}")
            role = str(edge.get("role", "membership"))
            if transcript_id not in features[commit_hash]["linked_transcript_ids"]:
                features[commit_hash]["linked_transcript_ids"].append(transcript_id)
            if commit_hash not in transcripts_by_id[transcript_id]["associated_feature_ids"]:
                transcripts_by_id[transcript_id]["associated_feature_ids"].append(commit_hash)
            append_relationship(
                relationships,
                left_entity_type="feature", left_entity_id=commit_hash,
                right_entity_type="transcript", right_entity_id=transcript_id, role=role,
                evidence_type="reviewed-config", evidence_source="manual_links.json", confidence=1.0,
                allocation_weight=0.0, included_in_rollup_totals=False,
                manual_override_state="include", reviewed_by=edge.get("reviewed_by", ""),
                reviewed_at=edge.get("reviewed_at", ""), review_method=manual.get("review_method_version", ""),
                evidence_note=edge.get("evidence_note", ""), source_digest=edge.get("transcript_digest", ""),
            )

    for configured_hash, edges in manual.get("commit_plans", {}).items():
        commit_hash = resolve_config_hash(str(configured_hash), commits_by_hash)
        for edge in edges if isinstance(edges, list) else [edges]:
            plan_id = str(edge.get("plan_id", ""))
            if plan_id not in plans_by_id:
                raise AnalysisError(f"Configured Plan does not exist: {plan_id}")
            roles = edge.get("roles") or [edge.get("role", "implementation")]
            role_text = ";".join(dict.fromkeys(str(role) for role in roles))
            feature = features[commit_hash]
            plan = plans_by_id[plan_id]
            if plan_id not in feature["linked_plan_ids"]:
                feature["linked_plan_ids"].append(plan_id)
            if plan_id not in commits_by_hash[commit_hash]["linked_plan_ids"]:
                commits_by_hash[commit_hash]["linked_plan_ids"].append(plan_id)
            if commit_hash not in plan["associated_feature_ids"]:
                plan["associated_feature_ids"].append(commit_hash)
            if "implementation" in roles and commit_hash not in plan["implementation_commit_ids"]:
                plan["implementation_commit_ids"].append(commit_hash)
            feature_plan_references.append({
                "feature_id": commit_hash, "plan_id": plan_id, "roles": role_text,
                "evidence_type": "reviewed-config", "confidence": 1.0,
                "allocation_weight": float(edge.get("allocation_weight", 1.0)),
                "included_in_direct_totals": "creation" in roles or "plan-revision" in roles,
                "included_in_rollup_totals": "implementation" in roles,
            })
            append_relationship(
                relationships,
                left_entity_type="feature", left_entity_id=commit_hash,
                right_entity_type="plan", right_entity_id=plan_id, role=role_text,
                evidence_type="reviewed-config", evidence_source="manual_links.json", confidence=1.0,
                allocation_weight=float(edge.get("allocation_weight", 1.0)),
                included_in_direct_totals="creation" in roles or "plan-revision" in roles,
                included_in_rollup_totals="implementation" in roles, manual_override_state="include",
                reviewed_by=edge.get("reviewed_by", ""), reviewed_at=edge.get("reviewed_at", ""),
                review_method=manual.get("review_method_version", ""), evidence_note=edge.get("evidence_note", ""),
            )

    for plan_id, edges in manual.get("plan_transcripts", {}).items():
        plan_id = str(plan_id)
        for edge in edges if isinstance(edges, list) else [edges]:
            transcript_id = str(edge.get("transcript_id", ""))
            if transcript_id not in transcripts_by_id:
                raise AnalysisError(f"Configured transcript does not exist: {transcript_id}")
            if transcript_id not in plans_by_id[plan_id]["associated_transcript_ids"]:
                plans_by_id[plan_id]["associated_transcript_ids"].append(transcript_id)
            if plan_id not in transcripts_by_id[transcript_id]["associated_plan_ids"]:
                transcripts_by_id[transcript_id]["associated_plan_ids"].append(plan_id)
            append_relationship(
                relationships,
                left_entity_type="plan", left_entity_id=plan_id,
                right_entity_type="transcript", right_entity_id=transcript_id,
                role=str(edge.get("role", "membership")), evidence_type="reviewed-config",
                evidence_source="manual_links.json", confidence=1.0, allocation_weight=0.0,
                manual_override_state="include", evidence_note=edge.get("evidence_note", ""),
            )

    reviews = manual.get("transcript_reviews", {})
    for transcript in transcripts:
        transcript_id = transcript["transcript_id"]
        review = reviews.get(transcript_id)
        status = "unreviewed"
        message = "No reviewed semantic allocation exists"
        tentative: list[dict[str, Any]] = []
        if review:
            configured_transcript_digest = review.get("normalized_content_digest") or review.get("transcript_digest")
            if configured_transcript_digest != transcript["normalized_content_digest"] or review.get("review_input_digest") != transcript["review_input_digest"]:
                status = "stale"
                message = "Transcript or review-input digest changed"
            elif review.get("review_status") != "reviewed":
                status = "unreviewed"
                message = "Review status is not reviewed"
            elif semantic_error := semantic_review_error(transcript_id, review, segments_by_id):
                status = "invalid"
                message = semantic_error
            else:
                status = "reviewed"
                message = "Reviewed allocation accepted"
                for allocation_key, entity_type, entity_key in (
                    ("feature_allocations", "feature", "commit_hash"),
                    ("plan_allocations", "plan", "plan_id"),
                ):
                    for allocation in review.get(allocation_key, []):
                        entity_id = str(allocation.get(entity_key, ""))
                        if entity_type == "feature":
                            entity_id = resolve_config_hash(entity_id, commits_by_hash)
                        segment_ids = list(allocation.get("segment_ids", [])) or [
                            segment["segment_id"] for segment in segments_by_transcript.get(transcript_id, [])
                        ]
                        weight = float(allocation.get("allocation_weight", 1.0))
                        for segment_id in segment_ids:
                            segment = segments_by_id[segment_id]
                            range_start = allocation.get("source_line_start")
                            range_end = allocation.get("source_line_end")
                            if range_start is not None and int(range_start) != segment["source_line_start"]:
                                status = "invalid"
                                message = f"Configured source start does not match {segment_id}"
                            if range_end is not None and int(range_end) != segment["source_line_end"]:
                                status = "invalid"
                                message = f"Configured source end does not match {segment_id}"
                            tentative.append({
                                "transcript_id": transcript_id, "segment_id": segment_id,
                                "entity_type": entity_type, "entity_id": entity_id,
                                "role": str(allocation.get("role", "work" if entity_type == "feature" else "implementation")),
                                "allocation_weight": weight, "source_line_start": segment["source_line_start"],
                                "source_line_end": segment["source_line_end"], "review_status": "reviewed",
                                "reviewed_config_entry_id": str(allocation.get("entry_id", "")),
                                "confidence": float(allocation.get("confidence", 1.0)),
                                "evidence_note": allocation.get("evidence_note", ""),
                                "included_in_direct_totals": bool(allocation.get("included_in_direct_totals", entity_type == "plan" and allocation.get("role") == "direct")),
                                "included_in_rollup_totals": bool(allocation.get("included_in_rollup_totals", entity_type == "feature" or allocation.get("role") == "implementation")),
                            })
                for entity_type in ("feature", "plan"):
                    totals: dict[str, float] = {}
                    for row in tentative:
                        if row["entity_type"] == entity_type:
                            totals[row["segment_id"]] = totals.get(row["segment_id"], 0.0) + row["allocation_weight"]
                    if any(total > 1.000001 for total in totals.values()):
                        status = "invalid"
                        message = f"{entity_type} segment allocations exceed 1.0"
                if status == "reviewed":
                    feature_rows = [row for row in tentative if row["entity_type"] == "feature"]
                    plan_rows = [row for row in tentative if row["entity_type"] == "plan"]
                    feature_remainder = metric_remainders(transcript, segments_by_transcript.get(transcript_id, []), feature_rows)
                    plan_remainder = metric_remainders(transcript, segments_by_transcript.get(transcript_id, []), plan_rows)
                    if not remainders_match(review.get("feature_unallocated_remainder"), feature_remainder) or not remainders_match(review.get("plan_unallocated_remainder"), plan_remainder):
                        status = "invalid"
                        message = "Configured unallocated remainder does not conserve transcript metrics"
                    else:
                        transcript["feature_unallocated_remainder"] = feature_remainder
                        transcript["plan_unallocated_remainder"] = plan_remainder
                        if any((value or 0) > 0.000001 for value in [*feature_remainder.values(), *plan_remainder.values()] if value is not None):
                            ctx.warn("transcript", transcript_id, "semantic_review_unallocated", review.get("unallocated_reason") or "Reviewed transcript retains unallocated metric remainder")
        if status != "reviewed":
            tentative = []
            category = {
                "unreviewed": "semantic_review_required",
                "stale": "semantic_review_stale",
                "invalid": "semantic_review_invalid",
            }[status]
            ctx.warn("transcript", transcript_id, category, message)
        transcript["semantic_review_status"] = status
        transcript["allocation_status"] = status
        for segment in segments_by_transcript.get(transcript_id, []):
            segment["review_status"] = status
        semantic_review_status.append({
            "transcript_id": transcript_id, "review_status": status,
            "normalized_content_digest": transcript["normalized_content_digest"],
            "configured_content_digest": (review or {}).get("normalized_content_digest", (review or {}).get("transcript_digest", "")),
            "review_input_digest": transcript["review_input_digest"],
            "configured_review_input_digest": (review or {}).get("review_input_digest", ""),
            "reviewed_by": (review or {}).get("reviewed_by", ""),
            "reviewed_at": (review or {}).get("reviewed_at", ""),
            "review_method": manual.get("review_method_version", ""),
            "message": message,
        })
        segment_allocations.extend(tentative)

    segment_by_id = segments_by_id
    for allocation in segment_allocations:
        transcript = transcripts_by_id[allocation["transcript_id"]]
        segment = segment_by_id[allocation["segment_id"]]
        transcript_segments = segments_by_transcript[allocation["transcript_id"]]
        segment_source_total = sum(float(item["source_line_count"]) for item in transcript_segments) or 1.0
        overhead_factor = float(transcript["line_count"]) / segment_source_total
        weight = float(allocation["allocation_weight"])
        allocation["allocated_source_lines"] = segment["source_line_count"] * overhead_factor * weight
        timing_available = transcript.get("elapsed_seconds") is not None
        allocation["allocated_assistant_processing_seconds"] = segment["assistant_processing_seconds"] * weight if timing_available else None
        allocation["allocated_user_response_seconds"] = segment["user_response_seconds"] * weight if timing_available else None
        allocation["allocated_visible_elapsed_seconds"] = segment["valid_atomic_elapsed_seconds"] * weight if timing_available else None
        allocation["allocated_back_and_forth_count"] = segment["back_and_forth_count"] * weight
        allocation["allocated_turn_count"] = len(segment["turn_ids"]) * weight
        if allocation["entity_type"] == "feature":
            feature = features[allocation["entity_id"]]
            if allocation["transcript_id"] not in feature["linked_transcript_ids"]:
                feature["linked_transcript_ids"].append(allocation["transcript_id"])
            if feature["feature_id"] not in transcript["associated_feature_ids"]:
                transcript["associated_feature_ids"].append(feature["feature_id"])
            feature["total_transcript_lines"] += allocation["allocated_source_lines"]
            feature["back_and_forth_count"] += allocation["allocated_back_and_forth_count"]
            feature["allocated_turn_count"] += allocation["allocated_turn_count"]
            if timing_available:
                feature["total_visible_conversation_elapsed_seconds"] = add_seconds(feature["total_visible_conversation_elapsed_seconds"], allocation["allocated_visible_elapsed_seconds"] or 0)
                feature["total_assistant_processing_seconds"] = add_seconds(feature["total_assistant_processing_seconds"], allocation["allocated_assistant_processing_seconds"] or 0)
                feature["total_user_response_seconds"] = add_seconds(feature["total_user_response_seconds"], allocation["allocated_user_response_seconds"] or 0)
            else:
                feature["unavailable_timing_count"] += 1
            append_relationship(
                relationships,
                left_entity_type="feature", left_entity_id=feature["feature_id"],
                right_entity_type="transcript", right_entity_id=allocation["transcript_id"],
                role=allocation["role"], evidence_type="reviewed-segment", evidence_source=allocation["segment_id"],
                source_line=allocation["source_line_start"], confidence=allocation["confidence"], allocation_weight=weight,
                included_in_rollup_totals=True, manual_override_state="reviewed-include",
                review_method=manual.get("review_method_version", ""), evidence_note=allocation["evidence_note"],
                source_digest=transcript["normalized_content_digest"],
            )
        else:
            plan = plans_by_id[allocation["entity_id"]]
            if allocation["transcript_id"] not in plan["associated_transcript_ids"]:
                plan["associated_transcript_ids"].append(allocation["transcript_id"])
            if allocation["entity_id"] not in transcript["associated_plan_ids"]:
                transcript["associated_plan_ids"].append(allocation["entity_id"])
            if allocation["role"] == "direct":
                plan["direct_transcript_lines"] += allocation["allocated_source_lines"]
                if timing_available:
                    plan["direct_visible_elapsed_seconds"] = add_seconds(plan["direct_visible_elapsed_seconds"], allocation["allocated_visible_elapsed_seconds"] or 0)
            else:
                plan["implementation_transcript_lines"] += allocation["allocated_source_lines"]
                if timing_available:
                    plan["implementation_visible_elapsed_seconds"] = add_seconds(plan["implementation_visible_elapsed_seconds"], allocation["allocated_visible_elapsed_seconds"] or 0)
            plan["back_and_forth_count"] += allocation["allocated_back_and_forth_count"]
            if timing_available:
                plan["total_visible_conversation_elapsed_seconds"] = add_seconds(plan["total_visible_conversation_elapsed_seconds"], allocation["allocated_visible_elapsed_seconds"] or 0)
                plan["total_assistant_processing_seconds"] = add_seconds(plan["total_assistant_processing_seconds"], allocation["allocated_assistant_processing_seconds"] or 0)
                plan["total_user_response_seconds"] = add_seconds(plan["total_user_response_seconds"], allocation["allocated_user_response_seconds"] or 0)
            append_relationship(
                relationships,
                left_entity_type="plan", left_entity_id=plan["plan_id"],
                right_entity_type="transcript", right_entity_id=allocation["transcript_id"],
                role=allocation["role"], evidence_type="reviewed-segment", evidence_source=allocation["segment_id"],
                source_line=allocation["source_line_start"], confidence=allocation["confidence"], allocation_weight=weight,
                included_in_direct_totals=allocation["role"] == "direct", included_in_rollup_totals=allocation["role"] != "direct",
                manual_override_state="reviewed-include", review_method=manual.get("review_method_version", ""),
                evidence_note=allocation["evidence_note"], source_digest=transcript["normalized_content_digest"],
            )

    allocations_by_transcript: dict[str, list[dict[str, Any]]] = {}
    for allocation in segment_allocations:
        allocations_by_transcript.setdefault(allocation["transcript_id"], []).append(allocation)
    for transcript_id, allocations in allocations_by_transcript.items():
        feature_ids = sorted({row["entity_id"] for row in allocations if row["entity_type"] == "feature"})
        plan_ids = sorted({row["entity_id"] for row in allocations if row["entity_type"] == "plan"})
        transcript = transcripts_by_id[transcript_id]
        transcript["linked_feature_ids"] = feature_ids
        transcript["allocation_total"] = round(1.0 - float((transcript.get("feature_unallocated_remainder") or {}).get("lines", 1.0) or 0), 10)
        for feature_id in feature_ids:
            for plan_id in plan_ids:
                role_set = {
                    row["role"] for row in allocations
                    if row["entity_type"] == "plan" and row["entity_id"] == plan_id
                }
                role = "implementation" if "implementation" in role_set else "direct"
                feature = features[feature_id]
                plan = plans_by_id[plan_id]
                if plan_id not in feature["linked_plan_ids"]:
                    feature["linked_plan_ids"].append(plan_id)
                if feature_id not in plan["associated_feature_ids"]:
                    plan["associated_feature_ids"].append(feature_id)
                if role == "implementation" and feature_id not in plan["implementation_commit_ids"]:
                    plan["implementation_commit_ids"].append(feature_id)
                if not any(row["feature_id"] == feature_id and row["plan_id"] == plan_id and role in row["roles"] for row in feature_plan_references):
                    feature_plan_references.append({
                        "feature_id": feature_id, "plan_id": plan_id, "roles": role,
                        "evidence_type": "reviewed-transcript-segments", "confidence": 1.0,
                        "allocation_weight": 1.0 / max(len(plan_ids), 1),
                        "included_in_direct_totals": role == "direct", "included_in_rollup_totals": role == "implementation",
                    })

    for plan in plans:
        implementation_ids = list(dict.fromkeys(plan["implementation_commit_ids"]))
        for feature_id in implementation_ids:
            feature = features[feature_id]
            shared_count = sum(
                1 for other in plans if feature_id in other["implementation_commit_ids"]
            ) or 1
            plan["implementation_code_lines"] += feature["total_code_lines_changed"] / shared_count
            plan["implementation_test_lines"] += feature["total_test_lines_changed"] / shared_count
            plan["implementation_documentation_lines"] += feature["total_documentation_lines_changed"] / shared_count
        dates = [
            parse_date(commits_by_hash[commit_id]["author_date"])
            for commit_id in set(plan["associated_feature_ids"] + plan["revision_commit_ids"])
            if commit_id in commits_by_hash
        ]
        dates += [transcripts_by_id[item]["export_date"] for item in plan["associated_transcript_ids"] if transcripts_by_id[item]["export_date"]]
        dates = [date for date in dates if date]
        plan["first_evidence_date"] = min(dates) if dates else ""
        plan["last_evidence_date"] = max(dates) if dates else ""

    apply_difficulty_scores(features, weights)
    apply_plan_difficulty_scores(plans_by_id, weights)
    themes, theme_references, theme_coverage = build_themes(
        ctx, data, features, plans_by_id, theme_config, manual
    )

    for feature in features.values():
        feature["linked_plan_ids"] = sorted(set(feature["linked_plan_ids"]), key=lambda value: int(value) if value.isdigit() else sys.maxsize)
        feature["linked_transcript_ids"] = sorted(set(feature["linked_transcript_ids"]))
        feature["parent_theme_ids"] = sorted(set(feature["parent_theme_ids"]))
        feature["warning_count"] = sum(
            warning.source_type == "commit" and warning.source_id in {feature["feature_id"], feature["short_hash"]}
            for warning in ctx.warnings
        )
    for plan in plans:
        plan["associated_feature_ids"] = sorted(set(plan["associated_feature_ids"]))
        plan["associated_transcript_ids"] = sorted(set(plan["associated_transcript_ids"]))
        plan["parent_theme_ids"] = sorted(set(plan["parent_theme_ids"]))
        plan["warning_count"] = sum(warning.source_type == "plan" and warning.source_id == plan["plan_id"] for warning in ctx.warnings)
    for transcript in transcripts:
        transcript["associated_feature_ids"] = sorted(set(transcript["associated_feature_ids"]))
        transcript["linked_feature_ids"] = sorted(set(transcript["linked_feature_ids"]))
        transcript["associated_plan_ids"] = sorted(set(transcript["associated_plan_ids"]), key=lambda value: int(value) if value.isdigit() else sys.maxsize)
        transcript["archive_commit_ids"] = sorted(set(transcript["archive_commit_ids"]))

    validate_model_invariants(data, features, plans_by_id)
    if ctx.require_reviewed_associations:
        incomplete = [row for row in semantic_review_status if row["review_status"] != "reviewed"]
        if incomplete:
            raise AnalysisError(f"{len(incomplete)} transcripts lack current valid semantic review")

    data.update({
        "features": sorted(features.values(), key=lambda row: row["feature_id"]),
        "plans": sorted(plans_by_id.values(), key=plan_order_sort_key),
        "themes": sorted(themes, key=lambda row: row["theme_id"]),
        "feature_references": feature_references,
        "plan_references": plan_references,
        "feature_plan_references": feature_plan_references,
        "plan_revisions": plan_revisions,
        "segment_allocations": segment_allocations,
        "semantic_review_status": semantic_review_status,
        "relationships": relationships,
        "theme_references": theme_references,
        "theme_coverage": theme_coverage,
        "candidate_commits_by_transcript": candidate_commits_by_transcript,
        "candidate_plans_by_transcript": candidate_plans_by_transcript,
        "difficulty_weights": weights,
        "manual_config": manual,
    })
    return data


def percentile_rank(value: float | None, values: list[float]) -> float:
    if value is None or value <= 0 or not values:
        return 0.0
    return sum(item <= value for item in sorted(values)) / len(values) * 100.0


def difficulty_label(score: float) -> str:
    if score >= 75:
        return "Very High"
    if score >= 50:
        return "High"
    if score >= 25:
        return "Moderate"
    return "Low"


def score_difficulty_cohort(
    records: Iterable[dict[str, Any]], weights: dict[str, float], signal_builder: Any
) -> None:
    rows = list(records)
    signals_by_record = {id(record): signal_builder(record) for record in rows}
    populations: dict[str, list[float]] = {}
    for signal_name in weights:
        populations[signal_name] = [
            float(signals_by_record[id(record)].get(signal_name) or 0)
            for record in rows
        ]
    for record in rows:
        signals = signals_by_record[id(record)]
        score = 0.0
        coverage = 0.0
        for signal_name, configured_weight in weights.items():
            value = signals.get(signal_name)
            if value is not None:
                coverage += float(configured_weight)
            score += percentile_rank(None if value is None else float(value), populations[signal_name]) * float(configured_weight)
        record["difficulty_inputs"] = signals
        record["difficulty_score"] = round(score, 2)
        record["difficulty_label"] = difficulty_label(score)
        record["difficulty_weight_coverage"] = round(coverage, 4)


def apply_difficulty_scores(
    features: dict[str, dict[str, Any]], weights: dict[str, float]
) -> None:
    score_difficulty_cohort(
        features.values(),
        weights,
        lambda feature: {
            "code_lines": feature["total_code_lines_changed"],
            "transcript_lines": feature["total_transcript_lines"],
            "plan_lines": feature["total_plan_lines"],
            "elapsed_time": feature["total_visible_conversation_elapsed_seconds"],
            "assistant_processing_time": feature["total_assistant_processing_seconds"],
            "back_and_forth_count": feature["back_and_forth_count"],
        },
    )


def apply_plan_difficulty_scores(
    plans: dict[str, dict[str, Any]], weights: dict[str, float]
) -> None:
    score_difficulty_cohort(
        plans.values(),
        weights,
        lambda plan: {
            "code_lines": plan["implementation_code_lines"],
            "transcript_lines": plan["direct_transcript_lines"] + plan["implementation_transcript_lines"],
            "plan_lines": plan["current_source_line_count"],
            "elapsed_time": plan["total_visible_conversation_elapsed_seconds"],
            "assistant_processing_time": plan["total_assistant_processing_seconds"],
            "back_and_forth_count": plan["back_and_forth_count"],
        },
    )


def configured_theme_edges(
    manual: dict[str, Any], key: str, theme_id: str
) -> tuple[set[str], set[str]]:
    raw = manual.get(key, {}).get(theme_id, {})
    if isinstance(raw, list):
        includes = {str(value) for value in raw}
        return includes, set()
    if not isinstance(raw, dict):
        return set(), set()
    def ids(values: Any) -> set[str]:
        result: set[str] = set()
        for value in values if isinstance(values, list) else [values]:
            if isinstance(value, str):
                result.add(value)
            elif isinstance(value, dict):
                result.add(str(value.get("commit_hash") or value.get("plan_id") or value.get("id") or ""))
        result.discard("")
        return result
    return ids(raw.get("include", [])), ids(raw.get("exclude", []))


def build_themes(
    ctx: AnalysisContext,
    data: dict[str, Any],
    features: dict[str, dict[str, Any]],
    plans: dict[str, dict[str, Any]],
    theme_config: dict[str, Any],
    manual: dict[str, Any],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    commit_files_by_hash: dict[str, list[dict[str, Any]]] = {}
    for row in data["commit_files"]:
        commit_files_by_hash.setdefault(row["commit_hash"], []).append(row)
    commits_by_hash = {commit["full_hash"]: commit for commit in data["commits"]}
    themes: list[dict[str, Any]] = []
    references: list[dict[str, Any]] = []
    theme_coverage: list[dict[str, Any]] = []
    for theme_id, definition in theme_config.items():
        themes.append({
            "theme_id": theme_id,
            "display_name": definition.get("display_name", theme_id),
            "description": definition.get("description", ""),
            "aliases": list(definition.get("aliases", [])),
            "keywords": list(definition.get("keywords", [])),
            "documentation_paths": list(definition.get("documentation_paths", [])),
            "child_feature_ids": [],
            "child_plan_ids": [],
            "linked_plan_ids": [],
            "linked_transcript_ids": [],
            "linked_commit_ids": [],
            "documentation_ids": [],
            "feature_inherited_transcript_lines": 0.0,
            "feature_allocated_transcript_lines": 0.0,
            "feature_inherited_code_lines": 0.0,
            "feature_allocated_code_lines": 0.0,
            "feature_inherited_elapsed_seconds": 0.0,
            "feature_allocated_elapsed_seconds": 0.0,
            "plan_direct_lines": 0.0,
            "plan_implementation_code_lines": 0.0,
            "plan_allocated_elapsed_seconds": 0.0,
            "child_feature_count": 0,
            "child_plan_count": 0,
            "commit_count": 0,
            "documentation_page_count": 0,
            "mean_feature_difficulty": 0.0,
            "median_feature_difficulty": 0.0,
            "max_feature_difficulty": 0.0,
            "mean_plan_difficulty": 0.0,
            "median_plan_difficulty": 0.0,
            "max_plan_difficulty": 0.0,
            "configured_definition_preserved": True,
        })
    themes_by_id = {theme["theme_id"]: theme for theme in themes}

    for theme_id, definition in theme_config.items():
        theme = themes_by_id[theme_id]
        manual_includes, manual_excludes = configured_theme_edges(manual, "theme_commits", theme_id)
        include_hashes = set(str(value) for value in definition.get("include_commit_hashes", [])) | manual_includes
        exclude_hashes = set(str(value) for value in definition.get("exclude_commit_hashes", [])) | manual_excludes
        resolved_includes: set[str] = set()
        resolved_excludes: set[str] = set()
        for value in include_hashes:
            try:
                resolved_includes.add(resolve_config_hash(value, commits_by_hash))
            except AnalysisError:
                ctx.warn("theme", theme_id, "theme_commit_unresolved", f"Theme include hash not in report range: {value}")
        for value in exclude_hashes:
            try:
                resolved_excludes.add(resolve_config_hash(value, commits_by_hash))
            except AnalysisError:
                ctx.warn("theme", theme_id, "theme_commit_unresolved", f"Theme exclude hash not in report range: {value}")
        include_paths = set(definition.get("include_commit_paths", []))
        include_prefixes = tuple(definition.get("include_commit_path_prefixes", []))
        aliases = [str(value).lower() for value in definition.get("aliases", [])]
        keywords = [str(value).lower() for value in definition.get("keywords", [])]
        for feature_id, feature in features.items():
            if feature_id in resolved_excludes:
                references.append({
                    "theme_id": theme_id, "entity_type": "feature", "entity_id": feature_id,
                    "relationship_type": "exclude", "evidence_source": "explicit negative Theme edge",
                    "confidence": 1.0, "allocation_weight": 0.0,
                })
                continue
            evidence = ""
            confidence = 0.0
            if feature_id in resolved_includes:
                evidence, confidence = "explicit Theme include", 1.0
            touched_paths = {path for row in commit_files_by_hash.get(feature_id, []) for path in row.get("expanded_paths", [row["path"]])}
            if not evidence and touched_paths.intersection(include_paths):
                evidence, confidence = "configured exact path", 1.0
            if not evidence and include_prefixes and any(path.startswith(include_prefixes) for path in touched_paths):
                evidence, confidence = "configured path prefix", 1.0
            if not evidence and definition.get("auto_keyword_match", True):
                match_text = " ".join([
                    feature["subject"], feature["body"], feature["changed_paths"], feature["scope"],
                    " ".join(feature["aliases"]),
                ]).lower()
                alias_hits = [value for value in aliases if value and value in match_text]
                keyword_hits = [value for value in keywords if value and value in match_text]
                if alias_hits:
                    evidence, confidence = "alias: " + ", ".join(alias_hits[:4]), 0.9
                elif keyword_hits:
                    evidence = "keywords: " + ", ".join(keyword_hits[:6])
                    confidence = min(0.85, 0.45 + 0.08 * len(keyword_hits))
            if evidence:
                theme["child_feature_ids"].append(feature_id)
                feature["parent_theme_ids"].append(theme_id)
                references.append({
                    "theme_id": theme_id, "entity_type": "feature", "entity_id": feature_id,
                    "relationship_type": "include", "evidence_source": evidence,
                    "confidence": confidence, "allocation_weight": 0.0,
                })

        plan_includes, plan_excludes = configured_theme_edges(manual, "theme_plans", theme_id)
        for plan_id, plan in plans.items():
            if plan_id in plan_excludes:
                references.append({
                    "theme_id": theme_id, "entity_type": "plan", "entity_id": plan_id,
                    "relationship_type": "exclude", "evidence_source": "explicit negative Theme edge",
                    "confidence": 1.0, "allocation_weight": 0.0,
                })
                continue
            evidence = ""
            confidence = 0.0
            if plan_id in plan_includes:
                evidence, confidence = "explicit Plan Theme include", 1.0
            elif definition.get("auto_keyword_match", True):
                text = (plan["display_title"] + " " + " ".join(plan["source_paths"])).lower()
                hits = [value for value in aliases + keywords if value and value in text]
                if hits:
                    evidence, confidence = "Plan topic: " + ", ".join(hits[:5]), 0.75
            if evidence:
                theme["child_plan_ids"].append(plan_id)
                plan["parent_theme_ids"].append(theme_id)
                references.append({
                    "theme_id": theme_id, "entity_type": "plan", "entity_id": plan_id,
                    "relationship_type": "include", "evidence_source": evidence,
                    "confidence": confidence, "allocation_weight": 0.0,
                })

    for feature in features.values():
        feature["parent_theme_ids"] = sorted(set(feature["parent_theme_ids"]))
        if feature["parent_theme_ids"]:
            feature["theme_coverage_state"] = "assigned"
        else:
            feature["theme_coverage_state"] = "missing_theme_assignment"
            ctx.warn(
                "feature", feature["feature_id"], "missing_theme_assignment",
                "Commit has no accepted Theme; no fallback Theme was fabricated",
            )
        theme_coverage.append({
            "feature_id": feature["feature_id"], "short_hash": feature["short_hash"],
            "theme_ids": feature["parent_theme_ids"], "theme_count": len(feature["parent_theme_ids"]),
            "coverage_state": feature["theme_coverage_state"],
        })

    docs_by_path = {doc["path"]: doc for doc in data["user_documentation"]}
    for theme_id, definition in theme_config.items():
        theme = themes_by_id[theme_id]
        for path in definition.get("documentation_paths", []):
            doc = docs_by_path.get(path)
            if doc:
                theme["documentation_ids"].append(doc["documentation_id"])
                doc["linked_theme_ids"].append(theme_id)
                references.append({
                    "theme_id": theme_id, "entity_type": "documentation", "entity_id": doc["documentation_id"],
                    "relationship_type": "documentation", "evidence_source": "configured documentation path",
                    "confidence": 1.0, "allocation_weight": 0.0,
                })

    for theme in themes:
        feature_scores: list[float] = []
        plan_scores: list[float] = []
        for feature_id in sorted(set(theme["child_feature_ids"])):
            feature = features[feature_id]
            share = 1 / max(len(feature["parent_theme_ids"]), 1)
            theme["feature_inherited_transcript_lines"] += feature["total_transcript_lines"]
            theme["feature_allocated_transcript_lines"] += feature["total_transcript_lines"] * share
            theme["feature_inherited_code_lines"] += feature["total_code_lines_changed"]
            theme["feature_allocated_code_lines"] += feature["total_code_lines_changed"] * share
            theme["feature_inherited_elapsed_seconds"] += float(feature["total_visible_conversation_elapsed_seconds"] or 0)
            theme["feature_allocated_elapsed_seconds"] += float(feature["total_visible_conversation_elapsed_seconds"] or 0) * share
            theme["linked_commit_ids"].append(feature_id)
            theme["linked_transcript_ids"].extend(feature["linked_transcript_ids"])
            feature_scores.append(feature["difficulty_score"])
        for plan_id in sorted(set(theme["child_plan_ids"]), key=lambda value: int(value) if value.isdigit() else sys.maxsize):
            plan = plans[plan_id]
            share = 1 / max(len(plan["parent_theme_ids"]), 1)
            theme["plan_direct_lines"] += plan["direct_plan_lines"] * share
            theme["plan_implementation_code_lines"] += plan["implementation_code_lines"] * share
            theme["plan_allocated_elapsed_seconds"] += float(plan["total_visible_conversation_elapsed_seconds"] or 0) * share
            theme["linked_plan_ids"].append(plan_id)
            plan_scores.append(plan["difficulty_score"])
        theme["child_feature_ids"] = sorted(set(theme["child_feature_ids"]))
        theme["child_plan_ids"] = sorted(set(theme["child_plan_ids"]), key=lambda value: int(value) if value.isdigit() else sys.maxsize)
        theme["linked_commit_ids"] = sorted(set(theme["linked_commit_ids"]))
        theme["linked_transcript_ids"] = sorted(set(theme["linked_transcript_ids"]))
        theme["linked_plan_ids"] = sorted(set(theme["linked_plan_ids"]), key=lambda value: int(value) if value.isdigit() else sys.maxsize)
        theme["child_feature_count"] = len(theme["child_feature_ids"])
        theme["child_plan_count"] = len(theme["child_plan_ids"])
        theme["commit_count"] = len(theme["linked_commit_ids"])
        theme["documentation_page_count"] = len(theme["documentation_ids"])
        theme["mean_feature_difficulty"] = statistics.mean(feature_scores) if feature_scores else 0.0
        theme["median_feature_difficulty"] = statistics.median(feature_scores) if feature_scores else 0.0
        theme["max_feature_difficulty"] = max(feature_scores, default=0.0)
        theme["mean_plan_difficulty"] = statistics.mean(plan_scores) if plan_scores else 0.0
        theme["median_plan_difficulty"] = statistics.median(plan_scores) if plan_scores else 0.0
        theme["max_plan_difficulty"] = max(plan_scores, default=0.0)
    return themes, references, theme_coverage


def validate_model_invariants(
    data: dict[str, Any], features: dict[str, dict[str, Any]], plans: dict[str, dict[str, Any]]
) -> None:
    commit_ids = {commit["full_hash"] for commit in data["commits"]}
    if set(features) != commit_ids or len(features) != len(data["commits"]):
        raise AnalysisError("Analytical and configured commit sets differ")
    for feature_id, feature in features.items():
        if feature["linked_commit_ids"] != [feature_id]:
            raise AnalysisError(f"Commit {feature_id} does not own exactly its canonical commit")
    if any(normalize_repo_path(source["path"]) == CONTROL_PLAN_PATH for source in data["plan_sources"]):
        raise AnalysisError("Control Plan 34 leaked into Plan sources")
    if "34" in plans:
        raise AnalysisError("Control Plan 34 leaked into analytical Plans")
    expected_start = data["report_commit_range"]["start_commit"]
    expected_end = data["report_commit_range"]["end_commit"]
    if expected_start != REPORT_START_COMMIT or expected_end != REPORT_END_COMMIT:
        raise AnalysisError("Generated report range differs from fixed Plan 34 boundaries")


def ensure_dirs(output_dir: Path) -> None:
    for stale_page in ("features.html", "timelines.html"):
        path = output_dir / stale_page
        if path.exists():
            path.unlink()
    for subdir in ("data", "features", "plans", "themes", "charts", "review-packets", "sources"):
        path = output_dir / subdir
        if path.exists():
            shutil.rmtree(path)
    for subdir in (
        "", "data", "plans", "themes", "charts",
        "review-packets/transcripts", "review-packets/themes",
        "sources/plans", "sources/transcripts", "sources/commits", "sources/user-documentation",
    ):
        (output_dir / subdir).mkdir(parents=True, exist_ok=True)


def write_csv(path: Path, rows: list[dict[str, Any]], fields: list[str]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            cleaned: dict[str, Any] = {}
            for field_name in fields:
                value = row.get(field_name, "")
                if isinstance(value, (list, dict)):
                    value = json.dumps(value, ensure_ascii=False, sort_keys=True)
                if value is None:
                    value = ""
                cleaned[field_name] = value
            writer.writerow(cleaned)


def html_page(title: str, body: str, root_prefix: str = "") -> str:
    site_links = "" if root_prefix else """
  <span aria-hidden="true">|</span>
  <a href="https://chrismccready.github.io/swifttag/Docs/Analysis/">Analysis README</a>
  <a href="https://chrismccready.github.io/swifttag/">SwiftTag GitHub Pages</a>"""
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(title)}</title>
  <link rel="stylesheet" href="{root_prefix}assets.css">
</head>
<body>
<header><h1>{html.escape(title)}</h1><nav>
  <a href="{root_prefix}index.html">Index</a>
  <a href="{root_prefix}commits.html">Commits</a>
  <a href="{root_prefix}plans.html">Plans</a>
  <a href="{root_prefix}themes.html">Themes</a>
  <a href="{root_prefix}response-times.html">Response Times</a>
  <a href="{root_prefix}difficulty.html">Difficulty</a>
  <a href="{root_prefix}charts.html">Charts</a>
  <a href="{root_prefix}transcripts.html">Transcripts</a>
  <a href="{root_prefix}warnings.html">Warnings</a>{site_links}
</nav></header><main>{body}</main></body></html>
"""


def table(headers: list[str], rows: list[list[Any]], table_id: str = "") -> str:
    identifier = f' id="{html.escape(table_id)}"' if table_id else ""
    parts = [f"<table{identifier}><thead><tr>"]
    parts.extend(f"<th>{html.escape(header)}</th>" for header in headers)
    parts.append("</tr></thead><tbody>")
    for row in rows:
        parts.append("<tr>" + "".join(f"<td>{cell}</td>" for cell in row) + "</tr>")
    parts.append("</tbody></table>")
    return "\n".join(parts)


def link(label: str, href: str) -> str:
    return f'<a href="{html.escape(href)}">{html.escape(label)}</a>'


def source_line_html(text: str) -> str:
    rows = []
    for number, line_text in enumerate(normalize_text(text).splitlines(), 1):
        rows.append(f'<tr id="L{number}"><th><a href="#L{number}">{number}</a></th><td><pre>{html.escape(line_text)}</pre></td></tr>')
    return '<table class="source-lines">' + "\n".join(rows) + "</table>"


def write_source_pages(ctx: AnalysisContext, data: dict[str, Any]) -> None:
    for source in data["plan_sources"]:
        body = f'<p>{html.escape(source["path"])}</p>' + source_line_html(read_text(ctx.repo_root / source["path"]))
        (ctx.output_dir / source_html_path_for_plan(source["plan_source_id"])).write_text(
            html_page("Plan Source: " + source["plan_source_id"], body, "../../"), encoding="utf-8"
        )
    for transcript in data["transcripts"]:
        body = f'<p>{html.escape(transcript["path"])}</p>' + source_line_html(read_text(ctx.repo_root / transcript["path"]))
        (ctx.output_dir / source_html_path_for_transcript(transcript["transcript_id"])).write_text(
            html_page("Transcript Source: " + transcript["transcript_id"], body, "../../"), encoding="utf-8"
        )
    for doc in data["user_documentation"]:
        body = f'<p>{html.escape(doc["path"])}</p>' + source_line_html(read_text(ctx.repo_root / doc["path"]))
        (ctx.output_dir / source_html_path_for_doc(doc["documentation_id"])).write_text(
            html_page("Documentation Source: " + doc["path"], body, "../../"), encoding="utf-8"
        )
    files_by_hash: dict[str, list[dict[str, Any]]] = {}
    for row in data["commit_files"]:
        files_by_hash.setdefault(row["commit_hash"], []).append(row)
    for commit in data["commits"]:
        file_rows = [
            [html.escape(row["path"]), html.escape(row["path_class"]), html.escape(row["status"]), row["additions"], row["deletions"], "yes" if row["binary"] else "no"]
            for row in files_by_hash.get(commit["full_hash"], [])
        ]
        body = "<h2>Subject</h2><p>" + html.escape(commit["subject"]) + "</p>"
        if commit["body"]:
            body += "<h2>Body</h2><pre>" + html.escape(commit["body"]) + "</pre>"
        body += "<h2>Files</h2>" + table(["Path", "Class", "Status", "Additions", "Deletions", "Binary"], file_rows)
        (ctx.output_dir / source_html_path_for_commit(commit["short_hash"])).write_text(
            html_page(commit_source_title(commit), body, "../../"), encoding="utf-8"
        )


def write_transcript_review_packets(ctx: AnalysisContext, data: dict[str, Any]) -> None:
    existing_reviews = data.get("manual_config", {}).get("transcript_reviews", {})
    features_by_id = {feature["feature_id"]: feature for feature in data["features"]}
    plans_by_id = {plan["plan_id"]: plan for plan in data["plans"]}
    themes_by_id = {theme["theme_id"]: theme for theme in data["themes"]}
    segments_by_transcript: dict[str, list[dict[str, Any]]] = {}
    for segment in data["transcript_segments"]:
        segments_by_transcript.setdefault(segment["transcript_id"], []).append(segment)
    allocations_by_transcript: dict[str, list[dict[str, Any]]] = {}
    for allocation in data["segment_allocations"]:
        allocations_by_transcript.setdefault(allocation["transcript_id"], []).append(allocation)
    status_by_id = {row["transcript_id"]: row for row in data["semantic_review_status"]}
    for transcript in data["transcripts"]:
        transcript_id = transcript["transcript_id"]
        packet_segments = []
        for segment in segments_by_transcript.get(transcript_id, []):
            packet_segments.append({
                "segment_id": segment["segment_id"],
                "source_line_start": segment["source_line_start"],
                "source_line_end": segment["source_line_end"],
                "speaker_start": segment["speaker_start"],
                "turn_ids": segment["turn_ids"],
                "source_line_count": segment["source_line_count"],
                "body_line_count": segment["body_line_count"],
                "assistant_processing_seconds": segment["assistant_processing_seconds"],
                "user_response_seconds": segment["user_response_seconds"],
                "valid_atomic_elapsed_seconds": segment["valid_atomic_elapsed_seconds"],
                "back_and_forth_count": segment["back_and_forth_count"],
                "orphan": segment["orphan"],
                "interrupted": segment["interrupted"],
                "excerpt": re.sub(r"\s+", " ", segment["text"])[:1200],
            })
        candidate_theme_ids: set[str] = set()
        for candidate in data["candidate_commits_by_transcript"].get(transcript_id, []):
            candidate_theme_ids.update(features_by_id.get(candidate["commit_hash"], {}).get("parent_theme_ids", []))
        for plan in data["candidate_plans_by_transcript"].get(transcript_id, []):
            candidate_theme_ids.update(plans_by_id.get(plan["plan_id"], {}).get("parent_theme_ids", []))
        packet = {
            "schema_version": 1,
            "review_method_version": data.get("manual_config", {}).get("review_method_version", REVIEW_METHOD_VERSION),
            "transcript_id": transcript_id,
            "path": transcript["path"],
            "normalized_content_digest": transcript["normalized_content_digest"],
            "review_input_digest": transcript["review_input_digest"],
            "source_link": "../../" + source_html_path_for_transcript(transcript_id) + "#L1",
            "header": {
                "export_date": transcript["export_date"],
                "reference_type": transcript["reference_type"],
                "references": transcript["references"],
                "agent": transcript["agent"],
            },
            "raw_metrics": {
                "line_count": transcript["line_count"],
                "turn_count": transcript["turn_count"],
                "valid_atomic_elapsed_seconds": transcript["valid_atomic_elapsed_seconds"],
                "assistant_processing_seconds": transcript["assistant_processing_seconds"],
                "user_response_seconds": transcript["user_response_seconds"],
                "back_and_forth_count": transcript["back_and_forth_count"],
            },
            "archive_provenance_commit_ids": transcript["archive_commit_ids"],
            "base_segments": packet_segments,
            "candidate_commits": [
                {
                    **candidate,
                    "source_link": "../../" + source_html_path_for_commit(candidate["short_hash"]),
                }
                for candidate in data["candidate_commits_by_transcript"].get(transcript_id, [])
            ],
            "candidate_plans": [
                {
                    "plan_id": plan["plan_id"], "display_title": plan["display_title"],
                    "current_source_path": plan["current_source_path"], "section_names": plan["section_names"],
                    "creation_commit_id": plan["creation_commit_id"], "revision_commit_ids": plan["revision_commit_ids"],
                    "source_link": "../../" + source_html_path_for_plan(plan["current_source_id"]) + "#L1",
                }
                for plan in data["candidate_plans_by_transcript"].get(transcript_id, [])
            ],
            "candidate_themes": [
                {
                    "theme_id": theme_id,
                    "display_name": themes_by_id[theme_id]["display_name"],
                    "accepted_commit_ids": sorted(
                        feature_id for feature_id in transcript["associated_feature_ids"]
                        if theme_id in features_by_id.get(feature_id, {}).get("parent_theme_ids", [])
                    ),
                    "accepted_plan_ids": sorted(
                        plan_id for plan_id in transcript["associated_plan_ids"]
                        if theme_id in plans_by_id.get(plan_id, {}).get("parent_theme_ids", [])
                    ),
                    "positive_and_negative_edges": [
                        {**row, "entity_type": "commit" if row["entity_type"] == "feature" else row["entity_type"]}
                        for row in data["theme_references"]
                        if row["theme_id"] == theme_id
                        and row["entity_id"] in set(transcript["associated_feature_ids"] + transcript["associated_plan_ids"])
                    ],
                }
                for theme_id in sorted(candidate_theme_ids)
            ],
            "existing_review": existing_reviews.get(transcript_id),
            "current_review_status": status_by_id[transcript_id],
            "conservation_preview": {
                "segment_source_lines": sum(segment["source_line_count"] for segment in packet_segments),
                "transcript_source_lines": transcript["line_count"],
                "header_note_lines": transcript["line_count"] - sum(segment["source_line_count"] for segment in packet_segments),
                "commit_lens": {
                    "allocated_lines": sum(
                        float(row.get("allocated_source_lines") or 0)
                        for row in allocations_by_transcript.get(transcript_id, [])
                        if row["entity_type"] == "feature"
                    ),
                    "allocated_atomic_elapsed_seconds": sum(
                        float(row.get("allocated_visible_elapsed_seconds") or 0)
                        for row in allocations_by_transcript.get(transcript_id, [])
                        if row["entity_type"] == "feature"
                    ),
                    "allocated_back_and_forth": sum(
                        float(row.get("allocated_back_and_forth_count") or 0)
                        for row in allocations_by_transcript.get(transcript_id, [])
                        if row["entity_type"] == "feature"
                    ),
                    "unallocated_remainder": transcript.get("feature_unallocated_remainder"),
                },
                "plan_lens": {
                    "allocated_lines": sum(
                        float(row.get("allocated_source_lines") or 0)
                        for row in allocations_by_transcript.get(transcript_id, [])
                        if row["entity_type"] == "plan"
                    ),
                    "allocated_atomic_elapsed_seconds": sum(
                        float(row.get("allocated_visible_elapsed_seconds") or 0)
                        for row in allocations_by_transcript.get(transcript_id, [])
                        if row["entity_type"] == "plan"
                    ),
                    "allocated_back_and_forth": sum(
                        float(row.get("allocated_back_and_forth_count") or 0)
                        for row in allocations_by_transcript.get(transcript_id, [])
                        if row["entity_type"] == "plan"
                    ),
                    "unallocated_remainder": transcript.get("plan_unallocated_remainder"),
                },
            },
            "unresolved_questions": [
                "Accept or reject Commit ownership for every base segment.",
                "Assign direct or implementation Plan role for every accepted Plan segment.",
                "Explain any Commit-lens or Plan-lens unallocated remainder.",
            ],
        }
        json_path = ctx.output_dir / "review-packets" / "transcripts" / f"{transcript_id}.json"
        md_path = ctx.output_dir / "review-packets" / "transcripts" / f"{transcript_id}.md"
        json_path.write_text(json.dumps(packet, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
        md = [
            f"# Transcript Review: {transcript_id}", "",
            f"- Path: `{transcript['path']}`",
            f"- Content digest: `{transcript['normalized_content_digest']}`",
            f"- Review-input digest: `{transcript['review_input_digest']}`",
            f"- Current status: `{transcript['semantic_review_status']}`", "",
            "## Base Segments", "",
        ]
        for segment in packet_segments:
            md.extend([
                f"### {segment['segment_id']} (lines {segment['source_line_start']}-{segment['source_line_end']})",
                "", segment["excerpt"] or "_No visible text._", "",
            ])
        md.extend(["## Candidate Commits", ""])
        for candidate in packet["candidate_commits"]:
            md.append(f"- `{candidate['commit_hash']}` — {candidate['subject']} ({candidate['score']:.2f}; {', '.join(candidate['reasons'])})")
        md.extend(["", "## Candidate Plans", ""])
        for plan in packet["candidate_plans"]:
            md.append(f"- Plan `{plan['plan_id']}` — {plan['display_title']}")
        md.extend(["", "## Candidate Themes", ""])
        for theme in packet["candidate_themes"]:
            md.append(f"- `{theme['theme_id']}` — {theme['display_name']}")
        md_path.write_text("\n".join(md) + "\n", encoding="utf-8")


def write_theme_review_packets(ctx: AnalysisContext, data: dict[str, Any]) -> None:
    for theme in data["themes"]:
        packet = {
            "theme_id": theme["theme_id"], "display_name": theme["display_name"],
            "description": theme["description"], "aliases": theme["aliases"], "keywords": theme["keywords"],
            "included_commit_ids": theme["child_feature_ids"], "included_plan_ids": theme["child_plan_ids"],
            "positive_and_negative_edges": [
                {**row, "entity_type": "commit" if row["entity_type"] == "feature" else row["entity_type"]}
                for row in data["theme_references"] if row["theme_id"] == theme["theme_id"]
            ],
        }
        base = ctx.output_dir / "review-packets" / "themes" / theme["theme_id"]
        base.with_suffix(".json").write_text(json.dumps(packet, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
        lines = [f"# Theme Review: {theme['display_name']}", "", theme["description"], "", "## Commits", ""]
        lines.extend(f"- `{feature_id}`" for feature_id in theme["child_feature_ids"])
        lines.extend(["", "## Plans", ""])
        lines.extend(f"- Plan `{plan_id}`" for plan_id in theme["child_plan_ids"])
        base.with_suffix(".md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def response_brackets(turns: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    ranges = {
        "0-1h": (0, 3600),
        "1-2h": (3600, 7200),
        "2-4h": (7200, 14400),
        ">4h": (14400, math.inf),
    }
    result: dict[str, dict[str, Any]] = {}
    for label, (minimum, maximum) in ranges.items():
        values = [
            float(turn["user_response_seconds"])
            for turn in turns
            if turn.get("user_response_seconds") is not None
            and float(turn["user_response_seconds"]) >= minimum
            and float(turn["user_response_seconds"]) < maximum
        ]
        result[label] = summary_stats(values)
    return result


def summary_stats(values: list[float]) -> dict[str, Any]:
    return {
        "count": len(values),
        "min": min(values) if values else None,
        "max": max(values) if values else None,
        "mean": statistics.mean(values) if values else None,
        "median": statistics.median(values) if values else None,
        "total": sum(values) if values else 0.0,
    }


def warning_rows(ctx: AnalysisContext) -> list[dict[str, Any]]:
    return [
        {
            "source_type": "commit" if warning.source_type == "feature" else warning.source_type,
            "source_id": warning.source_id,
            "category": warning.category, "message": warning.message,
            "line": warning.line or "",
        }
        for warning in ctx.warnings
    ]


def write_data_files(ctx: AnalysisContext, data: dict[str, Any], argv: list[str]) -> None:
    output = ctx.output_dir / "data"
    features_by_id = {row["feature_id"]: row for row in data["features"]}
    commit_rows = [
        {**commit, **features_by_id[commit["full_hash"]], "commit_hash": commit["full_hash"]}
        for commit in data["commits"]
    ]
    plan_rows = [
        {**row, "associated_commit_ids": row["associated_feature_ids"]}
        for row in data["plans"]
    ]
    transcript_rows = [
        {
            **row,
            "associated_commit_ids": row["associated_feature_ids"],
            "commit_unallocated_remainder": row.get("feature_unallocated_remainder"),
        }
        for row in data["transcripts"]
    ]
    segment_rows = [
        {**row, "candidate_commit_ids": row["candidate_feature_ids"]}
        for row in data["transcript_segments"]
    ]
    allocation_rows = [
        {**row, "entity_type": "commit" if row["entity_type"] == "feature" else row["entity_type"]}
        for row in data["segment_allocations"]
    ]
    relationship_rows = [
        {
            **row,
            "left_entity_type": "commit" if row["left_entity_type"] == "feature" else row["left_entity_type"],
            "right_entity_type": "commit" if row["right_entity_type"] == "feature" else row["right_entity_type"],
        }
        for row in data["relationships"]
    ]
    write_csv(output / "plans.csv", plan_rows, [
        "plan_id", "display_title", "numeric_order", "version_count", "source_plan_ids", "source_paths",
        "current_source_id", "current_source_path", "current_source_line_count", "creation_commit_id",
        "revision_commit_ids", "implementation_commit_ids", "transcript_archive_commit_ids",
        "associated_commit_ids", "associated_transcript_ids", "parent_theme_ids", "revision_additions",
        "revision_deletions", "direct_plan_lines", "direct_transcript_lines",
        "implementation_transcript_lines", "implementation_code_lines", "implementation_test_lines",
        "implementation_documentation_lines", "direct_visible_elapsed_seconds",
        "implementation_visible_elapsed_seconds", "total_visible_conversation_elapsed_seconds",
        "total_assistant_processing_seconds", "total_user_response_seconds", "back_and_forth_count",
        "difficulty_inputs", "difficulty_score", "difficulty_label", "difficulty_weight_coverage",
        "first_evidence_date", "last_evidence_date", "confidence_score", "warning_count",
    ])
    write_csv(output / "plan_revisions.csv", data["plan_revisions"], [
        "plan_id", "commit_hash", "short_hash", "roles", "path", "status", "additions", "deletions", "author_date",
    ])
    write_csv(output / "transcripts.csv", transcript_rows, [
        "transcript_id", "path", "export_date", "reference_type", "raw_references", "agent", "line_count",
        "turn_count", "user_turn_count", "assistant_turn_count", "first_timestamp", "last_timestamp",
        "elapsed_seconds", "valid_atomic_elapsed_seconds", "assistant_processing_seconds", "user_response_seconds",
        "elapsed_confidence", "back_and_forth_count", "warning_count", "documented_warning_count",
        "documented_warning_categories", "archive_commit_ids", "associated_commit_ids", "associated_plan_ids",
        "allocation_status", "allocation_total", "semantic_review_status", "normalized_content_digest",
        "review_input_digest", "commit_unallocated_remainder", "plan_unallocated_remainder",
    ])
    write_csv(output / "turns.csv", data["turns"], [
        "transcript_id", "turn_id", "turn_index", "speaker", "source_line_start", "source_line_end",
        "timestamp", "completion_timestamp", "body_line_count", "assistant_processing_seconds",
        "user_response_seconds", "timing_confidence", "interrupted",
    ])
    write_csv(output / "transcript_segments.csv", segment_rows, [
        "transcript_id", "segment_id", "segment_index", "source_line_start", "source_line_end", "speaker_start",
        "turn_ids", "turn_indexes", "body_line_count", "source_line_count", "assistant_processing_seconds",
        "user_response_seconds", "valid_atomic_elapsed_seconds", "back_and_forth_count", "orphan", "interrupted",
        "candidate_commit_ids", "candidate_plan_ids", "review_status",
    ])
    write_csv(output / "segment_allocations.csv", allocation_rows, [
        "transcript_id", "segment_id", "entity_type", "entity_id", "role", "allocation_weight",
        "source_line_start", "source_line_end", "allocated_source_lines",
        "allocated_assistant_processing_seconds", "allocated_user_response_seconds",
        "allocated_visible_elapsed_seconds", "allocated_back_and_forth_count", "allocated_turn_count",
        "review_status", "reviewed_config_entry_id", "confidence", "evidence_note",
        "included_in_direct_totals", "included_in_rollup_totals",
    ])
    write_csv(output / "semantic_review_status.csv", data["semantic_review_status"], [
        "transcript_id", "review_status", "normalized_content_digest", "configured_content_digest",
        "review_input_digest", "configured_review_input_digest", "reviewed_by", "reviewed_at", "review_method", "message",
    ])
    write_csv(output / "commits.csv", commit_rows, [
        "commit_hash", "full_hash", "short_hash", "author_date", "committer_date", "subject", "body", "type",
        "scope", "description", "breaking", "breaking_footers", "body_subject_aliases",
        "conventional_parse_status", "changed_files", "changed_file_count", "additions", "deletions",
        "code_line_count", "test_line_count", "docs_line_count", "plan_line_count", "transcript_line_count",
        "fixture_line_count", "fixture_or_binary_change", "linked_plan_ids", "linked_transcript_ids",
        "parent_theme_ids", "theme_coverage_state", "total_code_lines_changed", "total_test_lines_changed",
        "total_documentation_lines_changed", "total_plan_lines", "total_transcript_lines",
        "total_visible_conversation_elapsed_seconds", "total_assistant_processing_seconds",
        "total_user_response_seconds", "back_and_forth_count", "allocated_turn_count",
        "unavailable_timing_count", "difficulty_inputs", "difficulty_score", "difficulty_label",
        "difficulty_weight_coverage", "confidence_score", "warning_count", "first_evidence_date",
        "last_evidence_date", "link_confidence", "link_evidence",
    ])
    write_csv(output / "commit_files.csv", data["commit_files"], [
        "commit_hash", "short_hash", "path", "expanded_paths", "status", "path_class", "additions", "deletions", "binary",
    ])
    write_csv(output / "commit_references.csv", [
        {**row, "commit_hash": row["feature_id"]} for row in data["feature_references"]
    ], [
        "commit_hash", "source_type", "source_id", "evidence_type", "confidence", "allocation_weight", "source_line", "included_in_totals",
    ])
    write_csv(output / "plan_references.csv", data["plan_references"], [
        "plan_id", "source_type", "source_id", "role", "evidence_type", "confidence", "source_line",
    ])
    write_csv(output / "commit_plan_references.csv", [
        {**row, "commit_hash": row["feature_id"]} for row in data["feature_plan_references"]
    ], [
        "commit_hash", "plan_id", "roles", "evidence_type", "confidence", "allocation_weight",
        "included_in_direct_totals", "included_in_rollup_totals",
    ])
    write_csv(output / "theme_references.csv", [
        {**row, "entity_type": "commit" if row["entity_type"] == "feature" else row["entity_type"]}
        for row in data["theme_references"]
    ], [
        "theme_id", "entity_type", "entity_id", "relationship_type", "evidence_source", "confidence", "allocation_weight",
    ])
    write_csv(output / "theme_coverage.csv", [
        {**row, "commit_hash": row["feature_id"]} for row in data["theme_coverage"]
    ], [
        "commit_hash", "short_hash", "theme_ids", "theme_count", "coverage_state",
    ])
    write_csv(output / "relationships.csv", relationship_rows, [
        "left_entity_type", "left_entity_id", "right_entity_type", "right_entity_id", "role", "evidence_type",
        "evidence_source", "source_line", "confidence", "allocation_weight", "included_in_direct_totals",
        "included_in_rollup_totals", "manual_override_state", "reviewed_by", "reviewed_at", "review_method",
        "evidence_note", "source_digest", "warning_state",
    ])
    theme_rows = [
        {
            **row,
            "child_commit_ids": row["child_feature_ids"],
            "commit_inherited_transcript_lines": row["feature_inherited_transcript_lines"],
            "commit_allocated_transcript_lines": row["feature_allocated_transcript_lines"],
            "commit_inherited_code_lines": row["feature_inherited_code_lines"],
            "commit_allocated_code_lines": row["feature_allocated_code_lines"],
            "commit_inherited_elapsed_seconds": row["feature_inherited_elapsed_seconds"],
            "commit_allocated_elapsed_seconds": row["feature_allocated_elapsed_seconds"],
            "mean_commit_difficulty": row["mean_feature_difficulty"],
            "median_commit_difficulty": row["median_feature_difficulty"],
            "max_commit_difficulty": row["max_feature_difficulty"],
        }
        for row in data["themes"]
    ]
    write_csv(output / "themes.csv", theme_rows, [
        "theme_id", "display_name", "description", "aliases", "keywords", "documentation_paths",
        "child_commit_ids", "child_plan_ids", "linked_plan_ids", "linked_transcript_ids", "linked_commit_ids",
        "documentation_ids", "commit_inherited_transcript_lines", "commit_allocated_transcript_lines",
        "commit_inherited_code_lines", "commit_allocated_code_lines", "commit_inherited_elapsed_seconds",
        "commit_allocated_elapsed_seconds", "plan_direct_lines", "plan_implementation_code_lines",
        "plan_allocated_elapsed_seconds", "commit_count", "child_plan_count",
        "documentation_page_count", "mean_commit_difficulty", "median_commit_difficulty",
        "max_commit_difficulty", "mean_plan_difficulty", "median_plan_difficulty", "max_plan_difficulty",
        "configured_definition_preserved",
    ])
    write_csv(output / "user_documentation.csv", [
        {**row, "linked_commit_ids": row["linked_feature_ids"]} for row in data["user_documentation"]
    ], [
        "documentation_id", "path", "title", "heading_text", "link_count", "line_count", "linked_theme_ids", "linked_commit_ids",
    ])
    write_csv(output / "warnings.csv", warning_rows(ctx), ["source_type", "source_id", "category", "message", "line"])

    themed_count = sum(row["coverage_state"] == "assigned" for row in data["theme_coverage"])
    metrics = {
        "commit_count": len(data["commits"]),
        "plan_count": len(data["plans"]),
        "plan_source_count": len(data["plan_sources"]),
        "transcript_count": len(data["transcripts"]),
        "transcript_segment_count": len(data["transcript_segments"]),
        "theme_count": len(data["themes"]),
        "themed_commit_count": themed_count,
        "unthemed_commit_count": len(data["features"]) - themed_count,
        "theme_coverage_percentage": themed_count / max(len(data["features"]), 1) * 100,
        "warning_count": len(ctx.warnings),
        "review_status_counts": {
            status: sum(row["review_status"] == status for row in data["semantic_review_status"])
            for status in ("reviewed", "unreviewed", "stale", "invalid")
        },
        "assistant_processing": summary_stats([float(turn["assistant_processing_seconds"]) for turn in data["turns"] if turn["assistant_processing_seconds"] is not None]),
        "user_response": summary_stats([float(turn["user_response_seconds"]) for turn in data["turns"] if turn["user_response_seconds"] is not None]),
        "user_response_brackets": response_brackets(data["turns"]),
        "analytical_lenses": {
            "commit": "commits only",
            "plan": "Plan direct and implementation rollup; not additive with Commit lens",
            "theme": "Commit and Plan lenses reported separately",
        },
    }
    (output / "metrics.json").write_text(json.dumps(metrics, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
    dirty = filter_dirty_worktree_status(
        git(ctx, ["status", "--short"]).strip(), {CONTROL_PLAN_PATH}
    )
    metadata = {
        "utc_run_timestamp": dt.datetime.now(UTC).isoformat().replace("+00:00", "Z"),
        "git_head": git(ctx, ["rev-parse", "HEAD"]).strip(),
        "dirty_worktree_status": dirty,
        "python_version": sys.version,
        "matplotlib_version": ctx.matplotlib_version,
        "plotly_version": ctx.plotly_version,
        "command_arguments": argv,
        "report_start_commit": REPORT_START_COMMIT,
        "report_end_commit": REPORT_END_COMMIT,
        "input_file_counts": {
            "plans": len(data["plans"]), "plan_sources": len(data["plan_sources"]),
            "transcripts": len(data["transcripts"]), "user_documentation": len(data["user_documentation"]),
            "commits": len(data["commits"]),
        },
        "themed_commit_count": themed_count,
        "unthemed_commit_count": len(data["features"]) - themed_count,
        "theme_coverage_percentage": metrics["theme_coverage_percentage"],
        "warning_count": len(ctx.warnings),
        "review_status_counts": metrics["review_status_counts"],
    }
    (output / "run_metadata.json").write_text(json.dumps(metadata, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")


def matplotlib_pyplot(ctx: AnalysisContext | None = None) -> Any:
    base = (ctx.output_dir.parent / "tmp") if ctx else Path("/tmp/swifttag-analysis")
    mpl_dir = base / "matplotlib"
    cache_dir = base / "cache"
    mpl_dir.mkdir(parents=True, exist_ok=True)
    cache_dir.mkdir(parents=True, exist_ok=True)
    os.environ["MPLCONFIGDIR"] = str(mpl_dir)
    os.environ["XDG_CACHE_HOME"] = str(cache_dir)
    try:
        import matplotlib
        matplotlib.use("svg", force=True)
        matplotlib.rcdefaults()
        matplotlib.rcParams.update({
            "font.family": "DejaVu Sans",
            "font.size": 11,
            "axes.titlesize": 16,
            "axes.labelsize": 11,
            "xtick.labelsize": 10,
            "ytick.labelsize": 9,
            "svg.fonttype": "none",
            "svg.hashsalt": "swifttag-project-analysis-v2",
            "figure.facecolor": "white",
            "axes.facecolor": "white",
            "savefig.facecolor": "white",
        })
        from matplotlib import pyplot as plt
    except Exception as error:
        raise AnalysisError(
            "Matplotlib with SVG backend is required. Use project Python environment with "
            f"Matplotlib 3.11.0 or install it before rerunning. Original error: {error}"
        ) from error
    if ctx:
        ctx.matplotlib_version = str(matplotlib.__version__)
    return plt


def shorten_chart_label(label: str, max_length: int = 68) -> str:
    return label if len(label) <= max_length else label[: max_length - 1].rstrip() + "…"


def matplotlib_bar_chart(
    ctx: AnalysisContext,
    title: str,
    rows: list[tuple[str, float, str]],
    path: Path,
    data_href: str,
    x_label: str,
    limit: int | None = 45,
) -> None:
    plt = matplotlib_pyplot(ctx)
    ordered = sorted(((label, float(value or 0), url) for label, value, url in rows), key=lambda row: (-row[1], row[0].lower()))
    if limit is not None:
        ordered = ordered[:limit]
    empty = not ordered
    if empty:
        ordered = [("No data", 0.0, "")]
    labels = [shorten_chart_label(row[0]) for row in ordered]
    values = [row[1] for row in ordered]
    positions = list(range(len(ordered)))
    height = max(2.8, 1.2 + len(ordered) * 0.26)
    figure, axes = plt.subplots(figsize=(12.5, height))
    figure.subplots_adjust(left=0.39, right=0.94, top=1 - 0.38 / height, bottom=0.58 / height)
    bars = axes.barh(positions, values, color="#2f6f73", height=0.72)
    axes.set_yticks(positions, labels)
    axes.set_ylim(len(ordered) - 0.5, -0.5)
    if max(values, default=0) <= 0:
        axes.set_xlim(0, 1)
    axes.set_xlabel(x_label)
    axes.set_title(title, loc="left", fontweight="bold")
    axes.grid(axis="x", color="#d9e1e2", linewidth=0.8)
    axes.set_axisbelow(True)
    for side in ("top", "right", "left"):
        axes.spines[side].set_visible(False)
    axes.tick_params(axis="x", labelsize=10)
    axes.tick_params(axis="y", length=0, labelsize=9)
    axes.bar_label(bars, labels=[f"{value:.1f}" if abs(value) < 10 else f"{value:.0f}" for value in values], padding=3, fontsize=9)
    for tick, bar, (_, _, url) in zip(axes.get_yticklabels(), bars, ordered):
        if url:
            tick.set_url(url)
            bar.set_url(url)
    if empty:
        axes.text(0.5, 0.5, "No data available", transform=axes.transAxes, ha="center", va="center")
    footer = figure.text(0.01, 0.005, f"Data: {data_href}", fontsize=9, color="#5d6668")
    footer.set_url("../" + data_href)
    figure.savefig(path, format="svg", metadata={"Date": None, "Creator": "SwiftTag project analysis"})
    plt.close(figure)


def matplotlib_matrix_chart(
    ctx: AnalysisContext, themes: list[dict[str, Any]], features: list[dict[str, Any]], path: Path
) -> None:
    plt = matplotlib_pyplot(ctx)
    try:
        from matplotlib.patches import Rectangle
    except Exception as error:
        raise AnalysisError(f"Matplotlib patch support is required for Theme matrix: {error}") from error
    row_count = max(len(features), 1)
    column_count = max(len(themes), 1)
    height = max(4.0, 1.4 + row_count * 0.20)
    width = max(8.5, 3.8 + column_count * 0.52)
    figure, axes = plt.subplots(figsize=(width, height))
    figure.subplots_adjust(left=0.42, right=0.98, top=1 - 0.38 / height, bottom=min(0.32, 1.5 / height))
    if not features or not themes:
        axes.text(0.5, 0.5, "No Theme matrix data", transform=axes.transAxes, ha="center", va="center")
    else:
        for row_index, feature in enumerate(features):
            for column_index, theme in enumerate(themes):
                hit = theme["theme_id"] in feature["parent_theme_ids"]
                rectangle = Rectangle(
                    (column_index - 0.5, row_index - 0.5), 1, 1,
                    facecolor="#6d3fa0" if hit else ("#f3c45b" if not feature["parent_theme_ids"] else "#eeeeee"),
                    edgecolor="white", linewidth=0.5,
                )
                if hit or not feature["parent_theme_ids"]:
                    rectangle.set_url(f"../{source_html_path_for_commit(feature['short_hash'])}")
                axes.add_patch(rectangle)
        axes.set_xlim(-0.5, len(themes) - 0.5)
        axes.set_ylim(len(features) - 0.5, -0.5)
        axes.set_xticks(range(len(themes)), [shorten_chart_label(theme["display_name"], 22) for theme in themes])
        axes.set_yticks(range(len(features)), [f"{feature['short_hash']} {shorten_chart_label(feature['display_name'], 50)}" for feature in features])
        axes.tick_params(axis="x", length=0, labelsize=10, labelrotation=55)
        axes.tick_params(axis="y", length=0, labelsize=7)
        for tick, theme in zip(axes.get_xticklabels(), themes):
            tick.set_ha("right")
            tick.set_url(f"../themes/{theme['theme_id']}.html")
        for tick, feature in zip(axes.get_yticklabels(), features):
            tick.set_url(f"../{source_html_path_for_commit(feature['short_hash'])}")
    axes.set_title("Theme To Commit Coverage Matrix", loc="left", fontweight="bold")
    footer = figure.text(0.01, 0.005, "Data: data/theme_coverage.csv", fontsize=9, color="#5d6668")
    footer.set_url("../data/theme_coverage.csv")
    figure.savefig(path, format="svg", metadata={"Date": None, "Creator": "SwiftTag project analysis"})
    plt.close(figure)


def write_charts(ctx: AnalysisContext, data: dict[str, Any]) -> None:
    features = data["features"]
    plans = data["plans"]
    themes = data["themes"]
    feature_specs = [
        ("commit-time-spent.svg", "Commit Allocated Visible Time", "total_visible_conversation_elapsed_seconds", 3600, "Hours"),
        ("commit-difficulty.svg", "Commit Difficulty", "difficulty_score", 1, "Score"),
        ("code-lines-by-commit.svg", "Code Lines By Commit", "total_code_lines_changed", 1, "Changed lines"),
        ("transcript-plan-lines-by-commit.svg", "Transcript And Plan Lines By Commit", "combined", 1, "Lines"),
        ("commit-assistant-processing-time.svg", "Commit Allocated Assistant Time", "total_assistant_processing_seconds", 3600, "Hours"),
    ]
    for filename, title, key, divisor, label in feature_specs:
        rows = []
        for feature in features:
            value = feature["total_transcript_lines"] + feature["total_plan_lines"] if key == "combined" else float(feature.get(key) or 0)
            rows.append((f"{feature['short_hash']} {feature['display_name']}", value / divisor, f"../{source_html_path_for_commit(feature['short_hash'])}"))
        matplotlib_bar_chart(ctx, title, rows, ctx.output_dir / "charts" / filename, "data/commits.csv", label)
    plan_specs = [
        ("plan-time-allocation.svg", "Plan Allocated Visible Time", "total_visible_conversation_elapsed_seconds", 3600, "Hours"),
        ("plan-difficulty.svg", "Plan Difficulty", "difficulty_score", 1, "Score"),
        ("plan-revision-timeline.svg", "Plan Revision Churn", "revision", 1, "Added + deleted lines"),
    ]
    for filename, title, key, divisor, label in plan_specs:
        rows = []
        for plan in plans:
            value = plan["revision_additions"] + plan["revision_deletions"] if key == "revision" else float(plan.get(key) or 0)
            rows.append((f"Plan {plan['plan_id']} {plan['display_title']}", value / divisor, f"../plans/{plan['plan_id']}.html"))
        matplotlib_bar_chart(ctx, title, rows, ctx.output_dir / "charts" / filename, "data/plans.csv", label, limit=None)
    matplotlib_bar_chart(
        ctx, "Theme Commit-Lens Allocated Time",
        [(theme["display_name"], theme["feature_allocated_elapsed_seconds"] / 3600, f"../themes/{theme['theme_id']}.html") for theme in themes],
        ctx.output_dir / "charts" / "theme-rollup-time.svg", "data/themes.csv", "Hours", limit=None,
    )
    matplotlib_bar_chart(
        ctx, "Theme Commit-Lens Difficulty",
        [(theme["display_name"], theme["mean_feature_difficulty"], f"../themes/{theme['theme_id']}.html") for theme in themes],
        ctx.output_dir / "charts" / "theme-difficulty.svg", "data/themes.csv", "Mean score", limit=None,
    )
    matplotlib_bar_chart(
        ctx, "User Response Bracket Distribution",
        [(label, row["count"], "") for label, row in response_brackets(data["turns"]).items()],
        ctx.output_dir / "charts" / "user-response-brackets.svg", "data/turns.csv", "Turn count", limit=None,
    )
    matplotlib_bar_chart(
        ctx, "Commit Timeline Events",
        [(f"{feature['short_hash']} {feature['display_name']}", 1, f"../{source_html_path_for_commit(feature['short_hash'])}") for feature in features],
        ctx.output_dir / "charts" / "commit-timeline.svg", "data/commits.csv", "Event marker",
    )
    matplotlib_matrix_chart(ctx, themes, features, ctx.output_dir / "charts" / "theme-commit-matrix.svg")
    write_plotly_commit_history(ctx, data)


def commit_history_plot_payload(data: dict[str, Any]) -> dict[str, Any]:
    commits = sorted(data["commits"], key=lambda row: int(row["sequence"]))
    features_by_id = {row["feature_id"]: row for row in data["features"]}
    sequence_by_hash = {row["full_hash"]: int(row["sequence"]) for row in commits}

    def ordered_commit_ids(values: Iterable[str]) -> list[str]:
        return sorted(
            {value for value in values if value in sequence_by_hash},
            key=lambda value: sequence_by_hash[value],
        )

    plans = [
        {
            "id": str(plan["plan_id"]),
            "label": f"Plan {plan['plan_id']}: {plan['display_title']}",
            "initial_commit": plan["creation_commit_id"],
            "covered_commits": ordered_commit_ids(plan["associated_feature_ids"]),
        }
        for plan in data["plans"]
        if plan["creation_commit_id"] in sequence_by_hash
    ]
    transcripts = []
    for transcript in data["transcripts"]:
        archive_commits = ordered_commit_ids(transcript["archive_commit_ids"])
        if not archive_commits:
            continue
        transcripts.append({
            "id": transcript["transcript_id"],
            "label": transcript["transcript_id"],
            "initial_commit": archive_commits[0],
            "covered_commits": ordered_commit_ids(transcript["associated_feature_ids"]),
        })
    return {
        "start_commit": data["report_commit_range"]["start_commit"],
        "end_commit": data["report_commit_range"]["end_commit"],
        "commits": [
            {
                "hash": commit["full_hash"],
                "short_hash": commit["short_hash"],
                "author_date": commit["author_date"],
                "subject": commit["subject"],
                "code_lines": float(features_by_id[commit["full_hash"]]["total_code_lines_changed"]),
                "difficulty": float(features_by_id[commit["full_hash"]]["difficulty_score"]),
            }
            for commit in commits
        ],
        "plans": plans,
        "transcripts": transcripts,
    }


def write_plotly_commit_history(ctx: AnalysisContext, data: dict[str, Any]) -> None:
    configured_python = os.environ.get("PLOTLY_PYTHON", "").strip()
    plotly_python = (
        Path(configured_python).expanduser()
        if configured_python
        else ctx.repo_root / "ThirdParty" / "plotly_install" / "bin" / "python"
    )
    renderer = ctx.repo_root / "Docs" / "Analysis" / "render_plotly_commit_history.py"
    if not plotly_python.is_file():
        raise AnalysisError(
            "Plotly Python environment is required. Expected "
            "ThirdParty/plotly_install/bin/python or set "
            "PLOTLY_PYTHON to a Python executable containing Plotly."
        )
    if not renderer.is_file():
        raise AnalysisError(f"Plotly renderer is missing: {renderer}")
    payload_path = ctx.output_dir / "data" / "commit-history-plot.json"
    chart_path = ctx.output_dir / "charts" / "commit-history-timeline.html"
    payload_path.write_text(
        json.dumps(commit_history_plot_payload(data), indent=2, ensure_ascii=False, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    result = subprocess.run(
        [str(plotly_python), str(renderer), str(payload_path), str(chart_path)],
        cwd=ctx.repo_root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit status {result.returncode}"
        raise AnalysisError(f"Plotly commit-history chart generation failed: {detail}")
    ctx.plotly_version = result.stdout.strip()


def html_join_links(items: Iterable[tuple[str, str]]) -> str:
    values = [link(label, href) for label, href in items]
    return ", ".join(values) if values else "None"


def write_transcripts_without_timestamps_notes_page(ctx: AnalysisContext, data: dict[str, Any]) -> None:
    transcripts = [item for item in data["transcripts"] if item["transcript_id"] in TRANSCRIPTS_WITHOUT_TIMESTAMPS_IDS]
    rows = []
    for transcript in sorted(transcripts, key=lambda item: item["transcript_id"]):
        rows.append([
            link(transcript["transcript_id"], source_html_path_for_transcript(transcript["transcript_id"]) + "#L1"),
            transcript["line_count"], transcript["turn_count"], transcript["back_and_forth_count"],
            html.escape(transcript["elapsed_confidence"]),
            html_join_links((feature_id[:7], source_html_path_for_commit(feature_id[:7])) for feature_id in transcript["associated_feature_ids"]),
        ])
    body = """
<p>Known historical transcripts below contain countable conversation but no usable per-turn timing.</p>
<ul>
  <li>Lines, turns, speaker counts, back-and-forth, Commit evidence, Plan evidence, and Theme evidence remain available.</li>
  <li>Elapsed, Assistant-processing, and User-response timing remain null. Report never fabricates duration.</li>
  <li>Difficulty scoring projects unavailable timing to zero without renormalizing configured weights and reports weight coverage.</li>
</ul>
""" + table(["Transcript", "Lines", "Turns", "Back/Forth", "Timing", "Associated Commits"], rows)
    (ctx.output_dir / "transcripts-without-timestamps-notes.html").write_text(
        html_page("Transcripts Without Timestamps Notes", body), encoding="utf-8"
    )


def write_early_commit_notes_page(ctx: AnalysisContext, data: dict[str, Any]) -> None:
    sequence = {commit["full_hash"]: index for index, commit in enumerate(data["commits"])}
    start = sequence.get(EARLY_COMMIT_NOTES_START_HASH, 0)
    end = sequence.get(EARLY_COMMIT_NOTES_END_HASH, start)
    commits = data["commits"][start : end + 1]
    rows = [
        [
            link(commit["short_hash"], source_html_path_for_commit(commit["short_hash"])),
            html.escape(parse_date(commit["author_date"]) or ""), html.escape(commit["subject"]),
            link("Commit", source_html_path_for_commit(commit["short_hash"])),
            commit["code_line_count"], commit["test_line_count"], commit["docs_line_count"],
        ]
        for commit in commits
    ]
    body = """
<p>Every early commit is a canonical analytical Commit, including commits without Plan or transcript work evidence.</p>
<ul>
  <li>Commit identity equals full git hash.</li>
  <li>Code, test, documentation, and Plan-path line changes remain direct Commit inputs.</li>
  <li>Conversation metrics appear only when checked-in reviewed transcript segments allocate work to that Commit.</li>
  <li>Missing conversation evidence remains visible as unavailable or zero raw evidence, never inferred from commit time.</li>
</ul>
""" + table(["Hash", "Date", "Subject", "Commit", "Code", "Tests", "Docs"], rows)
    (ctx.output_dir / "early-commits-contribution-notes.html").write_text(
        html_page("Early Commits Contribution Notes", body), encoding="utf-8"
    )


def warning_source_href(ctx: AnalysisContext, row: dict[str, Any]) -> str | None:
    source_type = str(row["source_type"])
    source_id = str(row["source_id"])
    anchor_line: int | None = None
    if source_type == "commit" and re.fullmatch(r"[0-9a-f]{7,40}", source_id):
        href = source_html_path_for_commit(source_id[:7])
    elif source_type == "transcript":
        href = source_html_path_for_transcript(source_id)
        anchor_line = int(row["line"]) if str(row["line"]).isdigit() else 1
    elif source_type == "plan" and source_id.isdigit():
        href = f"plans/{source_id}.html"
    elif source_type == "plan_source":
        href = source_html_path_for_plan(source_id)
        anchor_line = int(row["line"]) if str(row["line"]).isdigit() else 1
    elif source_type in {"documentation", "user_documentation"}:
        href = source_html_path_for_doc(source_id)
        anchor_line = int(row["line"]) if str(row["line"]).isdigit() else 1
    elif source_type == "theme":
        href = f"themes/{source_id}.html"
    elif source_type == "html":
        href = source_id
    else:
        return None
    if not (ctx.output_dir / href).exists():
        return None
    return href + (f"#L{anchor_line}" if anchor_line is not None else "")


def remainder_impact_label(
    remainder: dict[str, float | None] | None,
    transcript: dict[str, Any],
) -> str:
    totals = {
        "lines": transcript.get("line_count"),
        "assistant_processing": transcript.get("assistant_processing_seconds"),
        "user_response": transcript.get("user_response_seconds"),
        "back_and_forth": transcript.get("back_and_forth_count"),
    }
    values = [
        float(value)
        for key, value in (remainder or {}).items()
        if value is not None and float(totals.get(key) or 0) > 0.000001
    ]
    if not values or all(value <= 0.000001 for value in values):
        return "Included"
    if all(value >= 0.999999 for value in values):
        return "Excluded"
    return "Partial; remainder excluded"


def theme_time_impact_label(data: dict[str, Any], transcript_id: str) -> str:
    transcript = next(
        (item for item in data["transcripts"] if item["transcript_id"] == transcript_id),
        None,
    )
    if transcript is None or transcript.get("valid_atomic_elapsed_seconds") is None:
        return "Unavailable timing"
    total = float(transcript["valid_atomic_elapsed_seconds"] or 0)
    if total <= 0.000001:
        return "No timed evidence"
    themed_feature_ids = {
        feature["feature_id"] for feature in data["features"] if feature["parent_theme_ids"]
    }
    themed_plan_ids = {
        plan["plan_id"] for plan in data["plans"] if plan["parent_theme_ids"]
    }

    def lens_label(entity_type: str, themed_ids: set[str]) -> str:
        allocated = sum(
            float(allocation.get("allocated_visible_elapsed_seconds") or 0)
            for allocation in data["segment_allocations"]
            if allocation["transcript_id"] == transcript_id
            and allocation["entity_type"] == entity_type
            and allocation["entity_id"] in themed_ids
        )
        if allocated <= 0.000001:
            return "Excluded"
        if math.isclose(allocated, total, abs_tol=0.000001):
            return "Included"
        return "Partial"

    return (
        f"Commit lens {lens_label('feature', themed_feature_ids)}; "
        f"Plan lens {lens_label('plan', themed_plan_ids)}"
    )


def warning_metric_impacts(row: dict[str, Any], data: dict[str, Any]) -> tuple[str, str, str]:
    category = str(row["category"])
    if category == "semantic_review_unallocated" and row["source_type"] == "transcript":
        transcript = next(
            (item for item in data["transcripts"] if item["transcript_id"] == row["source_id"]),
            None,
        )
        if transcript is None:
            return "Unknown", "Unknown", "Unknown"
        return (
            remainder_impact_label(transcript.get("feature_unallocated_remainder"), transcript),
            remainder_impact_label(transcript.get("plan_unallocated_remainder"), transcript),
            theme_time_impact_label(data, str(row["source_id"])),
        )
    if category == "missing_theme_assignment":
        return "Included", "Unaffected", "Excluded (no accepted Theme)"
    return "Unaffected", "Unaffected", "Unaffected"


def write_warning_page(ctx: AnalysisContext, data: dict[str, Any]) -> None:
    rows = []
    for row in warning_rows(ctx):
        source_href = warning_source_href(ctx, row)
        source_cell = link(row["source_id"], source_href) if source_href else html.escape(row["source_id"])
        commit_impact, plan_impact, theme_impact = warning_metric_impacts(row, data)
        rows.append([
            html.escape(row["source_type"]), source_cell, html.escape(row["category"]),
            html.escape(row["message"]), html.escape(commit_impact), html.escape(plan_impact),
            html.escape(theme_impact), row["line"],
        ])
    body = '<p><a href="data/warnings.csv">source data</a></p>' + table(
        [
            "Source Type", "Source", "Category", "Message", "Commit Difficulty",
            "Plan Difficulty", "Theme Time", "Line",
        ],
        rows,
    )
    (ctx.output_dir / "warnings.html").write_text(html_page("Warnings", body), encoding="utf-8")


def write_report_pages(ctx: AnalysisContext, data: dict[str, Any]) -> None:
    features = data["features"]
    plans = data["plans"]
    themes = data["themes"]
    difficulty_weights = data["difficulty_weights"]
    features_by_id = {feature["feature_id"]: feature for feature in features}
    plans_by_id = {plan["plan_id"]: plan for plan in plans}
    themes_by_id = {theme["theme_id"]: theme for theme in themes}
    commits_by_hash = {commit["full_hash"]: commit for commit in data["commits"]}
    transcripts_by_id = {transcript["transcript_id"]: transcript for transcript in data["transcripts"]}
    allocations_by_feature: dict[str, list[dict[str, Any]]] = {}
    allocations_by_plan: dict[str, list[dict[str, Any]]] = {}
    for allocation in data["segment_allocations"]:
        target = allocations_by_feature if allocation["entity_type"] == "feature" else allocations_by_plan
        target.setdefault(allocation["entity_id"], []).append(allocation)

    themed_count = sum(feature["theme_coverage_state"] == "assigned" for feature in features)
    index_body = f"""
<section class="summary-grid">
  <div><strong>Commits</strong><span>{len(data['commits'])}</span></div>
  <div><strong>Plans</strong><span>{len(plans)}</span></div>
  <div><strong>Transcripts</strong><span>{len(data['transcripts'])}</span></div>
  <div><strong>Themes</strong><span>{len(themes)}</span></div>
  <div><strong>Theme Coverage</strong><span>{themed_count}/{len(features)}</span></div>
  <div><strong>Warnings</strong><span>{len(ctx.warnings)}</span></div>
</section>
<p>Commit, Plan, and Theme views are separate analytical lenses. Totals are not additive across lenses.</p>
<h2>Top Commit Difficulty</h2>
"""
    index_body += table(
        ["Commit", "Hash", "Score", "Label", "Elapsed", "Plans"],
        [[
            link(feature["display_name"], source_html_path_for_commit(feature["short_hash"])), feature["short_hash"],
            f"{feature['difficulty_score']:.1f}", feature["difficulty_label"],
            format_seconds(feature["total_visible_conversation_elapsed_seconds"]), len(feature["linked_plan_ids"]),
        ] for feature in sorted(features, key=lambda row: (-row["difficulty_score"], row["feature_id"]))[:15]],
    )
    index_body += """
<h3>Commit Activity And Coverage Timeline</h3>
<iframe class="plotly-chart" src="charts/commit-history-timeline.html"
  title="Commit line counts, difficulty, Plan commit dates, and transcript commit dates"></iframe>
<p><a href="difficulty.html#commit-difficulty-description">Commit Difficulty derivation and description</a></p>
"""
    index_body += '<p><a href="data/metrics.json">metrics JSON</a> · <a href="data/run_metadata.json">run metadata</a></p>'
    (ctx.output_dir / "index.html").write_text(html_page("SwiftTag Project Analysis", index_body), encoding="utf-8")

    commit_rows = []
    for feature in sorted(features, key=lambda row: (parse_date(row["author_date"]) or "", row["feature_id"])):
        theme_links = html_join_links((themes_by_id[theme_id]["display_name"], f"themes/{theme_id}.html") for theme_id in feature["parent_theme_ids"])
        plan_links = html_join_links((f"Plan {plan_id}", f"plans/{plan_id}.html") for plan_id in feature["linked_plan_ids"])
        transcript_links = html_join_links(
            (transcript_id, source_html_path_for_transcript(transcript_id) + "#L1")
            for transcript_id in feature["linked_transcript_ids"]
        )
        commit_rows.append([
            link(feature["short_hash"], source_html_path_for_commit(feature["short_hash"])),
            html.escape(parse_date(feature["author_date"]) or ""), html.escape(feature["subject"]), theme_links,
            f"{feature['difficulty_score']:.1f} {feature['difficulty_label']}", f"{feature['total_code_lines_changed']:.0f}",
            f"{feature['total_transcript_lines']:.1f}", format_seconds(feature["total_visible_conversation_elapsed_seconds"]),
            plan_links, transcript_links, f"{feature['total_test_lines_changed']:.0f}",
            f"{feature['total_documentation_lines_changed']:.0f}",
        ])
    commits_body = '<p><a href="data/commits.csv">source data</a></p>' + table(
        ["Hash", "Date", "Subject", "Themes", "Difficulty", "Code", "Transcript Lines", "Elapsed", "Plans", "Transcripts", "Tests", "Docs"],
        commit_rows, "commit-table",
    )
    (ctx.output_dir / "commits.html").write_text(html_page("Commits", commits_body), encoding="utf-8")

    timestamp_ids = TRANSCRIPTS_WITHOUT_TIMESTAMPS_IDS
    for feature in features:
        commit = commits_by_hash[feature["feature_id"]]
        theme_links = html_join_links((themes_by_id[theme_id]["display_name"], f"../../themes/{theme_id}.html") for theme_id in feature["parent_theme_ids"])
        plan_links = html_join_links((f"Plan {plan_id}: {plans_by_id[plan_id]['display_title']}", f"../../plans/{plan_id}.html") for plan_id in feature["linked_plan_ids"])
        transcript_links = html_join_links((transcript_id, f"../../{source_html_path_for_transcript(transcript_id)}#L1") for transcript_id in feature["linked_transcript_ids"])
        allocation_rows = [[
            link(row["transcript_id"], f"../../{source_html_path_for_transcript(row['transcript_id'])}#L{row['source_line_start']}"),
            html.escape(row["segment_id"]), html.escape(row["role"]), f"{row['allocation_weight']:.3f}",
            f"{row['allocated_source_lines']:.1f}", format_seconds(row["allocated_visible_elapsed_seconds"]),
        ] for row in allocations_by_feature.get(feature["feature_id"], [])]
        file_rows = [[html.escape(row["path"]), row["additions"], row["deletions"], html.escape(row["path_class"])] for row in data["commit_files"] if row["commit_hash"] == feature["feature_id"]]
        commit_date = html.escape(parse_date(commit["author_date"]) or "Unavailable")
        body = f"""
<p><strong>Commit Date:</strong> {commit_date}</p>
<p><code>{feature['feature_id']}</code></p>
<p>{html.escape(feature['subject'])}</p>
{('<h2>Body</h2><pre>' + html.escape(commit['body']) + '</pre>') if commit['body'] else ''}
<section class="summary-grid">
  <div><strong>Difficulty</strong><span>{feature['difficulty_score']:.1f} {feature['difficulty_label']}</span></div>
  <div><strong>Weight Coverage</strong><span>{feature['difficulty_weight_coverage']:.0%}</span></div>
  <div><strong>Elapsed</strong><span>{format_seconds(feature['total_visible_conversation_elapsed_seconds'])}</span></div>
  <div><strong>Assistant</strong><span>{format_seconds(feature['total_assistant_processing_seconds'])}</span></div>
  <div><strong>User Response</strong><span>{format_seconds(feature['total_user_response_seconds'])}</span></div>
  <div><strong>Back/Forth</strong><span>{feature['back_and_forth_count']:.1f}</span></div>
</section>
<h2>Themes</h2><p>{theme_links}</p>
<h2>Associated Plans</h2><p>{plan_links}</p>
<h2>Associated Transcripts</h2><p>{transcript_links}</p>
<h2>Reviewed Segment Evidence</h2>{table(['Transcript', 'Segment', 'Role', 'Weight', 'Lines', 'Atomic Elapsed'], allocation_rows)}
<h2>Changed Files</h2>{table(['Path', 'Additions', 'Deletions', 'Class'], file_rows)}
<h2>Difficulty Inputs</h2>{table(['Signal', 'Raw Value'], [[html.escape(key), 'Unavailable' if value is None else f'{value:.2f}'] for key, value in feature['difficulty_inputs'].items()])}
<h2>Notes</h2>
"""
        notes = []
        if timestamp_ids.intersection(feature["linked_transcript_ids"]):
            notes.append('<a href="../../transcripts-without-timestamps-notes.html">Transcript timing unavailable notes</a>')
        if feature["theme_coverage_state"] != "assigned":
            notes.append("Theme assignment needs review; no default Theme applied.")
        body += "<ul>" + "".join(f"<li>{note}</li>" for note in notes) + "</ul>" if notes else "<p>No Commit-specific notes.</p>"
        (ctx.output_dir / source_html_path_for_commit(feature["short_hash"])).write_text(
            html_page("Commit: " + feature["display_name"], body, "../../"), encoding="utf-8"
        )

    plan_rows = []
    for plan in plans:
        plan_rows.append([
            link(f"Plan {plan['plan_id']}", f"plans/{plan['plan_id']}.html"), html.escape(plan["display_title"]),
            plan["version_count"], html_join_links((themes_by_id[item]["display_name"], f"themes/{item}.html") for item in plan["parent_theme_ids"]),
            link(plan["creation_commit_id"][:7], source_html_path_for_commit(plan["creation_commit_id"][:7])) if plan["creation_commit_id"] else "Unresolved",
            len(plan["implementation_commit_ids"]), len(plan["associated_transcript_ids"]),
            format_seconds(plan["direct_visible_elapsed_seconds"]), format_seconds(plan["implementation_visible_elapsed_seconds"]),
            f"{plan['difficulty_score']:.1f} {plan['difficulty_label']}",
            html.escape(plan["first_evidence_date"] or ""), html.escape(plan["last_evidence_date"] or ""),
        ])
    plans_body = '<p><a href="data/plans.csv">source data</a></p>' + table(
        ["Plan", "Title", "Versions", "Themes", "Creation Commit", "Implementation Commits", "Transcripts", "Direct Time", "Implementation Time", "Difficulty", "First Evidence", "Last Evidence"],
        plan_rows,
    )
    (ctx.output_dir / "plans.html").write_text(html_page("Plans", plans_body), encoding="utf-8")

    revisions_by_plan: dict[str, list[dict[str, Any]]] = {}
    for revision in data["plan_revisions"]:
        revisions_by_plan.setdefault(revision["plan_id"], []).append(revision)
    for plan in plans:
        source_links = html_join_links((source_id, f"../{source_html_path_for_plan(source_id)}#L1") for source_id in plan["source_plan_ids"])
        feature_links = html_join_links((f"{features_by_id[item]['short_hash']} {features_by_id[item]['display_name']}", f"../{source_html_path_for_commit(features_by_id[item]['short_hash'])}") for item in plan["associated_feature_ids"])
        transcript_links = html_join_links((item, f"../{source_html_path_for_transcript(item)}#L1") for item in plan["associated_transcript_ids"])
        revision_rows = [[
            link(row["short_hash"], f"../{source_html_path_for_commit(row['short_hash'])}"), html.escape(row["roles"]),
            html.escape(row["path"]), row["additions"], row["deletions"], html.escape(parse_date(row["author_date"]) or ""),
        ] for row in revisions_by_plan.get(plan["plan_id"], [])]
        allocation_rows = [[
            link(row["transcript_id"], f"../{source_html_path_for_transcript(row['transcript_id'])}#L{row['source_line_start']}"),
            row["segment_id"], html.escape(row["role"]), f"{row['allocation_weight']:.3f}",
            f"{row['allocated_source_lines']:.1f}", format_seconds(row["allocated_visible_elapsed_seconds"]),
        ] for row in allocations_by_plan.get(plan["plan_id"], [])]
        body = f"""
<p>{html.escape(plan['display_title'])}</p>
<section class="summary-grid">
  <div><strong>Difficulty</strong><span>{plan['difficulty_score']:.1f} {plan['difficulty_label']}</span></div>
  <div><strong>Direct Time</strong><span>{format_seconds(plan['direct_visible_elapsed_seconds'])}</span></div>
  <div><strong>Implementation Time</strong><span>{format_seconds(plan['implementation_visible_elapsed_seconds'])}</span></div>
  <div><strong>Plan Lines</strong><span>{plan['current_source_line_count']}</span></div>
  <div><strong>Revision Churn</strong><span>{plan['revision_additions'] + plan['revision_deletions']}</span></div>
  <div><strong>Implementation Code</strong><span>{plan['implementation_code_lines']:.0f}</span></div>
</section>
<h2>Sources</h2><p>{source_links}</p>
<h2>Commits</h2><p>{feature_links}</p>
<h2>Transcripts</h2><p>{transcript_links}</p>
<h2>Revision Timeline</h2>{table(['Commit', 'Roles', 'Path', 'Additions', 'Deletions', 'Date'], revision_rows)}
<h2>Reviewed Transcript Segments</h2>{table(['Transcript', 'Segment', 'Role', 'Weight', 'Lines', 'Atomic Elapsed'], allocation_rows)}
<h2>Difficulty Inputs</h2>{table(['Signal', 'Raw Value'], [[html.escape(key), 'Unavailable' if value is None else f'{value:.2f}'] for key, value in plan['difficulty_inputs'].items()])}
"""
        (ctx.output_dir / "plans" / f"{plan['plan_id']}.html").write_text(
            html_page(f"Plan {plan['plan_id']}: {plan['display_title']}", body, "../"), encoding="utf-8"
        )

    theme_rows = [[
        link(theme["display_name"], f"themes/{theme['theme_id']}.html"), theme["child_feature_count"], theme["child_plan_count"],
        f"{theme['feature_allocated_transcript_lines']:.1f}", format_seconds(theme["feature_allocated_elapsed_seconds"]),
        f"{theme['mean_feature_difficulty']:.1f}", f"{theme['mean_plan_difficulty']:.1f}",
    ] for theme in themes]
    themes_body = '<p>Commit and Plan metrics are separate, non-additive lenses.</p><p><a href="data/themes.csv">source data</a> · <a href="data/theme_coverage.csv">coverage data</a></p>' + table(
        ["Theme", "Commits", "Plans", "Allocated Commit Transcript Lines", "Allocated Commit Time", "Mean Commit Difficulty", "Mean Plan Difficulty"], theme_rows,
    )
    themes_body += f"<p>Themed commits: {themed_count}; unthemed: {len(features) - themed_count}; coverage: {themed_count / max(len(features), 1):.1%}.</p>"
    (ctx.output_dir / "themes.html").write_text(html_page("Themes", themes_body), encoding="utf-8")
    for theme in themes:
        feature_links = html_join_links((f"{features_by_id[item]['short_hash']} {features_by_id[item]['display_name']}", f"../{source_html_path_for_commit(features_by_id[item]['short_hash'])}") for item in theme["child_feature_ids"])
        plan_links = html_join_links((f"Plan {item}: {plans_by_id[item]['display_title']}", f"../plans/{item}.html") for item in theme["child_plan_ids"])
        body = f"""
<p>{html.escape(theme['description'])}</p>
<h2>Commits</h2><p>{feature_links}</p>
<h2>Plans</h2><p>{plan_links}</p>
<h2>Separate Lenses</h2>
{table(['Lens', 'Transcript Lines', 'Code/Plan Lines', 'Elapsed', 'Mean Difficulty'], [
    ['Commit', f"{theme['feature_allocated_transcript_lines']:.1f}", f"{theme['feature_allocated_code_lines']:.1f}", format_seconds(theme['feature_allocated_elapsed_seconds']), f"{theme['mean_feature_difficulty']:.1f}"],
    ['Plan', 'See Plan records', f"{theme['plan_direct_lines']:.1f} direct / {theme['plan_implementation_code_lines']:.1f} implementation", format_seconds(theme['plan_allocated_elapsed_seconds']), f"{theme['mean_plan_difficulty']:.1f}"],
])}
<p><a href="../review-packets/themes/{theme['theme_id']}.md">review packet</a></p>
"""
        (ctx.output_dir / "themes" / f"{theme['theme_id']}.html").write_text(
            html_page("Theme: " + theme["display_name"], body, "../"), encoding="utf-8"
        )

    assistant_stats = summary_stats([float(turn["assistant_processing_seconds"]) for turn in data["turns"] if turn["assistant_processing_seconds"] is not None])
    user_stats = summary_stats([float(turn["user_response_seconds"]) for turn in data["turns"] if turn["user_response_seconds"] is not None])
    def stats_table(stats: dict[str, Any]) -> str:
        return table(["Count", "Min", "Max", "Mean", "Median", "Total"], [[stats["count"], format_seconds(stats["min"]), format_seconds(stats["max"]), format_seconds(stats["mean"]), format_seconds(stats["median"]), format_seconds(stats["total"])]])
    response_body = "<h2>Assistant Processing</h2>" + stats_table(assistant_stats) + "<h2>User Response</h2>" + stats_table(user_stats)
    response_body += "<h2>User Response Brackets</h2>" + table(
        ["Bracket", "Count", "Min", "Max", "Mean", "Median", "Total"],
        [[label, stats["count"], format_seconds(stats["min"]), format_seconds(stats["max"]), format_seconds(stats["mean"]), format_seconds(stats["median"]), format_seconds(stats["total"])] for label, stats in response_brackets(data["turns"]).items()],
    )
    response_body += "<h2>Plan Allocation View</h2>" + table(
        ["Plan", "Direct", "Implementation", "Assistant", "User Response"],
        [[link(f"Plan {plan['plan_id']}", f"plans/{plan['plan_id']}.html"), format_seconds(plan["direct_visible_elapsed_seconds"]), format_seconds(plan["implementation_visible_elapsed_seconds"]), format_seconds(plan["total_assistant_processing_seconds"]), format_seconds(plan["total_user_response_seconds"])] for plan in plans],
    )
    (ctx.output_dir / "response-times.html").write_text(html_page("Response Times", response_body), encoding="utf-8")

    def weight_percent(signal: str) -> str:
        return f"{float(difficulty_weights[signal]):.0%}"

    commit_difficulty_description = f"""
<h2 id="commit-difficulty-description">Commit Difficulty</h2>
<div class="difficulty-description">
  <p>Commit Difficulty is a relative score from 0 to 100. Each raw signal is converted to its percentile rank among all Commits in this report, then multiplied by its configured weight. Weighted percentile contributions are summed; Commit and Plan percentile populations are independent.</p>
  <ul>
    <li><strong>Changed application-code lines ({weight_percent('code_lines')}):</strong> application-code additions plus deletions attributed to the Commit; tests, documentation, Plans, transcripts, fixtures, and other files are excluded.</li>
    <li><strong>Allocated transcript lines ({weight_percent('transcript_lines')}):</strong> reviewed transcript-segment lines allocated to the Commit.</li>
    <li><strong>Changed Plan lines ({weight_percent('plan_lines')}):</strong> Plan-file additions plus deletions made by the Commit.</li>
    <li><strong>Allocated visible conversation time ({weight_percent('elapsed_time')}):</strong> valid Assistant-processing and User-response time allocated from reviewed transcript segments.</li>
    <li><strong>Allocated Assistant processing time ({weight_percent('assistant_processing_time')}):</strong> Assistant work time allocated from reviewed transcript segments.</li>
    <li><strong>Allocated back-and-forth count ({weight_percent('back_and_forth_count')}):</strong> User-to-Assistant exchanges allocated from reviewed transcript segments.</li>
  </ul>
  <p>For each signal, percentile rank equals the percentage of report Commits with a value less than or equal to the current value. Zero, non-positive, or unavailable values contribute zero. Unavailable signals reduce Weight Coverage; remaining weights are not renormalized.</p>
  <p>Labels use fixed score thresholds: Low below 25, Moderate from 25 to below 50, High from 50 to below 75, and Very High at 75 or above.</p>
</div>
"""
    difficulty_body = "<p>Commit and Plan cohorts use same configured weights but independent percentile populations. Unavailable signals project to zero contribution without per-record weight renormalization.</p>"
    difficulty_body += commit_difficulty_description + table(
        ["Commit", "Score", "Label", "Coverage", "Code", "Transcript", "Plan", "Elapsed", "Assistant", "Back/Forth"],
        [[link(feature["display_name"], source_html_path_for_commit(feature["short_hash"])), f"{feature['difficulty_score']:.1f}", feature["difficulty_label"], f"{feature['difficulty_weight_coverage']:.0%}", f"{feature['total_code_lines_changed']:.0f}", f"{feature['total_transcript_lines']:.1f}", f"{feature['total_plan_lines']:.0f}", format_seconds(feature["total_visible_conversation_elapsed_seconds"]), format_seconds(feature["total_assistant_processing_seconds"]), f"{feature['back_and_forth_count']:.1f}"] for feature in sorted(features, key=lambda row: (-row["difficulty_score"], row["feature_id"]))],
    )
    plan_difficulty_description = f"""
<h2 id="plan-difficulty-description">Plan Difficulty</h2>
<div class="difficulty-description">
  <p>Plan Difficulty uses the same weighted-percentile method as Commit Difficulty, but ranks each Plan only against other Plans in this report.</p>
  <ul>
    <li><strong>Implementation code lines ({weight_percent('code_lines')}):</strong> changed application-code lines from implementation Commits associated with the Plan; code shared by multiple Plans is divided across those Plans.</li>
    <li><strong>Allocated transcript lines ({weight_percent('transcript_lines')}):</strong> direct and implementation transcript-segment lines allocated to the Plan.</li>
    <li><strong>Current Plan lines ({weight_percent('plan_lines')}):</strong> line count of the Plan family's current source file.</li>
    <li><strong>Allocated visible conversation time ({weight_percent('elapsed_time')}):</strong> valid Assistant-processing and User-response time allocated to the Plan.</li>
    <li><strong>Allocated Assistant processing time ({weight_percent('assistant_processing_time')}):</strong> Assistant work time allocated to the Plan.</li>
    <li><strong>Allocated back-and-forth count ({weight_percent('back_and_forth_count')}):</strong> User-to-Assistant exchanges allocated to the Plan.</li>
  </ul>
  <p>Each signal's Plan percentile is multiplied by its configured weight and summed into the 0-to-100 score. Zero, non-positive, or unavailable values contribute zero. Unavailable signals reduce Weight Coverage without renormalizing remaining weights. Label thresholds match Commit Difficulty.</p>
</div>
"""
    difficulty_body += plan_difficulty_description + table(
        ["Plan", "Score", "Label", "Coverage", "Implementation Code", "Transcript", "Current Plan Lines", "Elapsed", "Assistant", "Back/Forth"],
        [[link(f"Plan {plan['plan_id']}", f"plans/{plan['plan_id']}.html"), f"{plan['difficulty_score']:.1f}", plan["difficulty_label"], f"{plan['difficulty_weight_coverage']:.0%}", f"{plan['implementation_code_lines']:.1f}", f"{plan['direct_transcript_lines'] + plan['implementation_transcript_lines']:.1f}", plan["current_source_line_count"], format_seconds(plan["total_visible_conversation_elapsed_seconds"]), format_seconds(plan["total_assistant_processing_seconds"]), f"{plan['back_and_forth_count']:.1f}"] for plan in sorted(plans, key=lambda row: (-row["difficulty_score"], row["plan_id"]))],
    )
    (ctx.output_dir / "difficulty.html").write_text(html_page("Difficulty", difficulty_body), encoding="utf-8")

    transcript_rows = [[
        link(transcript["transcript_id"], source_html_path_for_transcript(transcript["transcript_id"]) + "#L1"),
        transcript["export_date"], transcript["line_count"], transcript["turn_count"],
        format_seconds(transcript["valid_atomic_elapsed_seconds"]), html.escape(transcript["semantic_review_status"]),
        html_join_links((item[:7], source_html_path_for_commit(item[:7])) for item in transcript["associated_feature_ids"]),
        html_join_links((f"Plan {item}", f"plans/{item}.html") for item in transcript["associated_plan_ids"]),
    ] for transcript in data["transcripts"]]
    (ctx.output_dir / "transcripts.html").write_text(html_page(
        "Transcripts", '<p><a href="data/transcripts.csv">source data</a> · <a href="data/semantic_review_status.csv">review status</a></p>' + table(
            ["Transcript", "Date", "Lines", "Turns", "Atomic Elapsed", "Review", "Commits", "Plans"], transcript_rows
        )
    ), encoding="utf-8")

    chart_paths = [
        *sorted((ctx.output_dir / "charts").glob("*.svg")),
        *sorted((ctx.output_dir / "charts").glob("*.html")),
    ]
    chart_links = [link(chart.stem.replace("-", " ").title(), f"charts/{chart.name}") for chart in chart_paths]
    (ctx.output_dir / "charts.html").write_text(html_page("Charts", "<ul>" + "".join(f"<li>{value}</li>" for value in chart_links) + "</ul>"), encoding="utf-8")
    write_early_commit_notes_page(ctx, data)
    write_transcripts_without_timestamps_notes_page(ctx, data)
    write_warning_page(ctx, data)


def write_assets(output_dir: Path) -> None:
    css = """
:root { color-scheme: light; --fg:#1c2526; --muted:#5d6668; --line:#d9e1e2; --panel:#f5f7f7; --accent:#2f6f73; }
body { margin:0; font:14px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; color:var(--fg); background:white; }
header { padding:20px 28px 12px; border-bottom:1px solid var(--line); background:var(--panel); }
main { padding:24px 28px 48px; max-width:1500px; }
h1 { margin:0 0 12px; font-size:28px; } h2 { margin-top:28px; }
nav a,a { color:var(--accent); text-decoration:none; } nav a { margin-right:12px; }
table { border-collapse:collapse; width:100%; margin:12px 0 24px; }
th,td { border:1px solid var(--line); padding:7px 9px; vertical-align:top; } th { background:var(--panel); text-align:left; }
pre { margin:0; white-space:pre-wrap; font-family:ui-monospace,SFMono-Regular,Menlo,monospace; }
.source-lines th { width:56px; text-align:right; user-select:none; } .source-lines td { width:100%; }
.summary-grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(160px,1fr)); gap:10px; margin:16px 0 24px; }
.summary-grid div { border:1px solid var(--line); background:var(--panel); padding:12px; }
.summary-grid strong { display:block; color:var(--muted); font-size:12px; }
.summary-grid span { display:block; font-size:20px; margin-top:4px; }
.plotly-chart { display:block; width:100%; height:780px; border:1px solid var(--line); }
"""
    (output_dir / "assets.css").write_text(css.strip() + "\n", encoding="utf-8")


class InternalHrefParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.hrefs: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        for name, value in attrs:
            if name == "href" and value:
                self.hrefs.append(value)

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self.handle_starttag(tag, attrs)


def validate_internal_links(ctx: AnalysisContext) -> None:
    for html_file in ctx.output_dir.rglob("*.html"):
        parser = InternalHrefParser()
        parser.feed(read_text(html_file))
        for href in parser.hrefs:
            if (
                href.startswith(("#", "//"))
                or re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", href)
            ):
                continue
            target_part = href.split("#", 1)[0]
            if not target_part:
                continue
            target = (html_file.parent / target_part).resolve()
            try:
                target.relative_to(ctx.output_dir.resolve())
            except ValueError:
                continue
            if not target.exists():
                ctx.warn("html", relpath(html_file, ctx.output_dir), "broken_internal_link", href)


def run_analysis(
    repo_root: Path,
    output_dir: Path,
    argv: list[str],
    *,
    review_only: bool = False,
    require_reviewed_associations: bool = False,
) -> AnalysisContext:
    ctx = AnalysisContext(
        repo_root=repo_root.resolve(),
        output_dir=output_dir.resolve(),
        require_reviewed_associations=require_reviewed_associations,
    )
    config_dir = ctx.repo_root / "Docs/Analysis/config"
    config_snapshot = {
        path: path.read_bytes()
        for path in sorted(config_dir.glob("*.json"))
    }
    ensure_dirs(ctx.output_dir)
    data = discover_inputs(ctx)
    data = build_cross_references(ctx, data, review_only=review_only)
    write_assets(ctx.output_dir)
    write_source_pages(ctx, data)
    write_transcript_review_packets(ctx, data)
    write_theme_review_packets(ctx, data)
    if review_only:
        write_data_files(ctx, data, argv)
    else:
        write_charts(ctx, data)
        write_data_files(ctx, data, argv)
        write_report_pages(ctx, data)
        warning_count = len(ctx.warnings)
        validate_internal_links(ctx)
        if len(ctx.warnings) != warning_count:
            write_data_files(ctx, data, argv)
            write_warning_page(ctx, data)
    for path, original in config_snapshot.items():
        if not path.exists() or path.read_bytes() != original:
            raise AnalysisError(f"Generator modified checked-in configuration: {path}")
    return ctx


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate deterministic SwiftTag project analysis reports.")
    parser.add_argument("--repo-root", default=".", help="Repository root path.")
    parser.add_argument("--output", default="Docs/Analysis/output", help="Generated output directory.")
    parser.add_argument("--review-only", action="store_true", help="Emit deterministic transcript review packets without requiring accepted semantic review.")
    parser.add_argument("--require-reviewed-associations", action="store_true", help="Fail unless every transcript has current valid reviewed associations.")
    args = parser.parse_args(argv)
    repo_root = Path(args.repo_root).resolve()
    output_arg = Path(args.output)
    output_dir = output_arg if output_arg.is_absolute() else (repo_root / output_arg)
    command_argv = sys.argv[1:] if argv is None else argv
    try:
        ctx = run_analysis(
            repo_root, output_dir, command_argv,
            review_only=args.review_only,
            require_reviewed_associations=args.require_reviewed_associations,
        )
    except AnalysisError as error:
        print(f"Analysis failed: {error}", file=sys.stderr)
        return 2
    print(f"Generated analysis: {ctx.output_dir}")
    print(f"Warnings: {len(ctx.warnings)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
