---
name: trello-tasks
description: Fetch latest tasks from a Trello board and summarize them
disable-model-invocation: true
allowed-tools: Bash(curl *) Bash(cat *)
argument-hint: [board-name (optional)]
---

Fetch and summarize open Trello cards.

```!
TRELLO_KEY=$(cat /run/credentials/trello-key 2>/dev/null || echo "MISSING")
TRELLO_TOKEN=$(cat /run/credentials/trello-token 2>/dev/null || echo "MISSING")
BOARD_ID="${TRELLO_BOARD_ID:-default}"

if [ "$TRELLO_KEY" = "MISSING" ] || [ "$TRELLO_TOKEN" = "MISSING" ]; then
  echo "ERROR: Trello credentials not found. Ensure trello-key and trello-token are sealed."
  exit 1
fi

curl -s "https://api.trello.com/1/boards/$BOARD_ID/cards?key=$TRELLO_KEY&token=$TRELLO_TOKEN&filter=open"
```

Summarize the cards grouped by list, with priorities highlighted. If an argument was provided, filter to cards matching "$ARGUMENTS".
