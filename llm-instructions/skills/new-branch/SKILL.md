---
name: new-branch
description: Create a new git branch from main and switch to it
disable-model-invocation: true
allowed-tools: Bash(git *)
argument-hint: [branch-name]
---

Create and switch to a new branch named `$0` from the latest main:

1. Run `git fetch origin`
2. Run `git checkout -b $0 origin/main`
3. Confirm the new branch is active with `git branch --show-current`
