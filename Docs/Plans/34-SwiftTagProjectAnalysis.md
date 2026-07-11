# SwiftTag Project Analysis Plan

## Goal

Refactor current project-analysis generator so report is driven by plan and
conversation-transcript evidence, every Commit represents exactly one git
commit, and Plans become first-class analytical categories comparable to
Themes.

Generated report must explain:

- how visible conversation time is allocated to individual commits
- how commits and transcripts relate to numbered Plans
- relative Commit difficulty
- relative Plan difficulty
- Theme membership without synthetic plan or transcript Commits
- confidence, exclusions, and manual decisions behind every association

## Plan Status

- Plan 34 is current implementation-driving plan under AGENTS.md.
- Prior Open Questions are resolved and answers are in Confirmed Decisions.
- Implementation must follow phases, tests, acceptance criteria, and review
  gates below.

## Scope

### In Scope

- Update existing Python generator in
  Docs/Analysis/analyze_swifttag_project.py.
- Update existing JSON configuration under Docs/Analysis/config.
- Update parser and report tests in
  Docs/Analysis/tests/test_analysis_parsers.py.
- Limit report commit population to closed inclusive ancestry range from
  2c8445cbde7892ceff58fb58780a79278bcf7d6e through
  1071c2e0ffd3bbc279f2cca6e15509e725518e25.
- Exclude Docs/Plans/34-SwiftTagProjectAnalysis.md from every report input,
  record, relationship, metric, page, chart, count, and dirty-file listing.
- Generate one Commit record for every commit in configured report range.
- Use canonical full git hash as Commit identity.
- Treat commit subject as Commit display name.
- Treat Plans as separate records with their own:
  - linked commits and commits
  - linked transcripts
  - revision history
  - time allocation
  - difficulty inputs, score, and label
  - Themes
  - confidence and warnings
- Parse transcript headers, turns, content, file history, plan history, and git
  messages to associate transcripts with Commits and Plans.
- Generate deterministic transcript-review packets containing parsed segments,
  structural evidence, and candidate Commit/Plan associations.
- Use development-time agent review, guided by this Plan, for semantic transcript
  attribution and ambiguous weighting decisions.
- Store agent-reviewed decisions in checked-in version-2 configuration under
  Docs/Analysis/config before final report generation.
- Support many-to-many Commit, Plan, Transcript, and Theme relationships.
- Preserve explicit manual include, exclude, replacement, and allocation
  decisions.
- Add linked associated-Plan output to Commits page.
- Preserve and verify existing transcript-without-timestamps notes behavior.
- Preserve current difficulty signals and configurable weighting approach while
  calculating Commit and Plan scores in separate cohorts.
- Regenerate static HTML, CSV, JSON, SVG, source mirrors, notes, warnings, and
  review packets under Docs/Analysis/output.

### Out Of Scope

- Changing SwiftTag app behavior or Swift source.
- Editing historical plans, transcripts, or git commits.
- Rewriting commit messages.
- Inventing elapsed time for transcripts without usable timestamps.
- Treating transcript archive commit as work commit solely because it added
  transcript file.
- Splitting one git commit into multiple Commit records.
- Combining Commit, Plan, and Theme rollups into one additive project total.
- Network services or hosted chart libraries.
- Runtime agent spawning, model API calls, or network-based semantic analysis
  from report generator.
- Hard-coding transcript-specific semantic decisions in Python generator when
  decision belongs in reviewed configuration.
- FLAC fixture processing.

## Plan Input Checklist Coverage

- Latest numbered plan reviewed:
  - Docs/Plans/33-AddTrackFileRename.md
- Relevant guides reviewed:
  - AGENTS.md
  - Docs/Guides/git-commit-message-guide.md
  - Docs/Guides/testing-guide.md
  - Docs/Guides/transcript-template.md
- Current implementation reviewed:
  - Docs/Analysis/analyze_swifttag_project.py
  - Docs/Analysis/README.md
  - Docs/Analysis/config/difficulty_weights.json
  - Docs/Analysis/config/feature_aliases.json
  - Docs/Analysis/config/feature_themes.json
  - Docs/Analysis/config/manual_links.json
  - Docs/Analysis/tests/test_analysis_parsers.py
  - current generated output under Docs/Analysis/output
- Relevant transcript patterns reviewed:
  - timestamped and untimestamped turns
  - transcript committed with implementation
  - transcript committed after implementation
  - one transcript referencing multiple Plans
  - plan-number and filename mismatches
  - versioned plan families
  - old Conversation Transcript heading variants
  - CR-heavy and zero-width-character input
  - one transcript covering multiple implementation commits
- Relevant git-history patterns reviewed:
  - conventional and non-conventional subjects
  - breaking-change marker in subject
  - multiple conventional-looking sections in one commit message
  - commit adding plan and code together
  - commits updating a plan during implementation
  - archive commit adding several older transcripts
  - renamed plan and transcript paths
- Fixture applicability:
  - No FLAC import or writeback occurs.
  - SwiftTagTestFiles fixtures are not required.

## Current Implementation Snapshot

- Analyzer currently parses plans, transcripts, user documentation, git
  history, timing, Themes, difficulty, notes, and static output.
- Current configured report range contains 208 commits but produces 174
  Commits.
- Current cross-reference engine seeds a Commit from every plan family.
- Transcript filename clusters can create Commits.
- Commits can be assigned to shared aggregate Commits.
- Thirteen current Commits contain multiple commits.
- Six current Commits contain no commit.
- Two commits currently map to two Commits.
- Current Plans are passive source records:
  - related_transcript_ids and related_commit_ids are not populated
  - no analytical plan detail pages exist
  - no Plan difficulty is calculated
- Current features.html Plans column displays count, not associated Plan links.
- Current transcript allocation applies one scalar to whole transcript.
- Turn records expose linked_feature_id but parser does not populate it.
- Current transcript-file change evidence can wrongly give archived
  conversation time to archive commit.
- Current analyzer has no explicit two-pass agent-review boundary; it mixes
  deterministic inference and reviewed overrides.
- Current implementation already provides:
  - transcripts-without-timestamps-notes.html
  - feature Notes links for known untimestamped transcripts
  - Project Theme configuration
  - supplied AppleScript manual mappings and allocation weights
  - positive and negative Theme overrides
- This work is migration of existing analyzer, not greenfield implementation.

## Confirmed Decisions

- Report commit range starts with initial commit
  2c8445cbde7892ceff58fb58780a79278bcf7d6e and ends with commit
  1071c2e0ffd3bbc279f2cca6e15509e725518e25, inclusive.
- Never derive report range from HEAD, current branch tip, current date, or
  commits added after fixed end commit.
- Any commit following fixed end commit, or dated after its author or committer
  timestamp, is out of range and must not appear in report commit data,
  relationships, metrics, Themes, charts, or totals.
- Every in-range git commit creates exactly one Commit, including docs, test,
  project, build, plan-only, and transcript-only commits.
- Commit id is canonical full git hash.
- Short hash must resolve uniquely and is used for Commit detail filenames.
- Commit display name is primary git subject exactly as stored.
- Report-facing entity name is Commit. Do not emit a separate legacy analytical
  concept or navigation entry, features.html, or features directory.
- commits.html is the only Commit index. It replaces the prior features.html
  analysis and prior raw commits.html listing.
- Commit detail pages replace raw commit source mirrors under
  sources/commits/<short-hash>.html. Full hash remains canonical identity in
  page content, configuration, relationships, and data.
- commits.html rows sort by author date ascending, then full hash for stable
  ordering. Columns are Hash, Date, Subject, Themes, Difficulty, Code,
  Transcript Lines, Elapsed, Plans, Transcripts, Tests, and Docs.
- plans.html includes First Evidence and Last Evidence as final columns instead
  of Warnings.
- Do not generate timelines.html or a Timelines navigation entry. Plan evidence
  dates live on plans.html; response-times.html retains Plan allocation view.
- Checked-in schema-v2 feature_allocations and
  feature_unallocated_remainder keys remain unchanged for reviewed-config and
  digest compatibility. Generated pages, exports, review guidance, and labels
  call this analytical lens Commit.
- Conventional-looking sections in commit body remain evidence and aliases;
  they never create extra Commits.
- Non-conventional historical subject still creates one Commit with unparsed
  type/scope and warning.
- Plans and transcripts never create Commits.
- Plans are first-class category parallel to Themes.
- Plan category identity is numeric Plan order. Explicit version variants with
  same numeric order, such as Plan 11 v1-v4, share one Plan family category
  while preserving each version as source and revision evidence.
- Repeated slug under different numbers remains separate Plan categories. Plans
  19, 20, and 22 do not collapse merely because all use
  AddSwiftTagDocumentSaveOptions slug.
- Plan 34 is implementation guidance for report generator, not report evidence.
  Exclude exact normalized path Docs/Plans/34-SwiftTagProjectAnalysis.md from
  Plan discovery and all generated report data and presentation.
- Commit changing or creating a Plan remains its normal commit and also
  gains Plan association.
- One transcript can associate with multiple Commits and Plans.
- One Commit can associate with multiple Plans.
- One Plan can associate with multiple commits, Commits, transcripts, and
  Themes.
- Transcript archive provenance and transcript work attribution are separate
  relationships.
- Transcript addition commit is not automatically owner of conversation
  metrics.
- Transcript segments or turns are preferred allocation unit.
- Deterministic generator owns extraction, timestamps, line counts, exact
  structural relationships, candidate scoring, validation, metric calculation,
  and report rendering.
- Development-time agent owns semantic decisions that require reading meaning:
  commit ownership, Plan ownership, direct-versus-implementation role,
  accepted segment boundaries when defaults are insufficient, and ambiguous
  allocation decisions.
- Agent review happens outside report process. Generator never spawns an agent,
  imports model SDK, calls model API, or requires network.
- Agent-reviewed configuration is semantic source of truth. Generator code
  contains reusable algorithms/schema only, not project-history decisions.
