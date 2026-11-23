# Changelog

All notable changes to Agent Letterbox for Rex are documented here.

Versions are whole numbers. This edition starts at 1.

## Unreleased

- The readme opens with a Quick install jump to the install section. That section still holds the copy-this prompt and the commands. The section stays where it is.
- The copy-this prompt is a short pointer at this checkout. It stops when this checkout is absent, names no remote, and does not clone another tree. The install rules stay on this page: `install.sh` with `AGENT_LETTERBOX_REPO`, stop if the launcher is not this checkout, an empty directory for `--dir`, and stop if a layout or a bridge would change.

## 1 — 2026-11-20

This is the Rex edition. It rings a registered Rex block.

- `letterbox rex` registers a block by its full id. A label or a short id is refused. The doorbell is typed with `rex send`, then Enter after the usual pause. Every Rex command passes `--autostart=false`, which means this adapter does not start a server. On lookup, no live block is `surface_not_found`, and exit 4 is `server_unreachable` and is not retried. A failed send is `send_failed`.
- The binary is `REX_BIN_PATH` if that is set, otherwise `REX_BIN_DIR`, then the Mac app bundle, then a `rex` on `PATH` only when `rex version` says it is this Rex. That ask runs the PATH program once. A Perl script of the same name is not executed.
- A shell in front is not typed. A program that says it is blocked, including a permission question, is not typed. Text already sitting in a block that is not a shell and not blocked is joined to the doorbell, and Enter submits both.
- Settings are `REX_BIN_PATH`, `REX_BIN_DIR`, `LETTERBOX_REX_REGISTRY`, `LETTERBOX_REX_PATTERNS`, and `LETTERBOX_REX_SUBMIT`.
- The `thread` field on a reply is additive and optional. Letters without it remain valid. Readers ignore unknown fields.
- An ownership reply uses `letterbox reply`. A delegate requires `--ack`.
- `progress` records a note. `nudge` rings an open letter again. A doorbell token is accepted by prefix and pattern.
