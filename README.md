# Colofa

A native macOS Git client for the kind of Git work you do thirty times a day.

Colofa assumes you are not going to linger. You open it, see what changed, stage a few files, commit, sync, and close it again. That round trip is the whole product.

It also shows Git's real state rather than a simplified one. The index, HEAD, and the upstream are objects you already have a mental model of, so Colofa displays them as they are instead of collapsing them into checkboxes and a single sync button.

## Status

Early development. What works today, against real repositories, through the `git` CLI you already have installed:

- Opening a repository with the native picker, and reopening the last one on launch
- Ordinary repositories, linked worktrees, and repositories inside submodules
- Live status: branch, upstream, ahead and behind counts, staged and unstaged changes
- Staging and unstaging files, one at a time or all at once
- Creating Commits from exactly the staged changes, including first Commit and Amend workflows
- A repository inspector showing effective Git configuration, with editing for `user.name`, `user.email`, and `http.proxy` in either repository or global scope
- Diffs for the selected staged or unstaged change, in unified or split layout, with renames showing both paths, submodules showing both commits, and binary files showing metadata instead of invented text
- Size limits enforced while the patch is still being read: anything past 2 MiB or 20,000 lines waits for you to ask for it, and anything past 10 MiB or 100,000 lines is summarised rather than rendered
- Browsing the history of any local branch, remote branch, or tag by selecting it — inspection only, never a checkout: 200 topologically ordered commits at a time, with a Load More that appends the next page without duplicates or gaps
- Two ways to read that history, both of them Git's own answers: every reachable commit, or `--first-parent` — the ref's own line, where a side branch is represented by the merge that integrated it rather than by its commits
- Commit details for the selected commit: full message, SHA, author and committer with both times, parents, refs, and the paths it changed, with a root commit and a shallow-clone boundary stated as the different things they are
- Reading a commit one file at a time, the way the working set is read: clicking a changed path asks Git for that path's patch, so a large commit stays browsable and a size limit is reached by a file rather than by a commit
- Copying the selected commit's full SHA or the selected branch's name

Still missing: hunk staging, branch operations, fetch, pull, push, stashes, merge, and rebase. Their toolbar buttons already hold their places, disabled. The interface was settled first as the design target, and the backend is working its way up to it.

## The window

Three columns and a status bar, arranged in the order the work happens: look at changes, pick changes, write a message, commit, sync.

```
┌─ Toolbar ────────────────────────────────────────────────────────────┐
│  ⌘ Colofa │              Fetch │ Pull ② │ Push ③ │ Branch │ ⓘ        │
├───────────┬───────────────────────────┬──────────────────────────────┤
│ Sidebar   │ Changes                   │ Diff                         │
│           │                           │                              │
│ Workspace │ ⚠ Rebase in progress      │ Sources/Git/Repository.swift │
│  Changes  │   2 of 5  [Continue][Abort]│ +18 −4       [Unified|Split] │
│  History  │                           │ ───────────────────────────  │
│  Stashes  │ ▾ Staged (2)      Unstage │ @@ -12,7 +12,9 @@   [Unstage]│
│           │   M Repository.swift  +18 │  12  12   func load() {      │
│ Branches  │   A Diff.swift        +96 │      13 + let head = …       │
│  ✓ main   │                           │  13  14   }                  │
│    feat/x │ ▾ Changes (3)       Stage │                              │
│           │   M App.swift          +4 │                              │
│ Remotes   │   ? Notes.md              │                              │
│  origin   │ ───────────────────────── │                              │
│           │ [ Summary               ] │                              │
│ Tags      │ [ Description           ] │                              │
│           │ □ Amend         Commit 2  │                              │
├───────────┴───────────────────────────┴──────────────────────────────┤
│ ⑂ main → origin/main · ↑3 ↓2 · Fetched 2 minutes ago                 │
└──────────────────────────────────────────────────────────────────────┘
```

The rest of the interface falls out of a handful of decisions.

Staged and Changes stay two separate sections. One list with checkboxes looks tidier, but it has no way to say that a file is half staged, and the moment hunk staging ships, that state stops being hideable.

The commit editor sits under the staged list rather than in the sidebar, so picking files and writing the message happen in one movement down the middle column.

Rebase and merge are absent from the toolbar, which holds only frequent, safe operations. The destructive and infrequent ones live in branch context menus and the menu bar, where they have an obvious object and no chance of a stray click.

A half-finished rebase or an unresolved conflict is a situation that lasts, not a momentary alert. It sits in a banner across the top of the middle column with Continue, Skip, and Abort within reach, and conflicted files jump to the top of the list. A modal would wall off exactly the file browsing you need to get out of it.

Ahead and behind counts sit on the Push and Pull buttons themselves. What you do about the number is press that button.

Repository information lives in a trailing inspector, collapsed by default. It is something you glance at now and then, so it has no claim on window width the rest of the time.

Editing configuration means picking a scope first and typing second. One picker rules the whole section, and every field spells out its relationship to the other scope: inherited, overriding, or the dangerous one, where you are editing the global value while this repository quietly overrides it. Clearing a field runs `git config --unset` rather than storing an empty string, since an empty value is still a value and goes on shadowing the global one.

Meaning is carried by the status letters (M / A / D / R / ? / U), with color along for support. That holds everywhere in the app.

## Requirements

- macOS 14 or later
- Git available on the system. Colofa runs the local `git` CLI so your credential helpers, SSH agent, config, and hooks keep working
- Xcode 26.6 with the macOS 26.5 SDK and Swift 6.3.3 to build

## Build and run

```bash
open Colofa.xcodeproj
```

Or from the command line:

```bash
xcodebuild build -project Colofa.xcodeproj -scheme Colofa -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

## Tests

Three targets split the work:

| Target | Covers |
| --- | --- |
| `ColofaTests` | Parsers, repository state, and view models. No Git process involved. |
| `ColofaGitIntegrationTests` | Real Git repositories created on disk, driven through the real CLI. |
| `ColofaUITests` | Interface behavior. English only. |

```bash
xcodebuild test -project Colofa.xcodeproj -scheme Colofa -destination 'platform=macOS' -only-testing:ColofaTests CODE_SIGNING_ALLOWED=NO
```

Run the real Git integration tests with the same unsigned setup:

```bash
xcodebuild test -project Colofa.xcodeproj -scheme Colofa -destination 'platform=macOS' -only-testing:ColofaGitIntegrationTests CODE_SIGNING_ALLOWED=NO
```

UI tests require a locally signed test host:

```bash
xcodebuild test -project Colofa.xcodeproj -scheme Colofa -destination 'platform=macOS' -only-testing:ColofaUITests
```

For a coverage summary from a result bundle:

```bash
Scripts/report-coverage.swift path/to/result.xcresult
```

CI is not enabled; validation runs locally. Run SwiftLint with the version declared in `.swiftlint-version`:

```bash
swift Scripts/swiftlint.swift
```

After an approved SwiftLint version change, regenerate the portable baseline with:

```bash
swift Scripts/swiftlint.swift --write-baseline
```

## Layout

```
Colofa/
  App/                       App entry point and menu bar commands
  Features/
    Repository/
      Models/                Value types for status, refs, config, failures
      Services/              Git CLI invocation and output parsing
    Workspace/
      State/                 @Observable workspace state
      Views/                 Sidebar, changes, inspector, toolbar, status bar
  Resources/                 Assets and Localizable.xcstrings
  Shared/                    Small cross-feature helpers
```

Git logic lives outside the views so it can be tested on its own. One type per file.

---

© 2026 Anemoris Studio. All rights reserved.
