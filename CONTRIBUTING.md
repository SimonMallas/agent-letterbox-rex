# Contributing to Agent Letterbox for Rex

## Scope

**Supported**

- Durable Markdown letters, reply-first handling, atomic publication, advisory locks
- Doorbells to a registered Rex block, typed by default
- Local Rex only. Commands pass `--autostart=false`

**Not in scope**

- cmux, tmux, zellij, and herdr product trees, desktop agents, webhooks, remote transport packaging, marketplace plugins

## Development

```bash
chmod +x bin/letterbox adapters/*.sh tests/*.sh
# make test uses a fake rex. It does not start a Rex server.
make test
```