- Generator computes metric weights from reviewed segment line ranges and
  parsed timing intervals. Agent provides whole-transcript numeric percentages
  only when semantic work cannot be separated into segments.
- New, missing, stale, or invalid semantic review stays excluded from totals and
  emits review warning until config is updated.
- Whole-transcript percentages remain supported when turn-level separation is
  impossible.
- Accepted Commit shares plus explicit unallocated remainder equal 1.0 for
  each transcript metric.
- Accepted Plan shares plus explicit unallocated remainder equal 1.0 within
  separate Plan analytical lens.
- Plan and Commit views are alternative analytical lenses. Their totals must
  never be added together as independent work.
- Plan metrics distinguish direct plan-authoring work from associated
  implementation rollup.
- Current difficulty weight names and values remain baseline.
- Commit and Plan percentile normalization runs separately.
- Commit Plan-line signal uses Plan file line changes in that commit, not full
  current Plan length repeated across every associated Commit.
- Plan direct line signal uses current Plan source lines; revision churn is
  reported separately.
- Known untimestamped transcripts remain countable conversation with timing
  unavailable.
- Reviewed manual overrides outrank automatic inference.
- Explicit negative Theme links outrank keyword/path inference.
- Existing Project Theme remains required and receives commit-Commit and Plan
  memberships after migration.
- Preserve every current Theme: Picture, SwiftTag Document, Diff, AppleScript,
  Tags, Save, Settings, User Docs, Project, and FLAC Lib.
- Every commit should have at least one accepted Theme. When no Theme
  can be determined confidently, leave Commit unassigned rather than forcing
  false membership and emit missing_theme_assignment warning for review.
- Plan 26 uses direct-only interpretation: direct Plan-authoring metrics retain
  commit 192eaacabaecbe09ee3ee59d935f0d3ab2d86a02 and direct share of
  transcript-2026-04-18-1-26-AddAppleScriptSupport. Later AppleScript commit
  Commits and transcript segments may link Plan 26 with implementation or
  plan-revision roles. Old synthetic Add AppleScript Support Plan Commit is
  retired.
- Commit 5866685bcbe463804d3efa4fb258029bf961207a associates with
  transcript-2026-04-21-1-26-AddAppleScriptSupport.
- Commit 859a8f570b718d332f3f3814fc621280ae0f077e has confirmed nonexclusive
  membership association with
  transcript-2026-04-22-1-26-AddAppleScriptSupport.
- Commit 0c2d38575541a8dada750da08698d78e75a4d3f0 is archive provenance for
  both preceding transcript files because it adds both files. Archive
  provenance does not assign work-time ownership by itself.
- Transcript contents must still be parsed to discover other commit/Plan edges
  and determine allocation weights; explicit association does not imply full
  transcript allocation.
- Matplotlib is required for all chart generation. Do not use optional custom
  SVG chart fallback.
- Matplotlib charts use 11-point base text, 10-point x-axis tick labels,
  9-point bar-category/value labels, and 7-point matrix y-axis labels.
- warnings.html Source cells link to generated source/detail pages when target
  resolves. Non-page sources remain plain text.
- Duplicate override entries resolve by canonical identity and emit at most one
  relationship.
- Existing output is generated data and is replaced from clean model on every
  run.
- Missing timing is stored as null, not displayed as zero. To preserve current
  weighting behavior, scoring projects unavailable signal to zero percentile
  contribution, keeps original configured weights without per-record
  renormalization, and reports original-weight coverage as confidence.

## Dependencies And Constraints

### Product And Data Constraints

- Local git history is authoritative for commit identity, message, dates, and
  changed paths.
- Transcript visible content is authoritative for conversation subject and
  timing.
- Transcript export date can differ from commit date.
- Transcript may be committed at same time as or after associated Plan/code
  commits.
- Historical paths and headers contain typos and inconsistent naming.
- Manual mappings supplied for earlier aggregate model must migrate without
  recreating aggregate Commits.
- Report commit range is immutable for this report: closed inclusive ancestry
  range 2c8445cbde7892ceff58fb58780a79278bcf7d6e through
  1071c2e0ffd3bbc279f2cca6e15509e725518e25.
- Resolve both boundary hashes and require start to be ancestor of end. Treat
  missing, ambiguous, reversed, or unreachable boundaries as fatal errors.
- Current Plan and transcript source files may provide evidence for in-range
  commits, but references to out-of-range commits cannot create Commits or
  contribute report relationships, metrics, Themes, charts, or totals.
- Source plans and transcripts must remain unmodified.
- Semantic review is repository-maintenance work performed before final report
  run, not dynamic report dependency.
- Reviewed association entry must include review-input digest over normalized
  transcript, referenced Plan sources, candidate commit evidence, and review
  method version so changed evidence invalidates stale semantic decision.

### Tooling, Environment, And Filesystem Constraints

- Generator remains runnable with local Python command documented in README.
- Network access is not required.
- Python standard library remains sufficient for parsing and HTML.
- Matplotlib is required for chart generation. README must document supported
  version/environment and dependency check.
- Current inspected environment provides Matplotlib 3.11.0; record runtime
  version in run metadata and document 3.11.0 as tested baseline.
- Missing Matplotlib is fatal with actionable installation/runtime error; no
  handwritten SVG fallback is allowed.
- Set MPLCONFIGDIR and XDG_CACHE_HOME to deterministic writable analysis/tmp
  paths before importing Matplotlib.
- Use fixed noninteractive backend, style, fonts, SVG hash salt, and normalized
  metadata so Matplotlib output remains deterministic.
- Git rename history and short-hash resolution must use local repository.
- Generated output cleanup must not delete config, tests, source plans, or
  source transcripts.
- Dirty worktree metadata must exclude exact normalized path
  Docs/Plans/34-SwiftTagProjectAnalysis.md so control Plan cannot leak into
  report through repository-state metadata.
- Retire obsolete exclusion for Docs/Plans/_SwiftTagProjectAnalysis.md during
  configuration migration and replace it with exact Plan 34 path.
- Xcode, ViewInspector, and XCUI are not applicable to this Python report
  generator.
- Final report command must work offline from repository inputs and checked-in
  configuration.

## High-Risk Implementation Concerns

### Product And Behavioral Risks

- Synthetic Plan/Transcript Commits survive migration and duplicate commits.
- One commit with multi-subject body becomes multiple Commits.
- Broad transcript Plan reference assigns all later work to Plan record.
- Transcript archived later assigns conversation time to unrelated archive
  commit.
- Whole transcript time is duplicated across several commits.
- Plan and Commit totals are added, inflating project time.
- Full Plan line count is copied into every linked Commit difficulty score.
- Legacy aggregate Theme membership leaks unrelated Themes to every commit in
  cluster.
- Low-confidence filename matching overrides stronger header or git evidence.
- Deterministic candidate inference is mistaken for semantic review and enters
  totals without agent acceptance.
- Agent-reviewed decisions are hard-coded in generator, making history changes
  require code edits.
- Report run silently spawns agent or calls model/network, breaking
  reproducibility and offline use.
- Transcript changes after review but stale config still contributes metrics.
- Manual negative Theme links are lost during automatic reclassification.
- Commit remains without Theme and no review warning is generated.
- Uncertain commit is forced into Project or another Theme without evidence.
- Old slug-backed Commit URLs remain and misrepresent new model.

### Tooling, Environment, And Filesystem Risks

- Short hash is ambiguous.
- Plan or transcript path changed through rename syntax in git log.
- File has .md.md suffix while header names .md.
- Plan 31 transcript names old/nonexistent Plan filename.
- Zero-width characters in historical subjects break matching.
- Duplicate manual entry creates duplicate relationship.
- Generated output retains stale pages after schema change.
- Matplotlib fallback or volatile SVG metadata makes chart output differ across
  identical runs.
- Current untracked/generated analysis workspace contains user work and must not
  be removed outside generated output paths.
- Full repository regeneration can expose malformed historical input; warnings
  must not become crashes.

## Destructive And Write-Back Behavior

- Preserve:
  - all source Plans
  - all source transcripts
  - git history
  - accepted manual overrides
  - difficulty weights
  - reviewed Theme definitions
- Agent may update:
  - reviewed semantic association config
  - allocation overrides and evidence notes
  - accepted/rejected candidate state
- Generator must never update config. It only reads, validates, and reports
  config state.
- Replace on regeneration:
  - Docs/Analysis/output HTML
  - Docs/Analysis/output data files
  - Docs/Analysis/output charts
  - Docs/Analysis/output source mirrors
  - Docs/Analysis/output review packets
- Remove stale generated Commit and Plan detail pages not present in new run.
- Do not remove or rewrite config entries silently.
- Invalid or conflicting config entry produces warning and remains reviewable.
- Legacy generated URLs may receive redirect pages only if generator can do so
  deterministically; otherwise remove and report migration in run metadata.
- Partial-save and UI selection semantics do not apply.

## Proposed Output Layout

    Docs/Analysis/
      analyze_swifttag_project.py
      README.md
      config/
        difficulty_weights.json
        feature_aliases.json
        feature_themes.json
        manual_links.json
      tests/
        test_analysis_parsers.py
        fixtures/
          manual-association-expectations.json
      output/
        index.html
        commits.html
        themes.html
        plans.html
        response-times.html
        difficulty.html
        charts.html
        transcripts.html
        warnings.html
        transcripts-without-timestamps-notes.html
        early-commits-contribution-notes.html
        plans/
          <plan-family-id>.html
        themes/
          <theme-id>.html
        charts/
        review-packets/
          transcripts/
            <transcript-id>.md
            <transcript-id>.json
          themes/
            <theme-id>.md
            <theme-id>.json
        sources/
          plans/
          transcripts/
          commits/
            <short-hash>.html
          user-documentation/
        data/
          commits.csv
          plans.csv
          plan_revisions.csv
          transcripts.csv
          turns.csv
          transcript_segments.csv
          segment_allocations.csv
          semantic_review_status.csv
          commit_files.csv
          commit_references.csv
          plan_references.csv
          commit_plan_references.csv
          theme_references.csv
          theme_coverage.csv
          relationships.csv
          themes.csv
          user_documentation.csv
          metrics.json
          warnings.csv
          run_metadata.json

