# SwiftTag Project Analysis

`analyze_swifttag_project.py` builds deterministic, offline reports from local
git history, numbered Plans, conversation transcripts, and user documentation.

## Analytical Model

- Report range is fixed and inclusive:
  `2c8445cbde7892ceff58fb58780a79278bcf7d6e` through
  `1071c2e0ffd3bbc279f2cca6e15509e725518e25`.
- Every in-range git commit produces exactly one analytical Commit.
- Commit identity uses canonical 40-character git hash. Detail page filename
  uses unique seven-character short hash.
- Commit display name is exact primary commit subject.
- Plans and transcript clusters never create Commits.
- Numbered Plans are separate analytical records. Explicit versions sharing
  one number form one family; repeated slugs under different numbers remain
  separate.
- Commit, Plan, and Theme metrics are alternative lenses. Never add their
  rollups together as independent project work.
- `Docs/Plans/34-SwiftTagProjectAnalysis.md` controls generator implementation
  and is excluded from report evidence and worktree metadata.

## Runtime Requirement

Python standard library handles extraction and report rendering. Matplotlib is
required for static charts. Matplotlib 3.11.0 is tested baseline; missing
package or SVG backend stops run with actionable error. Plotly renders
interactive Commit activity and coverage timeline embedded in index page.
Generator uses `ThirdParty/plotly_install/bin/python` by default; set
`PLOTLY_PYTHON` to another Python executable containing Plotly when needed.
Generator configures writable Matplotlib cache directories, noninteractive SVG
backend, fixed font/style/hash salt, and normalized SVG metadata.

Preflight:

```sh
MPLCONFIGDIR=Docs/Analysis/tmp/matplotlib \
XDG_CACHE_HOME=Docs/Analysis/tmp/cache \
python3 -c 'import matplotlib; matplotlib.use("svg", force=True); print(matplotlib.__version__)'
ThirdParty/plotly_install/bin/python -c 'import plotly; print(plotly.__version__)'
```

## Two-Pass Review Workflow

First emit deterministic transcript review packets:

```sh
python3 Docs/Analysis/analyze_swifttag_project.py \
  --repo-root . \
  --output Docs/Analysis/output \
  --review-only
```

Development-time reviewer reads packets, transcript segments, candidate commit
evidence, referenced Plans, and Plan 34 rubric. Reviewer records accepted and
rejected semantic decisions in `config/manual_links.json` schema version 2.
Generator itself never starts reviewer process, calls model API, imports model
SDK, or accesses network.

Generate report:

```sh
python3 Docs/Analysis/analyze_swifttag_project.py \
  --repo-root . \
  --output Docs/Analysis/output
```

Release gate:

```sh
python3 Docs/Analysis/analyze_swifttag_project.py \
  --repo-root . \
  --output Docs/Analysis/output \
  --require-reviewed-associations
```

Normal run renders missing, stale, or invalid review as warnings and excludes
affected semantic allocations from totals. Required-review run fails instead.
Generator validates configuration but never rewrites it.

## Reviewed Configuration

`config/manual_links.json` schema version 2 stores stable entity keys:

- `commit_transcripts`: membership/work/provenance edges keyed by full hash
- `commit_plans`: Plan roles keyed by full hash
- `plan_transcripts`: Plan/transcript membership and role evidence
- `theme_commits` and `theme_plans`: explicit positive and negative edges
- `commit_aliases`: display-independent matching aliases
- `documented_untimestamped_transcripts`: physical path and logical aliases
- `transcript_reviews`: content digest, review-input digest, segment ownership,
  Plan roles, accepted/rejected candidates, provenance, and explicit remainder
- lens-scoped `exclusive_*` collections
- fixed report boundaries and warning suppressions

Reviewed entry becomes stale when normalized transcript content, referenced
Plan evidence, candidate commit evidence, or review-method version changes.
Invalid/stale allocations never enter totals.

Schema-v1 compatibility conversion exists in memory for diagnostics and tests.
It is pure and idempotent. Checked-in schema version 2 remains authoritative.
Schema-v2 `feature_allocations` and `feature_unallocated_remainder` keys remain
unchanged for reviewed-config and digest compatibility; generated reports,
pages, data exports, and review guidance present this lens as Commit.

## Segment Allocation

Parser creates one base segment from each User turn plus following Assistant
turns until next User turn. Leading Assistant content becomes orphan segment.
Reviewed segment ranges determine metric-specific weights:

- source lines, including proportional header/note lines
- Assistant processing intervals
- User-response intervals assigned to preceding Assistant topic
- valid atomic elapsed time
- User-to-Assistant back-and-forth pairs

Commit and Plan lenses conserve metrics independently. Accepted allocations
plus explicit unallocated remainder equal source totals. Whole-transcript scalar
allocation is valid only with reviewed explanation that segmentation is not
possible. Transcript archive provenance always remains separate and receives
zero automatic work allocation.

Eight known untimestamped transcripts retain lines, turns, relationships, and
back-and-forth. Timing fields remain null and scoring projects unavailable
signals to zero without renormalizing configured weights. Difficulty output
reports original-weight coverage.

## Difficulty

`config/difficulty_weights.json` baseline:

- code lines: 0.30
- transcript lines: 0.15
- Plan lines: 0.10
- visible elapsed: 0.20
- Assistant processing: 0.10
- back-and-forth: 0.15

Commit and Plan cohorts normalize separately. Commit Plan-line input uses
Plan-path changes from sole commit. Plan direct input uses current source line
count while revision churn remains separate context.

## Generated Output

`Docs/Analysis/output` is replaced from clean model each run:

- main HTML: `index.html`, `commits.html`, `plans.html`, `themes.html`,
  `response-times.html`, `difficulty.html`, `charts.html`,
  `transcripts.html`, and `warnings.html`
- analytical Commit pages under `sources/commits/<short-hash>.html`; these
  replace prior raw commit mirrors and prior `features/<full-hash>.html` pages
- analytical Plan pages under `plans/<plan-family-id>.html`
- Theme pages under `themes/`
- Matplotlib SVG and offline Plotly timeline HTML under `charts/`
- transcript and Theme review packets under `review-packets/`
- line-anchored source mirrors under `sources/`
- flat analytical records and one-edge-per-row relationship/allocation files
  under `data/`
- notes for early commits and transcripts without timestamps

Warnings page links each resolvable Source value to corresponding generated
Commit, transcript, Plan, Theme, HTML, or source-mirror page. Sources without a
generated target remain plain text.

All configured Themes receive row, page, review packet, metrics, and chart
presence even when value is zero. Unthemed commits remain visible in
coverage denominator and matrix with `missing_theme_assignment` warning.

## Verification

```sh
python3 -m unittest discover Docs/Analysis/tests
python3 Docs/Analysis/analyze_swifttag_project.py \
  --repo-root . --output Docs/Analysis/output
python3 Docs/Analysis/analyze_swifttag_project.py \
  --repo-root . --output Docs/Analysis/output \
  --require-reviewed-associations
```

For determinism, run final command twice. Compare analytical data and SVG files
byte-for-byte. Compare stable `run_metadata.json` fields separately because run
timestamp, current HEAD, dirty status, Python runtime, and command arguments are
documented volatile fields. Internal-link validation runs during every final
generation.
