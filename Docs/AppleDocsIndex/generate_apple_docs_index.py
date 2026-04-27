#!/usr/bin/env python3
"""Generate an rg-friendly local Apple documentation index.

The script extracts text from installed DocC archives, docsets, and Xcode
AdditionalDocumentation markdown files into Docs/AppleDocsIndex/Generated.
It uses only Python standard library modules.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import html.parser
import json
import os
import pathlib
import re
import shutil
import sys
from typing import Any, Iterable


ROOT = pathlib.Path(__file__).resolve().parent
DEFAULT_OUTPUT = ROOT / "Generated"
DEFAULT_XCODE_APP = pathlib.Path("/Applications/Xcode.app")


class HTMLTextExtractor(html.parser.HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.parts: list[str] = []
        self._skip_depth = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.lower() in {"script", "style", "noscript"}:
            self._skip_depth += 1
        if tag.lower() in {"p", "br", "li", "h1", "h2", "h3", "h4", "tr"}:
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() in {"script", "style", "noscript"} and self._skip_depth:
            self._skip_depth -= 1
        if tag.lower() in {"p", "li", "h1", "h2", "h3", "h4", "tr"}:
            self.parts.append("\n")

    def handle_data(self, data: str) -> None:
        if not self._skip_depth:
            self.parts.append(data)

    def text(self) -> str:
        return normalize_text(" ".join(self.parts))


def normalize_text(value: str) -> str:
    value = value.replace("\r\n", "\n").replace("\r", "\n")
    value = re.sub(r"[ \t]+", " ", value)
    value = re.sub(r"\n{3,}", "\n\n", value)
    return value.strip()


def slug(value: str, fallback: str) -> str:
    value = re.sub(r"[^A-Za-z0-9._-]+", "-", value).strip("-._")
    return value[:140] or fallback


def newest_existing(paths: Iterable[pathlib.Path]) -> list[pathlib.Path]:
    existing = [path.expanduser() for path in paths if path.expanduser().exists()]
    return sorted(existing, key=lambda path: str(path))


def default_roots(xcode_app: pathlib.Path) -> list[pathlib.Path]:
    home = pathlib.Path.home()
    roots = [
        xcode_app / "Contents",
        home / "Library/Developer/Xcode",
        home / "Library/Developer/Shared/Documentation",
        pathlib.Path("/Library/Developer/Shared/Documentation"),
    ]
    return newest_existing(roots)


def additional_docs_roots(xcode_app: pathlib.Path) -> list[pathlib.Path]:
    return newest_existing(
        [
            xcode_app
            / "Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation"
        ]
    )


def iter_files(root: pathlib.Path, names: set[str]) -> Iterable[pathlib.Path]:
    for path in root.rglob("*"):
        if path.is_file() and path.name in names:
            yield path


def discover_docc_archives(roots: Iterable[pathlib.Path]) -> list[pathlib.Path]:
    archives: list[pathlib.Path] = []
    for root in roots:
        archives.extend(path for path in root.rglob("*.doccarchive") if path.is_dir())
    return sorted(set(archives), key=lambda path: str(path))


def discover_docsets(roots: Iterable[pathlib.Path]) -> list[pathlib.Path]:
    docsets: list[pathlib.Path] = []
    for root in roots:
        docsets.extend(path for path in root.rglob("*.docset") if path.is_dir())
    return sorted(set(docsets), key=lambda path: str(path))


def extract_markdown(path: pathlib.Path) -> str:
    text = path.read_text(encoding="utf-8", errors="ignore")
    text = re.sub(r"\A---\n.*?\n---\n", "", text, flags=re.S)
    return normalize_text(text)


def extract_html(path: pathlib.Path) -> str:
    parser = HTMLTextExtractor()
    parser.feed(path.read_text(encoding="utf-8", errors="ignore"))
    return parser.text()


def extract_json_text(data: Any) -> str:
    parts: list[str] = []
    skip_keys = {
        "identifier",
        "url",
        "images",
        "variants",
        "references",
        "metadata",
        "diffAvailability",
        "estimatedTime",
    }

    def walk(value: Any, key: str = "") -> None:
        if isinstance(value, str):
            if key not in skip_keys and not value.startswith("doc://"):
                parts.append(value)
            return
        if isinstance(value, list):
            for item in value:
                walk(item, key)
            return
        if isinstance(value, dict):
            if "text" in value and isinstance(value["text"], str):
                parts.append(value["text"])
            if "spelling" in value and isinstance(value["spelling"], str):
                parts.append(value["spelling"])
            for child_key, child_value in value.items():
                if child_key in skip_keys:
                    continue
                walk(child_value, child_key)

    walk(data)
    return normalize_text("\n".join(parts))


def extract_docc_json(path: pathlib.Path) -> tuple[str, str]:
    data = json.loads(path.read_text(encoding="utf-8", errors="ignore"))
    title = ""
    if isinstance(data, dict):
        metadata = data.get("metadata")
        if isinstance(metadata, dict):
            title = str(metadata.get("title") or metadata.get("roleHeading") or "")
        title = title or str(data.get("title") or "")
    return title, extract_json_text(data)


def write_record(output: pathlib.Path, source: pathlib.Path, title: str, text: str, kind: str) -> dict[str, str]:
    digest = hashlib.sha1(str(source).encode("utf-8")).hexdigest()[:12]
    record_name = slug(title or source.stem, digest) + f"-{digest}.txt"
    records_dir = output / "records"
    records_dir.mkdir(parents=True, exist_ok=True)
    record_path = records_dir / record_name
    body = "\n".join(
        [
            f"Title: {title or source.stem}",
            f"Kind: {kind}",
            f"Source: {source}",
            "",
            text,
            "",
        ]
    )
    record_path.write_text(body, encoding="utf-8")
    return {
        "title": title or source.stem,
        "kind": kind,
        "source": str(source),
        "record": str(record_path.relative_to(output)),
    }


def build_index(output: pathlib.Path, roots: list[pathlib.Path], include_additional_docs: bool) -> list[dict[str, str]]:
    records: list[dict[str, str]] = []

    for archive in discover_docc_archives(roots):
        for json_path in sorted(
            list((archive / "data/documentation").rglob("*.json"))
            + list((archive / "data/tutorials").rglob("*.json"))
        ):
            try:
                title, text = extract_docc_json(json_path)
            except Exception as error:
                print(f"warning: skipped {json_path}: {error}", file=sys.stderr)
                continue
            if text:
                records.append(write_record(output, json_path, title, text, "docc-json"))

    for docset in discover_docsets(roots):
        documents = docset / "Contents/Resources/Documents"
        if not documents.exists():
            continue
        for path in sorted(documents.rglob("*")):
            if not path.is_file() or path.suffix.lower() not in {".html", ".md", ".markdown"}:
                continue
            try:
                text = extract_html(path) if path.suffix.lower() == ".html" else extract_markdown(path)
            except Exception as error:
                print(f"warning: skipped {path}: {error}", file=sys.stderr)
                continue
            if text:
                records.append(write_record(output, path, path.stem, text, "docset"))

    if include_additional_docs:
        for docs_root in additional_docs_roots(DEFAULT_XCODE_APP):
            for path in sorted(docs_root.glob("*.md")):
                text = extract_markdown(path)
                if text:
                    records.append(write_record(output, path, path.stem, text, "xcode-additional-docs"))

    return records


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--source", action="append", type=pathlib.Path, help="Additional source root")
    parser.add_argument("--xcode-app", type=pathlib.Path, default=DEFAULT_XCODE_APP)
    parser.add_argument(
        "--no-additional-docs",
        action="store_true",
        help="Do not index Xcode AdditionalDocumentation markdown files",
    )
    args = parser.parse_args()

    roots = default_roots(args.xcode_app)
    if args.source:
        roots.extend(path.expanduser() for path in args.source if path.expanduser().exists())
    roots = sorted(set(roots), key=lambda path: str(path))

    output = args.output
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True, exist_ok=True)

    records = build_index(output, roots, include_additional_docs=not args.no_additional_docs)
    all_docs = []
    for record in records:
        all_docs.append((output / record["record"]).read_text(encoding="utf-8"))
    (output / "all-docs.txt").write_text("\n\n---\n\n".join(all_docs), encoding="utf-8")
    (output / "records.tsv").write_text(
        "kind\ttitle\trecord\tsource\n"
        + "\n".join(
            f"{record['kind']}\t{record['title']}\t{record['record']}\t{record['source']}"
            for record in records
        )
        + ("\n" if records else ""),
        encoding="utf-8",
    )
    metadata = {
        "generated_at_utc": _dt.datetime.now(_dt.timezone.utc).isoformat(timespec="seconds"),
        "record_count": len(records),
        "source_roots": [str(path) for path in roots],
    }
    (output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(records)} records in {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