## Data Model

### Commit Record

- commit hash: canonical full commit hash
- short hash
- display name from primary subject
- exact subject and body
- conventional type, scope, breaking marker, and description
- conventional parse status
- aliases and body-subject evidence
- author and committer dates
- changed paths
- code, test, documentation, Plan, transcript, fixture, and binary line counts
- exactly one linked commit hash, equal to commit hash
- associated Plan ids
- associated transcript ids
- parent Theme ids
- Theme coverage state and missing_theme_assignment warning id, when unassigned
- transcript segment allocations
- allocated transcript lines and turn counts
- allocated visible elapsed time
- allocated Assistant processing time
- allocated User response time
- allocated back-and-forth count
- Commit difficulty inputs, score, and label
- association confidence
- warnings
- first and last evidence dates

Invariant:

- number of Commits equals number of in-range commits
- every Commit has one commit
- every commit has one Commit

### Commit Source Record

- canonical full and short hash
- author and committer dates
- exact subject/body and parsed conventional metadata
- changed files, rename status, and numstat
- path classifications and binary flags
- sole linked Commit id, equal to full hash
- associated Plan, transcript-provenance, and warning edges

Commit record remains raw git/source view. Commit record is one-to-one
analytical view layered on it.

### Plan Record

- stable family id
- display title
- numeric order
- versioned source Plan ids and paths
- current source path
- source line count
- revision line additions/deletions
- section names and source anchors
- creation commit
- Plan revision commits
- associated implementation commits and commits
- transcript archive commits
- direct Plan-work transcript segments
- implementation transcript segments
- parent Theme ids
- relationship roles and evidence
- direct Plan lines, transcript lines, timing, and back-and-forth
- associated implementation code, test, and documentation lines
- allocated rollup metrics
- Plan difficulty inputs, score, and label
- first and last evidence dates
- confidence and warnings

Plan-to-commit role values:

- creation
- version-addition
- plan-revision
- implementation
- transcript-archive

One Plan/commit edge may carry several roles.
Manual is relationship evidence/override state, not semantic Plan role.

### Transcript Record

- transcript id and exact path
- normalized lookup aliases
- export date
- reference type
- raw and normalized References
- exact referenced Plan ids
- agent
- line and turn counts
- User and Assistant turn counts
- first and last timestamp
- visible elapsed time when calculable
- warning and documented-warning counts
- archive commit ids
- associated Commit ids
- associated Plan ids
- allocation status and total
- semantic review status: reviewed, unreviewed, stale, or invalid
- transcript normalized-content digest used by review config
- review-input digest used for staleness validation

### Turn And Transcript Segment Records

- transcript id
- turn/segment id and source line range
- speaker
- timestamps and completion timestamps
- body line count
- Assistant processing duration
- User response duration
- Commit allocation weights
- Plan allocation weights
- classification evidence
- confidence
- reviewed/candidate/structural source
- review status and reviewed config entry id
- interrupted marker

One turn may have several weighted associations. Do not store only one
linked_feature_id.

### Relationship Records

Every relationship stores:

- left entity type and id
- right entity type and id
- role
- evidence type
- evidence source and source line
- confidence
- allocation weight
- included-in-direct-totals flag
- included-in-rollup-totals flag
- manual override state
- reviewed_by, reviewed_at, review_method, evidence note, and source digest
- warning state

relationships.csv stores one edge per row. segment_allocations.csv stores one
transcript-segment/entity allocation per row. CSV must not serialize multiple
weighted associations into one list-valued cell.

### Theme Record

- stable Theme id and display name
- description, aliases, keywords, and documentation paths
- child commit-Commit ids
- child Plan ids
- direct and inherited metrics
- shared allocation metrics
- explicit include and exclude evidence
- difficulty summaries for Commits and Plans
- confidence and warnings
- configured definition preservation status
- commit-Commit count, unthemed count, and coverage percentage

Theme records are configuration-driven. Every configured Theme produces data,
HTML, review packet, metrics, and chart presence even when metrics are zero.

## Commit Generation

1. Resolve fixed start and end hashes and validate closed ancestry range.
2. Enumerate start commit plus commits in start..end ancestry path. Include both
   boundaries and never traverse descendants of end or substitute HEAD.
3. Exclude any candidate whose author or committer timestamp is later than end
   commit timestamp and emit fatal range-integrity error if such candidate was
   otherwise inside resolved ancestry range.
4. Canonicalize every included commit to full hash.
5. Create one Commit immediately for every included commit.
6. Parse only primary subject for Commit name/type/scope.
7. Parse optional scope, exclamation breaking marker, and case-insensitive
   conventional units.
8. Parse BREAKING CHANGE and BREAKING-CHANGE footers as metadata.
9. Preserve primary subject Unicode and spelling exactly for display.
10. Normalize only matching keys.
11. Extract conventional-looking body sections as aliases/evidence.
12. Never create Commit while parsing Plans or transcripts.
13. Deduplicate manual references by resolved full hash.
14. Warn and reject ambiguous or missing short hashes.
15. Reject every manual or inferred relationship whose commit is outside fixed
    range; do not materialize partial out-of-range records.
16. Fail analysis integrity check if configured range commit cannot produce
    Commit; do not warn-and-skip malformed commit metadata.

## Plan Processing And Revision History

### Discovery

