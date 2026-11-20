# Rex team setup

This is the setup for a live Rex team. It is local only.

You arrange the blocks. Letterbox does not create them. It registers the full block id you give it, then rings that block when mail arrives.

## One-time setup

```bash
chmod +x bin/letterbox adapters/*.sh tests/*.sh
export PATH="$PWD/bin:$PATH"

letterbox rex setup --agents planner,reviewer,builder,researcher --dir /path/to/box
source /path/to/box/env.sh
```

`/path/to/box` is a directory you choose. Setup writes only that directory. It does not install a skill or a launcher, and it does not choose a default directory.

It creates:

```text
inboxes and processed folders for every named agent
rex-agents.tsv    # agent, full block id, session, registered at
env.sh            # LETTERBOX_DIR, the Rex doorbell, the registry, submit
```

`env.sh` sets `LETTERBOX_REX_SUBMIT=1`. The doorbell line is typed, then Enter. Set `LETTERBOX_REX_SUBMIT=0` to stop typing. `check` then says `doorbell: typing is off`.

## Register

From inside the block, with `REX_BLOCK` set to the full id, or pass `--block`:

```bash
letterbox rex register planner
letterbox rex run planner -- <your-agent-cli>
letterbox rex status
letterbox rex unregister planner
```

The id looks like `block:` and a UUID. A label, a position, or a short suffix is refused.

The session column is recorded. The doorbell does not use it to choose the block.

Optional `rex-patterns.tsv` is two columns, agent and full block id. It is used only when the registry has no live row for that agent.

## What is not typed

A shell in front is `shell_foreground` and is not typed. A program that says it is blocked, including a permission question, is `agent_blocked` and is not typed. When the foreground cannot be read, the line is typed.

Known limit: if the block is not a shell and not blocked, text already sitting in the block is joined to the doorbell, and Enter submits both. This edition does not detect or clear that text. See [rex.md](rex.md).

## One handoff

Requires a Rex server you already started, and a registered block. Send one letter between two agents. Confirm the inbox file and the doorbell, then the reply. This edition does not start the server (`--autostart=false`).
