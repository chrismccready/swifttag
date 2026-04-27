# Apple Docs Index

Local Apple documentation search support for SwiftTag agents.

## Quick Use

Regenerate index:

```sh
python3 Docs/AppleDocsIndex/generate_apple_docs_index.py
```

Search generated text:

```sh
rg -n "NSAppleScript|NSScriptCommand|com.apple.security.automation.apple-events" Docs/AppleDocsIndex/Generated
```

Use Xcode semantic search first when available:

1. `DocumentationSearch` for framework-aware semantic lookup.
2. `rg Docs/AppleDocsIndex/Generated` for exact symbols, entitlement keys, and phrases.
3. Apple Developer web docs when installed docs are missing or stale.

## Sources

The generator discovers:

- installed `.doccarchive` bundles under Xcode, `~/Library/Developer`, and `/Library/Developer`
- installed `.docset` bundles under Xcode and Developer documentation folders
- Xcode bundled AdditionalDocumentation markdown under `IDEIntelligenceChat.framework`

Current Xcode installs may store the main developer documentation in private Spotlight indexes. Those are not useful for direct `rg`, so the generator indexes extractable documentation bundles and markdown files only.

## Scout Profile

Use `apple-docs-scout-agent.md` as the prompt/profile for a low- or medium-reasoning built-in subagent. Current Codex subagent types are built in, so this project stores a reusable scout profile instead of registering a new global agent type.