1. Enumerate Docs/Plans/*.md.
2. Exclude exact normalized path Docs/Plans/34-SwiftTagProjectAnalysis.md before
   creating Plan records, lookup keys, relationships, review evidence, or
   metrics. This explicit control-Plan exclusion overrides numbered-Plan
   classification.
3. Group only same-number explicit version variants into Plan family.
4. Keep same-slug different-number Plans as distinct categories.
5. Select highest accepted explicit version as current source for versioned
   family. For unversioned family use surviving path; if several survive, use
   latest ancestry content revision and warn.
6. Preserve each source file/version as revision source.
7. Build lookup keys from exact path, basename, stem, number, slug, historical
   rename paths, and normalized .md.md alias.

### Git History

1. Find commits adding or modifying each Plan path.
2. Expand git rename notation.
3. Ignore pure rename entry with zero additions/deletions as content revision.
4. Across all files in family, classify earliest ancestry/topological accepted
   status A content addition as family creation.
5. Classify later version-file status A additions as version-addition plus
   plan-revision, not another family creation.
6. When status A is unavailable, use earliest ancestry/topological nonzero
   content commit and emit fallback warning. Do not use author-date sort or
   current git-log list order.
7. Classify later content changes as plan-revision.
8. Create implementation-role candidate when non-Plan code/test/docs and
   transcript evidence indicate Plan implementation. Agent review accepts
   semantic implementation role. Creation or plan-revision and implementation
   roles may coexist on same edge.
9. Keep same commit identity; Plan relation is edge, not Commit.
10. Associate implementation commits through transcript/commit evidence even
   when they do not touch Plan file.

### Plan Metrics

- Direct metrics:
  - current Plan source lines
  - revision churn
  - Plan-authoring transcript segments
  - Plan creation/revision documentation changes
- Implementation rollup:
  - associated commit-Commit code/test/docs
  - implementation transcript segments
- Show direct and rollup separately.
- Plan file additions/deletions remain direct Plan evidence even when commit
  also implements code.
- Agent review classifies transcript segment as direct Plan work when
  request/response creates, reviews, clarifies, or updates Plan content, and as
  implementation when request/response changes or verifies product/report code.
- Generator applies reviewed role; it does not decide semantic role from text.
- Mixed transcript can contain both segment roles.
- For plan-wide totals, reviewed allocation wins. Without reviewed allocation,
  divide accepted shared commit/transcript metric equally by accepted Plan
  count. With no accepted Plan, keep full share unallocated.

## Agent Review Architecture

### Responsibility Boundary

Report generator performs only deterministic local operations:

- discover and parse Plans, transcripts, commits, and source paths
- split turns into deterministic base segments
- parse timestamps and calculate atomic timing intervals
- create exact structural edges:
  - commit identity and changed files
  - transcript archive provenance
  - exact transcript References to Plans
  - Plan creation/revision history
- score candidate semantic relationships from local evidence
- emit transcript review packets
- validate checked-in reviewed config
- calculate weights from reviewed segments
- generate reports, charts, warnings, and data

Development-time agent performs semantic review outside generator:

- read transcript segment meaning
- compare transcript with commit subjects/bodies/changed paths and Plan content
- accept or reject candidate commit and Plan relationships
- assign semantic role such as direct Plan work or implementation
- adjust segment boundaries only when deterministic base segment is insufficient
- record membership-only, work, provenance, and excluded relationships
- explain unallocated remainder
- write reviewed decisions into version-2 config

Generator must not:

- spawn sub-agent or other agent process
- call model API or import model SDK
- access network for semantic classification
- modify reviewed config
- automatically promote semantic-only candidates into totals
- contain project-specific transcript decisions in Python source

### Two-Pass Workflow

1. Run deterministic review-packet pass:

       python3 Docs/Analysis/analyze_swifttag_project.py \
         --repo-root . \
         --output Docs/Analysis/output \
         --review-only

2. Development-time agent reads this Plan, transcript packets, linked source
   evidence, current config, Plans, and commits.
3. Agent writes accepted/rejected associations, segment ownership, roles, and
   evidence into checked-in version-2 config.
4. Run deterministic final report:

       python3 Docs/Analysis/analyze_swifttag_project.py \
         --repo-root . \
         --output Docs/Analysis/output

5. Verification/release run requires every semantic association needed by
   totals to be reviewed:

       python3 Docs/Analysis/analyze_swifttag_project.py \
         --repo-root . \
         --output Docs/Analysis/output \
         --require-reviewed-associations

Normal final run may render incomplete report with warnings. Required-review
run fails when semantic review is missing, stale, or invalid.

### Transcript Review Packet

Each transcript packet contains:

- transcript id, path, normalized-content digest, review-input digest, and
  source line anchors
- header metadata, References, and archive-provenance commits
- deterministic User-plus-following-Assistant base segments
- parsed timing intervals and count metrics
- candidate commits with full hash, subject/body, changed paths, numstat, and
  source links
- candidate Plans with titles, sections, revision roles, and source links
- candidate Themes and current accepted/excluded relationships
- evidence scores and reasons
- existing reviewed config entries
- conservation preview for lines, time, and back-and-forth
- unresolved questions and unallocated remainder

### Agent Review Output

For each reviewed transcript, config records:

- normalized-content digest
- review-input digest
- review status and review provenance
- accepted/rejected candidate ids
- segment ids and exact source line ranges
- commit full hashes
- Plan family ids
- relationship role and membership/work/provenance distinction
- included-in-direct and included-in-rollup flags
- evidence note
- unallocated remainder and reason
- whole-transcript percentages only when segment separation is impossible

Store review conclusions and concise source-backed evidence, not hidden agent
reasoning or chain-of-thought.

Generator derives metric-specific line/time/count weights from reviewed segment
ranges. One scalar must not replace segment-derived metrics when parsed timing
and lines support separate allocations.

### Review Invalidation And Warnings

- semantic_review_required: no accepted review exists for semantic work needed
  by totals
- semantic_review_stale: transcript or review-input digest differs from reviewed
  config
- semantic_review_invalid: config references missing hash, Plan, segment, line
  range, or violates conservation
- semantic_review_unallocated: reviewed transcript retains explained remainder

Unreviewed, stale, or invalid semantic allocations stay out of totals. Exact
structural edges and raw source metrics remain visible.

## Transcript-Driven Association Methodology

### Core Chronology Rule

Transcript is visible-work evidence, not commit-time clock.

- Associated implementation commit may precede transcript archive commit.
- Same commit may contain code, Plan, and transcript.
- Plan may be created before transcript archive.
- Plan may be updated by later implementation commits.
- Archive commit may add several old transcripts and unrelated code.
- Archive provenance never assigns conversation timing by itself.

### Candidate Evidence Order

1. Checked-in agent-reviewed association.
2. Explicit full or uniquely resolved short commit hash in transcript.
3. Exact Plan path in transcript References.
4. Exact Plan/transcript path changed by commit, combined with matching commit
   subject/body or non-document changed paths.
5. Commit and transcript co-occurrence with matching subject and session date.
6. Plan revision history during transcript work.
7. Exact commit subject or distinctive body phrase in transcript.
8. Plan number/family and normalized slug.
9. Changed-path and transcript-topic overlap.
10. Directional date proximity, favoring work commit at or before transcript
    archive.
11. Weak keyword inference.

This order ranks review-packet candidates. No unreviewed semantic candidate,
regardless score, enters work allocations or difficulty totals. Exact structural
edges may enter structural reports without agent review, but never acquire
semantic work ownership from structure alone.

### Provenance Versus Work

- transcript-archive edge answers which commit added/changed transcript file.
- transcript-work edge answers which commit conversation describes.
- A docs(transcript) archive Commit can link transcript as provenance while
  receiving zero work-time allocation.
- Commit containing matching code plus transcript can receive both roles.

### Segment Allocation

1. Split transcript into turns.
2. Create deterministic base segment from each User turn plus every following
   Assistant turn until next User turn.
3. Do not auto-merge adjacent base segments. Agent may assign same owner and
   they aggregate naturally; reviewed config can group them for evidence
   display.
4. Leading Assistant content without User owner becomes orphan segment and
   remains unallocated until agent review resolves it.
5. Consecutive Assistant turns stay in current User segment. Consecutive User
   turns each start new base segment and preserve continuity warning.
6. Generator ranks candidate commits and Plans for each segment; agent
   review accepts/rejects owners and roles in config.
7. Use source line ranges for evidence.
8. Apply agent-reviewed segment ranges. Use reviewed percentage only when work
   cannot be separated by segment.
9. Require accepted Commit shares plus unallocated remainder to equal 1.0 for
   every count/time metric per transcript.
10. Require accepted Plan shares plus unallocated remainder to equal 1.0 within
   separate Plan analytical view.
11. Preserve raw membership even when allocated share is zero.
12. Record unallocated remainder and warning; never silently discard.
13. Allocate line counts and back-and-forth even when time is unavailable.
14. Assign Assistant processing interval to Assistant turn's topic segment.
15. Assign User response interval to preceding Assistant segment because
    interval measures time from that Assistant completion to next User turn.
16. Assign one User-to-Assistant back-and-forth pair to User request topic; if
    paired turns classify differently, keep User topic and emit boundary
    warning.
17. Allocate transcript header/note lines proportionally across accepted
    segments and unallocated remainder so transcript lines reconcile to source
    line count.
18. Build visible elapsed allocation from valid atomic Assistant and User
    intervals; do not multiply whole-transcript span by topic percentage.
19. Conservation tests compare allocated plus unallocated line counts,
    Assistant intervals, User-response intervals, and back-and-forth against
    parsed valid atomic totals. Difference between atomic timing and transcript
    wall span remains explicit unavailable/idle timing, never fabricated.

## Commit-To-Plan Association

Commit receives associated Plan link when:

- commit creates or modifies Plan
- commit message names Plan path/title/number
- allocated transcript segment references Plan
- transcript and Plan revision evidence jointly support relationship
- reviewed commit_plan link exists

Associated Plan column must show linked Plan names, not only count.
Links target analytical plans/<plan-family-id>.html pages; those pages link
line-anchored source mirrors.

Confirmed Plan 26 direct-only handling:

- commit 192eaacabaecbe09ee3ee59d935f0d3ab2d86a02 and planning share of
  transcript-2026-04-18-1-26-AddAppleScriptSupport are direct Plan-work
  evidence
- commit 777706cf1432bcd9bbd0ff1d145469d038b76fd3 and its transcript share are
  implementation evidence
- later Plan 26 implementation commits/transcripts use implementation or
  plan-revision roles
- direct Plan totals do not absorb every transcript merely because header
  references Plan 26
- Commit lens allocates 2026-04-18 planning segment to commit 192eaac
  and implementation segment to commit 777706c
- Plan lens may allocate both segments to Plan 26, labeling first direct and
  second implementation; Commit and Plan allocations normalize independently

## Reviewed Association Configuration And Migration

Use Docs/Analysis/config/manual_links.json schema version 2 as checked-in source
of reviewed semantic associations. Name remains for compatibility; contents may
come from development-time agent review or explicit user decision. Migrate
existing aggregate-oriented config to stable entity keys:

- commit_transcripts keyed by full commit hash
- commit_plans keyed by full commit hash
- plan_transcripts keyed by Plan family id
- theme_commits keyed by Theme id and full hash
- theme_plans keyed by Theme id and Plan family id
- commit_aliases keyed by full hash
- documented_untimestamped_transcripts keyed by exact path
- exclusive_transcript_work_commits keyed by transcript id
- exclusive_commit_work_transcripts keyed by full commit hash
- exclusive_commit_plans keyed by full commit hash
- exclusive_plan_direct_commits and exclusive_plan_direct_transcripts keyed by
  Plan family id
- explicit include, exclude, and exact-pair replace forms

Schema version 2 requirements:

- top-level schema_version equals 2
- top-level review_method_version identifies review rubric/schema
- commit_transcripts maps full hash to edge objects containing transcript_id,
  optional segment ids/source ranges, role, allocation_weight, evidence note,
  replace_inferred, included_in_totals, transcript digest, review-input digest,
  review status,
  reviewed_by, and reviewed_at
- commit_plans maps full hash to edge objects containing Plan family id, one or
  more roles, allocation_weight, evidence note, and replace_inferred
- plan_transcripts maps Plan family id to edge objects containing transcript id,
  segment ids/source ranges, direct-or-implementation role, allocation_weight,
  and replace_inferred
- theme_commits and theme_plans store explicit include and exclude ids
- commit_aliases stores display-independent matching aliases only
- documented_untimestamped_transcripts stores exact source path plus logical id
- transcript_reviews stores transcript digest, review-input digest, review
  status, reviewed base segment ids/ranges, accepted/rejected candidates,
  unallocated remainder, and review provenance
- exclusive_transcript_work_commits lists only commits allowed to own
  Commit-lens work metrics for named transcript
- exclusive_commit_work_transcripts lists only transcripts allowed to provide
  work metrics to named commit
- exclusive_commit_plans lists only candidate/reviewed Plan associations allowed
  for named commit while leaving Theme and transcript-provenance edges intact
- exclusive_plan_direct_commits and exclusive_plan_direct_transcripts constrain
  direct Plan-authoring lens only; later implementation/plan-revision edges
  remain eligible
- suppressed_warning_commit_ranges retains categories, canonical range bounds,
  and reason

Transcript work edge uses reviewed segment ids/ranges or whole-transcript
allocation_weight, never both. Whole-transcript weight requires explicit
cannot-segment reason. Membership-only/provenance edge sets included_in_totals
false and requires no weight.

Precedence:

1. explicit reviewed exclude
2. entity/source-scoped exclusive or replace_inferred rule
3. explicit agent/user-reviewed include and allocation
4. exact automatic structural evidence, structural role only
5. strong semantic candidate, excluded until reviewed
6. low-confidence semantic candidate, excluded until reviewed

replace_inferred on edge suppresses only same entity/source pair. Source-scoped
exclusive sets replace every inferred owner within named lens. Neither form
erases transcript archive provenance, another analytical lens, or unrelated
Theme relationship.

Migration rules:

- Legacy Commit mapped to one commit becomes alias/relationship bundle for
  that commit.
- Legacy Commit mapped to several commits expands to those commits.
- Legacy Plan Commit becomes Plan record relationship.
- Legacy transcript cluster with no commit cannot survive as Commit.
- Duplicate 9fea998 entry deduplicates.
- Conflicting manual labels for same commit become aliases, not Commits.
- Manual mismatch with actual git subject is honored as explicit relationship
  evidence but emits review warning.
- Existing allocation_weight values remain initial regression oracle.
- Existing explicit user/agent-reviewed overrides migrate with
  review_status=reviewed and legacy-review provenance. Old inferred links remain
  unreviewed candidates.
- Migrate all legacy keys: feature_definitions, feature_transcripts,
  feature_plans, feature_commits, feature_commit_ranges,
  replace_feature_transcripts, replace_feature_commits,
  exclusive_commit_feature_links, and suppressed_warning_commit_ranges.
- replace_feature_transcripts migrates to exclusive_commit_work_transcripts for
  resolved commit or exclusive_plan_direct_transcripts for legacy
  Plan-named Commit.
- replace_feature_commits migrates to exclusive_plan_direct_commits for legacy
  Plan-named Commit. For other aggregate Commits it freezes resolved commit
  set as migration evidence but creates no identity exclusivity in one-commit
  model.
- exclusive_commit_feature_links is obsolete for Commit identity. For each
  listed commit, migrate old manually accepted transcript and Plan sources to
  exclusive_commit_work_transcripts and exclusive_commit_plans; emit migration
  warning when old entry has no source constraint to preserve.
- Migrate Theme include/exclude feature ids, commit hashes, exact paths, and
  path prefixes without weakening explicit negative edges.
- Implement pure, idempotent schema-v1-to-v2 compatibility conversion in
  memory. It must never write config automatically.
- Update checked-in config to schema version 2 during implementation; version 2
  becomes authoritative after migration.
- Validate required fields, canonical hashes, Plan ids, allocation range, sum
  conservation, transcript/review-input digests, review status/provenance,
  valid segment ranges, segment-range versus scalar-weight exclusivity,
  cannot-segment reasons,
  and conflicting include/exclude entries before analysis.

## Required Conformance Baseline

All project-specific mappings and weights in this section seed checked-in
reviewed config and test fixtures. Do not hard-code them as conditional logic in
generator.

### Transcripts Without Timestamps

Treat these exact logical transcripts as countable conversation and unavailable
timing:

- Docs/Plans/Transcripts/transcript-2026-02-27-1-1-FLACBridgeExecution.md
- Docs/Plans/Transcripts/transcript-2026-03-02-1-MiscTagEditorDev.md
- Docs/Plans/Transcripts/transcript-2026-03-03-1-MiscTagEditorDev.md
- Docs/Plans/Transcripts/transcript-2026-03-04-1-2-ContentViewReorganizationPlan.md.md
- Docs/Plans/Transcripts/transcript-2026-03-06-1-4-FlacWriteTagsAndPicturesPlan.md
- Docs/Plans/Transcripts/transcript-2026-03-07-1-5-AddSaveNotificationsPlan.md
- Docs/Plans/Transcripts/transcript-2026-03-07-2-6-AgentsTranscriptSkillPlan.md
- Docs/Plans/Transcripts/transcript-2026-03-12-1-7-AddSaveStatusViewPlan.md

Requested logical ContentView transcript name ends in .md. Repository physical
path ends in .md.md. Config keys physical path and stores logical .md alias.
Logical alias is
Docs/Plans/Transcripts/transcript-2026-03-04-1-2-ContentViewReorganizationPlan.md.
Logical id is transcript-2026-03-04-1-2-ContentViewReorganizationPlan

For these transcripts:

- keep line, turn, speaker, and back-and-forth counts
- keep Commit, Plan, and Theme evidence
- exclude unavailable elapsed, Assistant, and User-response durations
- document expected warnings
- include them on transcripts-without-timestamps-notes.html
- link every associated Commit Notes section to that page

### AppleScript Commit And Transcript Associations

Existing reviewed allocation weights remain baseline. Development-time agent
uses transcript packets and this Plan to recompute segment evidence, then
updates config only when reviewed result supports change.

- 8053109fcb999ee4c2f8a060048b83dbfe4eed81:
  transcript-2026-05-20-1-MakePictureFix
- 83b8764ca1faecb6f984a4cf8703eaad75501f8a:
  transcript-2026-04-30-2-26-AddAppleScriptSupport
- 17b6c1045af4a5e5e2c465dded80f53ff5695df5 and
  1b08404c005806083a5443603d98c10c5510ee70:
  split transcript-2026-05-01-1-26-AddAppleScriptSupport
- 063c138d4ad746588a85c0be70cc1c5c75854e87:
  transcript-2026-05-02-1-26-AddAppleScriptSupport
- 7c15f6097d77ab2db98c6795b04474308f770536:
  transcript-2026-05-02-2-26-AddAppleScriptSupport
- d928e3bb438c8fa266b8700f3d4b2709c72bd7ee:
  transcript-2026-05-03-1-26-AddAppleScriptSupport
- 3fd6771aa6fbbc5afe81722f5d39ce0c171019cd:
  transcript-2026-05-03-2-26-AddAppleScriptSupport
- 2e24923ec49954fa4d4b17f56f3d26c10265a51b and
  43b64835145b64f3346d6298de67754019b36df8:
  split transcript-2026-05-04-1-26-AddAppleScriptSupport
- fc120558109cc0d36c1bee5ae25bce69d4702311,
  25fde2c3d0c01acd97eb967b5903f6336c57b6ae,
  94c83a7fe23cb17431994dd0f02d5f38c321630b, and
  77e0dc1182db2bdd7d3a4d09b5c1a7b3b912191b:
  split transcript-2026-05-07-1-26-AddAppleScriptSupport
- f19906905ecd5db8ea9d65fc0a6d80dbd0f798cb,
  82db5cd7599e76c1f0c6e8dda5f420865e32f4e7, and
  2976159836a41160b0a462b26c952968c19a7923:
  split transcript-2026-05-10-1-26-AddAppleScriptSupport
- 192eaacabaecbe09ee3ee59d935f0d3ab2d86a02 and
  777706cf1432bcd9bbd0ff1d145469d038b76fd3:
  split transcript-2026-04-18-1-26-AddAppleScriptSupport between direct Plan 26
  work and implementation Commit work
- bee209c217c6b5fa2c4eaddbddcab99101ee589a:
  transcript-2026-04-20-1-26-AddAppleScriptSupport
- bee209c217c6b5fa2c4eaddbddcab99101ee589a has no 2026-04-21 work edge
- 5866685bcbe463804d3efa4fb258029bf961207a has confirmed association with
  transcript-2026-04-21-1-26-AddAppleScriptSupport
- 859a8f570b718d332f3f3814fc621280ae0f077e has confirmed nonexclusive
  association with transcript-2026-04-22-1-26-AddAppleScriptSupport
- 0c2d38575541a8dada750da08698d78e75a4d3f0 has transcript-archive provenance
  edges to both 2026-04-21 and 2026-04-22 transcript files; those provenance
  edges receive zero automatic work allocation
- agent review of transcript content may add separate work edges to config,
  including 859a8f5 to 2026-04-21 fingerprint/audio segments and 0c2d385 to
  2026-04-22 tag-scripting segment
- confirmed association edges are membership evidence, not exclusive ownership;
  metric-specific weights come from parsed segments and must conserve source
  metrics

Content-derived 2026-04-21 regression fixture:

- lines 12-60 map to 5866685 stream-info work
- lines 61-97 and 98-116 map to 859a8f5 fingerprint/audio work
- header/note lines 1-11 and terminal line 117 distribute proportionally
- Assistant processing: 5866685 = 741 seconds; 859a8f5 = 573 seconds
- User response assigned to preceding work: 5866685 = 2,206 seconds;
  859a8f5 = 3,056 seconds
- back-and-forth: 5866685 = 1 pair; 859a8f5 = 2 pairs
- valid atomic elapsed: 5866685 = 2,947 seconds; 859a8f5 = 3,629 seconds

Content-derived 2026-04-22 regression fixture:

- lines 12-123 map to 0c2d385 tag-scripting work
- Assistant processing = 1,613 seconds
- 0c2d385 transcript-archive roles remain separate from this work edge
- 2298c43c00492de67ad920a395d3ec7a8c8fb722:
  transcript-2026-04-22-2-26-AddAppleScriptSupport
- d65459355d32c58116293e4f6cce8a759b6d67f5:
  transcript-2026-04-23-1-26-AddAppleScriptSupport
- 546e43d639eb9d7eceb46aa966b8a592b187b12c:
  transcript-2026-04-23-2-26-AddAppleScriptSupport
- c02d65544f4b09ec7b1fa8ca3e5e15204fdd1795 and
  95957dd6350042cf04715f42d75a708d22bd4af1:
  split transcript-2026-04-24-1-26-AddAppleScriptSupport
- 11ba78598b25840b5e415e7410b8df4b75c964c5:
  transcript-2026-04-28-1-26-AddAppleScriptSupport
- 6811df91487bd977d74d60b43af798e9970e5d69:
  transcript-2026-04-28-2-26-AddAppleScriptSupport
- 9b05c92e3f87af186de2ebdf43ebe8f297b41572:
  transcript-2026-04-29-1-26-AddAppleScriptSupport
- 46a24e9e98968ea9d3bfa50853be92e35d857f8e,
  bbb83ef00b9fb130f94ada7293ee1f429c6bf755, and
  24428a1548324e06268c9174e358e22e9559801b:
  split transcript-2026-04-29-2-26-AddAppleScriptSupport
- ce1865558f2929bb98bcf1450a297244be3fbb06 and
  987ade16137d70327f87ab16fcf3fc874681eba4:
  split transcript-2026-04-30-1-26-AddAppleScriptSupport
- 987ade16137d70327f87ab16fcf3fc874681eba4 also links
  Plan 27-TrackTagsRefactor

All user-supplied AppleScript mapping commits belong to AppleScript Theme
unless explicit additional Theme is stated. Commit 859a8f5 belongs to
AppleScript and FLAC Lib. Commit 5866685 does not inherit AppleScript solely
from transcript association; FLAC Lib and other evidence-based Themes may
apply. Additional required memberships:

- fingerprint/audio-property work: FLAC Lib
- 546e43d639eb9d7eceb46aa966b8a592b187b12c: Project
- fdd51810b0f51c7b8ee798ecfa0eb42453627946: AppleScript and Project
- d42524c80ead7c678062531b1a7e72fe58e29d72: AppleScript and Project

This includes 192eaacabaecbe09ee3ee59d935f0d3ab2d86a02 and
987ade16137d70327f87ab16fcf3fc874681eba4 as AppleScript commits.
Plan 26 also belongs to AppleScript Theme in Plan lens. Commit 0c2d385 belongs
to AppleScript through tag-scripting implementation evidence.

### Project Theme Membership

Project Theme must include commits for these canonical hashes:

- ae13badc1a2a880e7b374fa67010992d398fa737
- 4f2a9e8f1b624f200c4d62747f38f83200dbaf88
- 759876b5751c03c882cad89d885311f3073fe8cc
- f7f7e4be43044e840ea69ce6c03d1217b38913ad
- 05c75465e894b197009e4fa12fcee8a2f232be65
- c6c7c445aae308a598d41e9f839c9bfd0e495e88
- abe9194d5f3d791d34010e12ea51acb0054ae4ce
- c499b7aead381ce46c275a2b7e1571e2a49a4cc8
- 149bf183fe3edf4d14481d354a078cb50f628aee
- c0f71285faefcb501480a4ad69f63e5e7dc0df1e
- d42524c80ead7c678062531b1a7e72fe58e29d72
- e031a26f031d038fcc430fb7057600f67102ccbe
- 3c4cfff64ee127631152a551713977c1ad5a40dd
- fdd51810b0f51c7b8ee798ecfa0eb42453627946
- 07da732fae63f277c83cb54cf56698ac80e2c851
- 0015089006f52550ef2f4ed4fdd0057bb9e521b9
- 866d179e6bed7ea2133bcda6ef1ea9f2f91c5a15
- 65538b7f93d2246cfc37625f018af76640c6aa40
- 004751dd893b3e1b96ba2e42f9a63fc000d75663
- a28886ff5fcb92bf016b563a5df7785225f80a77
- b5795c22e58a84982d07d6846e1929f9eba2166f
- 9fea9987c80b7709896d6a46e750b0a0c7925c30
- 639e6a21c2fa231ef59f0c8aab3d67494a0bce8a
- 2c8445cbde7892ceff58fb58780a79278bcf7d6e
- a76f2110c364943a6a2b000cd575807b8f75a6e6

Migrate legacy Project members as follows:

- TestBugFixes: 19369540b1a2f92b3ab4fd1cedb4db7cefe41498
- ReuseEmptyEditorIssue: a41be8a2ef85b234f33f4003a47fd3d0117b6e83
- MiscCleanupAndDocs: expand reviewed range to these commits:
  - 1df3bec4c822e6fcc30d809dab5277868a8e3290
  - 486b13c723b2fac0220854d9ea7269a09442e7ce
  - e8c7dcb8fa1bcfe202e061807bb6873d2e1e0473
  - 65538b7f93d2246cfc37625f018af76640c6aa40
  - 716c54c01f81ac69fb1c6e5252727cbd5dd10310
- LaunchOpenFlacOrDocFix:
  3c4cfff64ee127631152a551713977c1ad5a40dd
- ContentView Reorganization Plan: link Plan 2 to Project; do not create Plan
  Commit

Required cross-Theme inclusions:

- 0015089006f52550ef2f4ed4fdd0057bb9e521b9: User Docs
- 639e6a21c2fa231ef59f0c8aab3d67494a0bce8a: Settings

Required negative Theme edges:

- b5795c22e58a84982d07d6846e1929f9eba2166f: not Tags
- 9fea9987c80b7709896d6a46e750b0a0c7925c30: not AppleScript, not Tags
- f7f7e4be43044e840ea69ce6c03d1217b38913ad: not Settings
- 05c75465e894b197009e4fa12fcee8a2f232be65: not Tags
- abe9194d5f3d791d34010e12ea51acb0054ae4ce: not User Docs
- c499b7aead381ce46c275a2b7e1571e2a49a4cc8: not Tags
- 149bf183fe3edf4d14481d354a078cb50f628aee: not SwiftTag Document
- e031a26f031d038fcc430fb7057600f67102ccbe: not AppleScript

## Theme Coverage Methodology

### Configuration-Driven Theme Support

Preserve every current Theme and its full configuration:

- Picture
- SwiftTag Document
- Diff
- AppleScript
- Tags
- Save
- Settings
- User Docs
- Project
- FLAC Lib

Preserve display name, description, aliases, keywords, documentation paths,
auto-match setting, explicit Commit includes, excludes, exact-path
rules, path-prefix rules, and manual edges. New configured Themes must work
without code changes or hard-coded report branches.

Generate data row, HTML detail page, review packet, metrics, and chart entry for
every configured Theme, including zero-value Themes.

### Commit Theme Coverage Audit

After automatic and manual Theme linking:

1. Audit every in-range commit.
2. Accept Commit when it has one or more non-excluded Theme edges.
3. When no Theme is accepted, emit missing_theme_assignment warning.
4. Warning links Commit page, commit source, candidate Themes, scores, evidence,
   and negative edges that prevented assignment.
5. Do not force Project, default, or nearest Theme solely to silence warning.
6. Keep unthemed Commit outside Theme totals but include it in coverage
   denominator and Theme matrix/coverage visualization.
7. Show themed count, unthemed count, and coverage percentage on index.html,
   themes.html, warnings.html, metrics.json, and run metadata.
8. Every Commit must therefore satisfy one of:
   - at least one accepted Theme
   - exactly one active missing_theme_assignment warning

## Time And Metric Calculations

### Commit Time

- Sum only transcript turn/segment shares allocated to Commit.
- Show raw transcript membership separately from allocated metrics.
- Show visible elapsed, Assistant processing, and User response separately.
- Show unavailable timing count.
- Show active evidence date range.
- Do not use commit date as conversation duration.

### Plan Time

- Direct Plan time uses Plan-authoring segments.
- Implementation time uses allocated segments associated with implementation
  commits.
- Shared implementation time is fractionally allocated across Plans for
  plan-category totals.
- Plan page shows direct, implementation, allocated, and unavailable values.

### User Response Brackets

Keep:

- 0-1h
- 1-2h
- 2-4h
- greater than 4h

Report count, min, max, mean, median, and total for valid durations only.

## Difficulty Methodology

### Baseline Weights

Use Docs/Analysis/config/difficulty_weights.json:

- code_lines: 0.30
- transcript_lines: 0.15
- plan_lines: 0.10
- elapsed_time: 0.20
- assistant_processing_time: 0.10
- back_and_forth_count: 0.15

### Commit Difficulty

Inputs:

- app-code lines from sole commit as weighted code_lines signal
- test and documentation lines from sole commit as visible context, not added to
  baseline score unless weights config is explicitly extended
- Plan file additions/deletions from sole commit as weighted plan_lines signal
- allocated transcript lines
- allocated visible elapsed time
- allocated Assistant processing time
- allocated back-and-forth
- unavailable timing count as confidence context

Normalize across commits only.

Exact configured-signal mapping:

- code_lines = sole commit app-code additions plus deletions
- transcript_lines = accepted allocated transcript lines
- plan_lines = sole commit Plan-path additions plus deletions
- elapsed_time = accepted allocated valid visible-elapsed intervals
- assistant_processing_time = accepted allocated valid Assistant intervals
- back_and_forth_count = accepted allocated pair count

Test and documentation line counts remain report/context fields.

### Plan Difficulty

Inputs:

- current Plan source lines as weighted plan_lines signal
- Plan revision churn as visible context, not added to baseline score unless
  weights config is explicitly extended
- allocated direct and implementation transcript lines
- allocated associated implementation app-code lines as weighted code_lines
  signal
- allocated test and documentation lines as visible context
- allocated visible elapsed time
- allocated Assistant processing time
- allocated back-and-forth
- associated Commit count as context, not weighted baseline unless config is
  explicitly extended

Normalize across Plan families only.

Exact configured-signal mapping:

- code_lines = accepted allocated implementation app-code additions plus
  deletions
- transcript_lines = accepted allocated direct plus implementation transcript
  lines
- plan_lines = current Plan-family source line count
- elapsed_time = accepted allocated valid direct plus implementation visible
  intervals
- assistant_processing_time = accepted allocated valid Assistant intervals
- back_and_forth_count = accepted allocated pair count

Plan revision churn, test lines, and documentation lines remain report/context
fields.

For either cohort:

- valid zero stays zero
- unavailable timing stays null in data/display but projects to zero for current
  scoring percentile input and receives zero percentile contribution
- record score keeps original configured weight proportions; no per-record
  renormalization
- difficulty_weight_coverage reports sum of original configured weights with
  available signals

### Labels

- 0-24: Low
- 25-49: Moderate
- 50-74: High
- 75-100: Very High

Commit and Plan scores use same labels but different percentile populations.
Show raw values so scores remain explainable.

## HTML And Navigation

### Commits

commits.html columns, in order:

- Hash linked to sources/commits/<short-hash>.html
- Date
- Subject
- Themes linked to Theme pages
- Difficulty
- Code
- Transcript Lines
- Elapsed
- Plans linked to associated Plan pages
- Transcripts linked to associated transcript sources
- Tests
- Docs

Sort Commit rows by Date ascending, then full hash for deterministic ties.
Navigation contains one Commits link and no separate legacy analytical link.

Commit detail:

- canonical full hash and exact subject
- commit body and changed files
- associated Plan links
- associated transcript/segment evidence
- parent Themes
- timing
- difficulty inputs
- allocation/confidence
- Notes
- timestamp-notes link when applicable

### Plans

plans.html columns:

- Plan family link
- title/order/version count
- Themes
- creation Commit
- associated implementation Commits
- transcripts
- direct time
- implementation time
- difficulty score/label
- first evidence
- last evidence

Plan detail:

- current source and version sources
- revision timeline
- creation, revision, implementation, and transcript-archive commits
- linked commit pages
- transcript segment evidence
- direct and rollup metrics
- difficulty inputs
- allocation/confidence
- Notes

difficulty.html and charts.html must present Commit and Plan difficulty as
separate tables/charts with independent normalization labels.
response-times.html must provide a separate Plan allocation view.
Charts include Plan time allocation, Plan difficulty, and Plan revision
timeline alongside existing Commit/Theme charts.

### Charts And Matplotlib

- Generate every chart through Matplotlib using noninteractive SVG backend.
- Remove handwritten bar_chart and matrix_chart fallback renderers.
- Change matplotlib_pyplot from optional-return/catch-all behavior to
  success-or-actionable-fatal-error.
- Change matplotlib_bar_chart and matplotlib_matrix_chart from Boolean fallback
  contracts to success-or-error and make write_charts call no fallback branch.
- Fail report run with actionable dependency error when Matplotlib import or
  SVG backend initialization fails.
- Use deterministic record ordering, figure dimensions, style, fonts, SVG hash
  salt, metadata suppression, and figure closure.
- Do not filter zero-valued configured Themes from Theme charts.
- Render empty/zero-data charts through Matplotlib with explicit empty-state
  label.
- Include unthemed commits in Theme coverage/matrix visualization.
- README documents required Matplotlib version/environment and verification
  command.

### Themes

- List commits and Plans separately.
- Preserve direct, inherited, shared, and allocated totals.
- Never inherit Theme from old aggregate Commit after migration.
- Compute Theme Commit lens from commits only.
- Compute Theme Plan lens from Plans only.
- Never add Plan implementation rollup to Commit lens because same commits and
  transcript work appear in both.
- Show all configured Themes, zero-value Themes, unthemed commit count, and
  coverage percentage.
- Review packet identifies positive and negative manual edges.

### Notes And Warnings

- Preserve transcripts-without-timestamps-notes.html.
- Rewrite early-commits-contribution-notes.html for normal one-commits;
  remove commit-only fallback and fixed 0.55 confidence language.
- Link warnings.html Source cells to Commit, transcript, Plan, Theme, HTML, or
  source-mirror pages when generated target exists.
- Add warnings for:
  - ambiguous hash
  - conflicting manual subject/hash
  - allocation not equal to 1.0
  - unallocated transcript segment
  - archive-only attribution
  - unresolved Plan path
  - low-confidence Commit/Plan link
  - stale legacy Commit config
  - missing_theme_assignment
  - semantic_review_required
  - semantic_review_stale
  - semantic_review_invalid
  - semantic_review_unallocated

## Implementation Phases

### 1. Freeze Baseline And Add Failing Invariant Tests

- Capture current manual AppleScript and Project expectations in fixture JSON.
- Freeze exact inclusive report boundaries at 2c8445cbde7892ceff58fb58780a79278bcf7d6e
  and 1071c2e0ffd3bbc279f2cca6e15509e725518e25.
- Add tests proving both boundaries are included, HEAD is ignored, descendants
  and later-dated commits are excluded, and invalid ancestry fails.
- Add exact-path exclusion test proving Plan 34 cannot enter Plan discovery,
  review packets, relationships, metrics, generated pages, charts, counts, or
  dirty-file metadata.
- Define review packet, transcript digest, and reviewed-config schemas.
- Add no-runtime-agent/model/network boundary tests.
- Add one-commit invariant tests.
- Add no-synthetic-Plan-Commit test.
- Add transcript chronology and archive-only tests.
- Add Plan category/difficulty output tests.
- Confirm tests fail for current mixed model before migration.

### 2. Create Commits First

- Refactor cross-reference engine to instantiate Commits only from commits.
- Use full hash identity.
- Parse primary subject and breaking metadata.
- Keep body subjects as evidence.
- Remove Plan/transcript Commit creation fallbacks.
- Populate one-to-one commit links.

### 3. Promote Plans

- Build Plan family records and revision history.
- Populate creation/revision roles from changed paths.
- Add Plan relationships to commits, Commits, transcripts, and Themes.
- Add direct versus implementation metric fields.
- Add Plan difficulty cohort.

### 4. Add Deterministic Transcript Evidence And Review Packets

- Separate archive provenance from work attribution.
- Add deterministic base segment records and transcript digests.
- Implement directional chronology.
- Rank transcript-to-Commit and transcript-to-Plan candidates without accepting
  semantic work ownership.
- Generate transcript review packets and --review-only command.
- Preserve unavailable-timing handling.

### 5. Migrate Reviewed Association Config

- Convert legacy aggregate Commit mappings to hash/Plan keys.
- Migrate explicit reviewed decisions separately from old inferred links.
- Preserve reviewed allocation weights.
- Add explicit positive/negative Theme edges.
- Deduplicate entries.
- Expand legacy cluster Theme members to canonical commits.
- Migrate confirmed 5866685/859a8f5 transcript associations and both 0c2d385
  transcript-archive provenance edges without making membership exclusive.

### 6. Run Development-Time Agent Review

- Run --review-only on current repository.
- Use this Plan as review rubric.
- Review every transcript packet needed by Commit/Plan time and difficulty
  totals.
- Record accepted/rejected candidates, segment ownership, roles, evidence,
  unallocated remainder, and review provenance in version-2 config.
- Re-run packet pass until no required review is missing, stale, or invalid.
- Commit reviewed config separately from generated report output when practical.

### 7. Recompute Commit, Plan, And Theme Metrics

- Apply only exact structural edges and reviewed semantic config.
- Compute metric-specific weights from reviewed segment ranges.
- Normalize allocations and expose explained unallocated remainder.
- Compute Commit difficulty from one commit plus allocated transcript share.
- Compute Plan direct and rollup difficulty separately.
- Rebuild Theme membership from commit and Plan edges.
- Preserve all configured Themes and run commit Theme coverage audit.
- Emit missing_theme_assignment for every Commit without accepted Theme.
- Verify category totals do not double-count internally.

### 8. Update Reports And Data

- Replace features.html and prior raw commits.html with one date-ascending
  commits.html using requested 12-column layout.
- Move analytical Commit detail pages to sources/commits/<short-hash>.html and
  remove output/features.
- Add Plan analytical detail pages.
- Update detail pages, charts, timelines, review packets, CSV, JSON, notes, and
  warnings.
- Replace handwritten SVG fallbacks with required Matplotlib-only chart path.
- Keep zero-value Themes and unthemed coverage visible in charts.
- Update Docs/Analysis/README.md with one-commit invariant, Plan
  category, two-pass agent review boundary, config schema migration, allocation
  rules, required Matplotlib environment/preflight, and output changes.
- Remove stale synthetic Commit pages.
- Validate escaped Unicode, punctuation, and HTML.

### 9. Verification

- Run pure parser/allocation unit tests.
- Run repository integration tests.
- Run python3 -m unittest discover Docs/Analysis/tests.
- Run python3 Docs/Analysis/analyze_swifttag_project.py --repo-root . --output
  Docs/Analysis/output.
- Run same command with --require-reviewed-associations and require success for
  current repository.
- Run generator twice.
- Compare all analytical data files except run_metadata.json; separately compare
  stable run-metadata fields while ignoring UTC timestamp, dirty status, Python
  environment, and other documented volatile fields.
- Validate every internal link.
- Inspect conformance fixtures.
- Review warnings and confirmed nonexclusive transcript associations.

## Test Strategy

### Unit Tests

- one commit creates one Commit
- Commit count equals commit count
- every Commit owns exactly one full hash
- Plan/transcript parsing creates no Commit
- body with multiple conventional-looking sections creates one Commit
- refactor(applescript)! subject parses breaking marker
- BREAKING CHANGE and BREAKING-CHANGE footers parse
- non-conventional historical subject produces normal commit with
  unparsed conventional metadata warning
- full-hash canonicalization and short-hash ambiguity
- duplicate override deduplication
- exact, renamed, .md.md, versioned, and mismatched Plan paths
- Plan 11 versions group while same-slug Plans 19, 20, and 22 remain separate
- Plan creation and revision roles
- one commit carries Plan creation/revision and implementation roles
- Plan creation ordering follows ancestry/status A through rename history
- Plan 11 has one family creation and later version-addition roles
- transcript archive provenance separate from work attribution
- same-commit transcript/code association
- later transcript archive associates backward to work commit
- archive-only commit receives no work time automatically
- deterministic base segments and review packets are stable across runs
- transcript normalized-content digest changes when review-relevant source
  changes
- review-input digest changes when referenced Plan/candidate commit evidence or
  review method version changes
- semantic candidate contributes no totals before agent-reviewed config
- exact structural edge remains visible without semantic review
- reviewed segment ranges derive metric-specific line/time/count weights
- whole-transcript percentage is accepted only when reviewed reason says segment
  separation is impossible
- stale transcript or review-input digest emits semantic_review_stale and
  excludes allocation
- missing review emits semantic_review_required and excludes allocation
- invalid segment/range/conservation emits semantic_review_invalid
- accepted turn/segment allocations plus explicit remainder equal 1.0 in each
  separate Commit and Plan lens
- shared Plan evidence defaults to equal accepted-Plan allocation
- unavailable timing retains count metrics
- unavailable timing is null in data, contributes zero score without weight
  renormalization, and reports coverage
- Commit and Plan difficulty normalization
- negative Theme override wins
- schema-v1-to-v2 config migration covers every legacy key and is idempotent
- transcript-, commit-, and Plan-scoped exclusive sets affect only named lens
- malformed config and unresolved canonical hash fail validation
- one Commit's Plan-path line change contributes once
- missing Theme emits missing_theme_assignment without fabricated fallback
- Matplotlib import/backend failure raises actionable fatal dependency error
- Matplotlib configuration fixes SVG backend, style, fonts, hash salt, and
  metadata
- warning Source rendering links resolvable generated targets and preserves
  plain text for unresolved/non-page sources
- chart x-axis and general text use configured readable font sizes

### Repository Integration Tests

- configured commit count equals Commit count
- configured commit set equals exact closed ancestry range from
  2c8445cbde7892ceff58fb58780a79278bcf7d6e through
  1071c2e0ffd3bbc279f2cca6e15509e725518e25
- start and end boundary commits appear in commits.csv and Commit output
- commits after 1071c2e0ffd3bbc279f2cca6e15509e725518e25 remain absent from
  commit rows, relationships, metrics, Themes, charts, and totals
- report result stays unchanged when repository HEAD advances past fixed end
- Plan 34 exact path is absent from Plan records, lookup data, review packets,
  relationships, metrics, generated pages, charts, counts, and dirty-file data
- --review-only generates one transcript packet per discovered transcript and
  does not require reviewed semantic config
- normal report exposes unreviewed/stale/invalid warnings and excludes affected
  semantic totals
- --require-reviewed-associations succeeds for current reviewed repository and
  fails for fixture with missing review
- generator leaves every config file byte-for-byte unchanged
- analyzer source/runtime has no agent/model SDK, agent-spawn, or network
  dependency
- offline final run succeeds using only repository inputs and Matplotlib
- semantic_review_status.csv matches transcript config/digest state
- configured report hashes, parsed commits, and Commit ids are identical sets
- no Commit has zero or multiple commits
- no Plan-family slug appears as synthetic Commit
- bee209c remains one Commit linked to 2026-04-20, not 2026-04-21 work
- Plan 26 direct authoring uses only 192eaac and direct 2026-04-18 share; later
  links remain implementation/plan-revision only
- 5866685 has confirmed 2026-04-21 association
- 859a8f5 has confirmed nonexclusive 2026-04-22 association
- content parser also discovers 859a8f5 work segments in 2026-04-21 and
  0c2d385 work segment in 2026-04-22
- 0c2d385 has zero-work transcript-archive edges to both 2026-04-21 and
  2026-04-22 files
- 0c2d385 Plan 26 edge records plan-revision, implementation, and
  transcript-archive roles without conflating their metrics
- 2026-04-21 metric allocations conserve transcript sources across 5866685 and
  859a8f5 content-derived work segments
- no stale fingerprint conflict warning remains
- existing reviewed allocation weights remain stable or changes are explicitly
  approved
- configured and generated Theme ids match for Picture, SwiftTag Document,
  Diff, AppleScript, Tags, Save, Settings, User Docs, Project, and FLAC Lib
- every configured Theme has data row, HTML page, review packet, metrics, and
  chart entry, including zero-value Themes
- every commit has accepted Theme or missing_theme_assignment warning
- negative override removing final Theme produces warning, not forced fallback
- Project Theme includes required commits and Plan 2
- Theme Commit and Plan lenses remain separate and non-additive
- required cross-Theme links exist
- required negative Theme links remain absent
- all eight untimestamped transcripts:
  - retain lines/turns/back-and-forth
  - retain null timing fields and unavailable timing count
  - contribute no fabricated duration to aggregates
  - appear on notes page
  - link from every associated Commit Notes section
- commits.html uses requested 12-column layout, date-ascending order, and
  working Theme, Plan, transcript, and Commit-detail links
- plans.html and plans/<id>.html exist
- plans.html ends with First Evidence and Last Evidence columns and omits
  Warnings column
- timelines.html is absent and navigation contains no Timelines entry
- Plan detail pages link commits and transcripts
- generated source anchors exist
- all internal links resolve
- stale aggregate Commit pages are removed
- no stale aggregate ids remain in version-2 config or output
- Commit detail page filenames use unique short hashes under sources/commits
- features.html and output/features are absent
- relationships.csv and segment_allocations.csv contain one edge per row and
  conserve allocation totals
- early-commit notes contain no fallback-Commit or fixed 0.55 semantics
- CSV/JSON row counts match in-memory records
- deterministic rerun produces stable analytical data
- all expected SVGs come from Matplotlib and contain deterministic metadata
- missing Matplotlib fails full analysis with actionable error
- no handwritten chart fallback executes
- every current Commit/transcript warning links from Source column to its
  generated detail/source page
- chart SVG text uses configured larger x-axis and base font sizes
- schema and verification instructions in README match generated output

### Manual Review

- Compare top Commit difficulty before/after allocation migration.
- Compare top Plan difficulty and raw inputs.
- Inspect Plan 26 timeline and transcript splits.
- Inspect archive commit 80b722e behavior.
- Inspect Project Theme membership and exclusions.
- Inspect untimestamped transcript notes links.
- Review every low-confidence or nonexclusive manual association.

ViewInspector, XCUI, Xcode build, and FLAC fixtures are not applicable.

## Acceptance Criteria

- Report uses only closed inclusive commit range
  2c8445cbde7892ceff58fb58780a79278bcf7d6e through
  1071c2e0ffd3bbc279f2cca6e15509e725518e25.
- Initial and end commits are included. Every commit after or dated after end
  commit is excluded from all report data and calculations.
- Generated run metadata records exact full start and end hashes.
- Advancing HEAD does not change included commit set.
- Docs/Plans/34-SwiftTagProjectAnalysis.md is absent from all report inputs,
  records, relationships, metrics, pages, charts, counts, and dirty-file data.
- Every in-range commit has exactly one Commit.
- Every Commit has exactly one commit.
- No Plan or transcript cluster exists as Commit.
- Commit identity is stable full hash.
- Commit analytical page path uses sources/commits/<short-hash>.html while
  canonical identity remains full hash.
- Primary commit subject is Commit display name.
- Plans are first-class records with analytical detail pages.
- Same-number explicit Plan versions group; same-slug different-number Plans
  remain separate.
- Plan pages show creation, revision, implementation, and transcript evidence.
- Plan pages show direct and implementation time separately.
- plans.html shows First Evidence and Last Evidence and does not show Warnings.
- timelines.html and Timelines navigation entry are absent.
- Commit and Plan difficulty use current weighting method in separate cohorts.
- Transcript timing is assigned through turn/segment allocation.
- Generator never spawns agent/sub-agent, calls model API, imports model SDK, or
  uses network for semantic classification.
- --review-only deterministically emits transcript review packets without
  semantic config mutation.
- Development-time agent writes semantic decisions to checked-in version-2
  config; project-specific transcript decisions are not hard-coded in Python.
- Generator computes weights from reviewed segment ranges; scalar percentages
  require reviewed explanation that segmentation is impossible.
- Missing, stale, or invalid semantic review is excluded from totals and emits
  explicit semantic-review warning.
- Transcript or review-input digest change invalidates prior review.
- Generator leaves config byte-for-byte unchanged.
- --require-reviewed-associations succeeds for current repository before report
  is accepted as complete.
- Transcript archive provenance does not assign work time by itself.
- Accepted Commit transcript allocations plus explicit unallocated remainder
  total 1.0 per transcript metric.
- Accepted Plan allocations plus explicit unallocated remainder total 1.0
  within Plan lens; shared accepted Plan work defaults to equal allocation.
- Plan allocations do not double-count within Plan category.
- Commit, Plan, and Theme totals are labeled as separate views.
- commits.html replaces prior features.html and raw commits.html views with
  columns Hash, Date, Subject, Themes, Difficulty, Code, Transcript Lines,
  Elapsed, Plans, Transcripts, Tests, and Docs.
- commits.html sorts Date ascending and links Hash, Themes, Plans, and
  Transcripts where applicable.
- Navigation contains one Commits link and no separate legacy analytical link.
- Commit details contain associated Plan links.
- Project Theme includes all required commits and Plan 2.
- Theme Commit and Plan lenses are separate and non-additive.
- All required positive and negative Theme overrides pass.
- Every current configured Theme is preserved and gets data, HTML, review
  packet, metrics, and chart output even when value is zero.
- Every commit has at least one accepted Theme or active
  missing_theme_assignment warning with review evidence.
- No Project/default Theme is fabricated without evidence.
- Plan 26 direct-only behavior matches Confirmed Decisions.
- 5866685 and 859a8f5 confirmed transcript associations exist; 0c2d385 owns
  archive provenance for both files; parsed work edges remain nonexclusive.
- All AppleScript mapping fixtures pass with no stale fingerprint conflict.
- transcripts-without-timestamps-notes.html exists.
- Every Commit associated with one of eight known untimestamped transcripts
  links notes page.
- Untimestamped transcripts contribute count/difficulty evidence but no
  fabricated time.
- Generated output has no stale aggregate Commit pages.
- Version-2 config has no stale aggregate Commit identities.
- early-commits-contribution-notes.html contains no fallback Commit model.
- Relationship/allocation CSV files store one edge per row and conserve source
  metrics with explicit remainder.
- All generated internal links resolve.
- Docs/Analysis/README.md documents new identities, schema, allocation, and
  verification commands, including two-pass agent review boundary and required
  Matplotlib environment.
- All charts are generated through Matplotlib SVG backend; no handwritten
  fallback renderer remains.
- Missing Matplotlib stops analysis with actionable dependency error.
- Repeated runs produce deterministic Matplotlib SVG content and metadata.
- Unit and repository integration tests pass.
- Full analysis completes twice with deterministic analytical output.
- Remaining warnings are documented and reviewable.

## Open Questions

None. Prior questions are resolved in Confirmed Decisions.
