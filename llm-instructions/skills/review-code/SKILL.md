---
name: review-code
description: Review code on the current branch from a specific standpoint
disable-model-invocation: true
allowed-tools: Bash(git *) Read Grep Glob
argument-hint: [standpoint e.g. "security", "performance", "readability"]
---

Review the code changes on this branch from a **$0** standpoint.

## Current changes

Diff against main:

```!
git diff origin/main...HEAD
```

Files changed:

```!
git diff origin/main...HEAD --name-only
```

## Instructions

Follow the review guidelines in @/etc/llm-instructions/code-review-guidelines.md

Focus your review specifically on **$0** concerns. For each issue found, reference the file and line number.
