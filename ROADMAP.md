# Agent Letterbox for Rex roadmap

## Shipped

Agent Letterbox for Rex is a filesystem-first coordination system for live
local Rex blocks.

- Durable Markdown letters in per-agent inboxes.
- Task vs non-task handling (`requires_ack`), with non-terminal `ack` plus
  `.md.ack` sidecars and terminal `nack` / `result`.
- One-shot `result` / `nack` for requests that explicitly opt out of ACK.
- `letterbox file` for non-task disposal; reply-first publication and
  recipient-owned archival.
- Safe reference handling: full id, display id, or unique opaque token.
- `letterbox token <8hex>` glance status: unhandled, already filed, or unknown.
- Operational inbox view: live work first, stale work last, progress age,
  `--recent`, `read`, and read-only threads.
- `progress` notes on an accepted letter, without publishing a new one.
- Atomic publication, advisory locks, lifecycle locks, and filesystem
  completion proof.
- `letterbox rex setup` / `run` / `register` for a full block id.
- Rex block doorbells, typed by default (`LETTERBOX_REX_SUBMIT=1`; `=0` turns
  typing off). A static block-id pattern is the fallback after the registry.
- Honest doorbell outcomes — never a claim that an agent read a letter.
- Public privacy, vocabulary, mutation, and early-abort test gates.
- Local Rex only. This edition does not start the server.

## Next

- Observe real use before adding more helper surface.
- Dogfood multi-agent Rex layouts.
- Soak one real ack-then-result cycle on a Rex server this tree does not start.
- Keep lifecycle semantics aligned with the cmux, tmux and Zellij siblings
  without coupling releases.
- Improve operator diagnostics without turning Letterbox into a dispatcher or
  task board.

## Deferred / out of scope

- Remote Rex packaging; multi-machine file transport or networked doorbells.
- Plugins marketplace distribution as a dependency.
- cmux/tmux/desktop/webhook adapters in this tree — sibling products.
- Autonomous desktop-agent turns.
- Persistent watchers, relay or proxy services, required background daemons,
  or a permanent postmaster role.
- Automatic backlog drain tools that bulk-file inboxes.
- `check --deep` reconciliation of letters that older helpers wrongly archived
  after ACK.
- A frontmatter protocol-version field: the on-disk format is unchanged.
- Built-in chat bridges; customer messaging apps remain native and independent.
  Any external messaging or external-doorbell transport requires a separate,
  app-neutral charter.
- Session `resume-log` as a public CLI surface.
- Auto-registration, machine read receipts, automatic reassignment, and
  guaranteed wake claims.
- Cross-host transport and message signing require separate evidence-led work.
