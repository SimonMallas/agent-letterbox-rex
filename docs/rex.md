# Rex

Rex is a terminal with a multiplexer. This edition rings one of its blocks.
The letter stays the letter. Rex does not keep the mail.

Register from inside a block, or pass the full id:

```bash
letterbox rex setup --agents planner,builder --dir /path/to/box
letterbox rex register planner
```

The id looks like `block:` and a UUID. A label, a position, or a short
suffix is refused. Those can match a different block.

The doorbell runs `rex send`, waits, then `rex send-key enter`. Every call
passes `--autostart=false`, so this adapter does not start a server. A
server started some other way can be there on a later nudge.

On lookup, exit 3 skips that row. If no row is live, the outcome is
`surface_not_found`. Exit 4 on lookup is `server_unreachable` and is not
retried. A lookup that hits the step cap is still `helper_timeout`, and
the wrapper tries that again. A send that fails, including exit 3 or exit
4, is `send_failed`. A step-cap timeout on that send is `unconfirmed`. If
Enter then fails, the text is already there: `pasted_not_submitted`.

If the foreground program is a shell, or a program in the block says it is
blocked, the line is not typed. A permission question is that blocked
state, so Enter is not sent and the question is left unanswered. When the
foreground cannot be read, the line is typed. When program status errors,
or is not readable, the line is typed too. A timeout on either check is
`helper_timeout` and is not typed.

Known limit: if the block is not a shell and not blocked, text already
sitting in the block is joined to the doorbell, and Enter submits both.
This edition does not detect or clear that text. Write from the Desk or a
phone instead of leaving text in the prompt.

`REX_BIN_PATH`, when set, is the binary, and nothing else is tried. That
name is ours. Rex itself sets `REX_BIN_DIR`, and that directory is tried
next, then the Rex app bundle on this Mac. A `rex` on `PATH` is asked
for `version` once. It is used only when that first line is `rex` and a
digit. A different tool is not used. A Perl script of the same name is
not executed. Do not run `rex skill setup` from here. Nothing in this
command installs a skill or a launcher.
