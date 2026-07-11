#!/usr/bin/env python3
from __future__ import annotations

import argparse
import html
import json
import math
from collections import defaultdict
from pathlib import Path
from typing import Any

import plotly
import plotly.graph_objects as go
from plotly.subplots import make_subplots


LANES = (
    ("Plan initial commit", "plans", "initial_commit", "diamond", "#2f6f73"),
    ("Plan covered commits", "plans", "covered_commits", "circle", "#2f6f73"),
    ("Transcript initial commit", "transcripts", "initial_commit", "diamond", "#76528f"),
    ("Transcript covered commits", "transcripts", "covered_commits", "circle", "#76528f"),
)


def group_events(
    entities: list[dict[str, Any]], commit_key: str, commit_order: dict[str, int]
) -> list[tuple[str, list[str]]]:
    grouped: dict[str, list[str]] = defaultdict(list)
    for entity in entities:
        values = entity.get(commit_key, [])
        commit_ids = values if isinstance(values, list) else [values]
        for commit_id in commit_ids:
            if commit_id in commit_order:
                grouped[commit_id].append(str(entity["label"]))
    return sorted(grouped.items(), key=lambda row: commit_order[row[0]])


def build_figure(payload: dict[str, Any]) -> go.Figure:
    commits = payload["commits"]
    if not commits:
        raise ValueError("Commit-history Plotly payload contains no commits")
    commits_by_hash = {commit["hash"]: commit for commit in commits}
    commit_order = {commit["hash"]: index for index, commit in enumerate(commits)}
    start = commits_by_hash[payload["start_commit"]]
    end = commits_by_hash[payload["end_commit"]]
    dates = [commit["author_date"] for commit in commits]
    commit_hover = [
        f"{html.escape(commit['short_hash'])} — {html.escape(commit['subject'])}"
        for commit in commits
    ]

    figure = make_subplots(
        rows=2,
        cols=1,
        shared_xaxes=True,
        vertical_spacing=0.14,
        row_heights=[0.66, 0.34],
        specs=[[{"secondary_y": True}], [{"secondary_y": False}]],
    )
    figure.add_trace(
        go.Bar(
            x=dates,
            y=[commit["code_lines"] for commit in commits],
            name="Commit changed code lines",
            marker={"color": "#5d9295", "line": {"width": 0}},
            opacity=0.72,
            customdata=commit_hover,
            hovertemplate=(
                "%{customdata}<br>%{x|%Y-%m-%d %H:%M UTC}"
                "<br>Changed code lines: %{y:,.0f}<extra></extra>"
            ),
        ),
        row=1,
        col=1,
        secondary_y=False,
    )
    figure.add_trace(
        go.Scatter(
            x=dates,
            y=[commit["difficulty"] for commit in commits],
            name="Commit difficulty",
            mode="lines",
            line={"color": "#b45f38", "width": 2, "shape": "linear"},
            connectgaps=False,
            customdata=commit_hover,
            hovertemplate=(
                "%{customdata}<br>%{x|%Y-%m-%d %H:%M UTC}"
                "<br>Difficulty: %{y:.1f}<extra></extra>"
            ),
        ),
        row=1,
        col=1,
        secondary_y=True,
    )

    for lane_name, entity_key, commit_key, symbol, color in LANES:
        events = group_events(payload[entity_key], commit_key, commit_order)
        event_commits = [commits_by_hash[commit_id] for commit_id, _ in events]
        entity_lists = [labels for _, labels in events]
        figure.add_trace(
            go.Scatter(
                x=[commit["author_date"] for commit in event_commits],
                y=[lane_name] * len(events),
                name=lane_name,
                mode="markers",
                marker={
                    "color": color,
                    "symbol": symbol,
                    "size": [min(28, 9 + 3 * math.sqrt(len(labels))) for labels in entity_lists],
                    "line": {"color": "#ffffff", "width": 1},
                },
                customdata=[
                    [
                        commit["short_hash"],
                        len(labels),
                        "<br>".join(html.escape(label) for label in labels),
                    ]
                    for commit, labels in zip(event_commits, entity_lists)
                ],
                hovertemplate=(
                    "%{y}<br>%{x|%Y-%m-%d %H:%M UTC}<br>Commit %{customdata[0]}"
                    "<br>Items: %{customdata[1]}<br>%{customdata[2]}<extra></extra>"
                ),
            ),
            row=2,
            col=1,
        )

    figure.update_layout(
        title={
            "text": "Commit Activity, Plan Coverage, And Transcript Coverage",
            "x": 0.01,
            "xanchor": "left",
        },
        height=760,
        margin={"l": 170, "r": 80, "t": 110, "b": 70},
        bargap=0.18,
        hovermode="closest",
        legend={
            "orientation": "h",
            "yanchor": "bottom",
            "y": 1.02,
            "xanchor": "left",
            "x": 0,
        },
        paper_bgcolor="#ffffff",
        plot_bgcolor="#ffffff",
        font={"family": "-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif", "color": "#1c2526"},
    )
    figure.update_xaxes(
        range=[start["author_date"], end["author_date"]],
        showgrid=True,
        gridcolor="#e4e9e9",
        linecolor="#b8c2c3",
        tickformat="%Y-%m-%d",
        row=1,
        col=1,
    )
    figure.update_xaxes(
        title_text="Commit author date (UTC)",
        range=[start["author_date"], end["author_date"]],
        showgrid=True,
        gridcolor="#e4e9e9",
        linecolor="#b8c2c3",
        tickformat="%Y-%m-%d",
        row=2,
        col=1,
    )
    figure.update_yaxes(
        title_text="Changed code lines",
        rangemode="tozero",
        showgrid=True,
        gridcolor="#e4e9e9",
        row=1,
        col=1,
        secondary_y=False,
    )
    figure.update_yaxes(
        title_text="Difficulty score",
        range=[0, 100],
        showgrid=False,
        row=1,
        col=1,
        secondary_y=True,
    )
    figure.update_yaxes(
        categoryorder="array",
        categoryarray=[lane[0] for lane in reversed(LANES)],
        showgrid=True,
        gridcolor="#edf0f0",
        row=2,
        col=1,
    )
    return figure


def main() -> int:
    parser = argparse.ArgumentParser(description="Render SwiftTag commit-history Plotly chart.")
    parser.add_argument("payload", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    payload = json.loads(args.payload.read_text(encoding="utf-8"))
    figure = build_figure(payload)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    figure.write_html(
        args.output,
        include_plotlyjs=True,
        full_html=True,
        auto_play=False,
        div_id="commit-history-plot",
        config={
            "displaylogo": False,
            "responsive": True,
            "scrollZoom": False,
            "toImageButtonOptions": {"format": "svg", "filename": "swifttag-commit-history"},
        },
    )
    print(plotly.__version__)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
