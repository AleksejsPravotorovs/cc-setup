# Owner actions — cc-setup

**Updated:** 2026-08-02 · commit `f473119` on `main`

Things only you can do. Everything else is already done and pushed.

## Status at a glance

| # | Action | Who | Urgency |
|---|--------|-----|---------|
| 1 | Send your colleague the install commands | You → colleague | Now — he is blocked |
| 2 | Get his `doctor.sh` output if it still fails | You → colleague | Only if #1 fails |
| 3 | Clean 21 duplicate `pp-setup` aliases in your `~/.zshrc` | You | Low |
| 4 | Your Claude auto-update reports a failed attempt | You | Low |

---

## 1. Send your colleague the install commands

**Why:** his setup crashed because the old script installed Claude through npm only, and
his npm writes to a folder only `root` owns. The fix is live on GitHub as of today, so a
plain re-run now works. He must **not** use `sudo npm install -g` — that creates worse
problems and Anthropic's docs warn against it.

**Steps:** send him this, to paste into Terminal **one block at a time**:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

```bash
exec $SHELL -l
claude --version
```

`claude --version` must print something like `2.1.220 (Claude Code)`. Then, from inside his
project folder:

```bash
curl -fsSL https://raw.githubusercontent.com/AleksejsPravotorovs/cc-setup/main/install.sh | bash
```

**Done when:** `claude --version` prints a version number, and the setup script finishes
without a red `[✗]` line.

**Then tell me:** "colleague is set up" — or paste whatever it printed instead.

---

## 2. If it still fails — get the diagnostic output

**Why:** "it doesn't work" has at least four different causes and I cannot tell them apart
without seeing his machine. This command prints everything needed and changes nothing on
his computer (read-only, no admin rights, no installs).

**Steps:** have him run this from the project folder:

```bash
bash scripts/doctor.sh
```

If that file is missing (his copy predates today), this works anywhere:

```bash
curl -fsSL https://raw.githubusercontent.com/AleksejsPravotorovs/cc-setup/main/scripts/doctor.sh | bash
```

**Done when:** he sends you the whole output, from `===== cc-setup doctor =====` to
`===== end of report =====`.

**Then tell me:** paste it here and I will name the exact cause.

---

## 3. One thing worth ruling out before anything else

**Why:** Claude Code requires a **Pro, Max, Team, Enterprise, or Console** account. The free
Claude.ai plan does not include it. If he is on a free account, every install step succeeds
and it still "doesn't work" at login — no error message will say why.

**Steps:** ask him which Claude plan his account is on.

**Done when:** you know the answer.

**Then tell me:** the plan name, if it is not Pro or Max.

---

## 4. Housekeeping on your own Mac (low priority)

**Why:** `scripts/doctor.sh` found two things on your machine while I was testing it.
Neither breaks anything today.

**a) 21 duplicate `alias pp-setup=` lines in `~/.zshrc`** — one per old project, and only
the last one wins. So `pp-setup` currently points at `test-papka`, regardless of which
project you are in.

**b) Claude's auto-updater reports** `Last update attempt: failed (install_failed)` dated
2026-08-02. You are on 2.1.220, so it is not urgent.

**Steps:** say the word and I will clean the `.zshrc` duplicates and look into the updater.
I have not touched either — editing your shell profile is not something I will do unasked.

**Done when:** you decide whether you want it.

**Then tell me:** "clean up my zshrc" if you do.
