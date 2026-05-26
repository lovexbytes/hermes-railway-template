# Hermes Agent Enhancements for Raw Valued — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the existing Hermes Telegram bot from a basic Notion-writer into a useful proactive ops assistant for Raw Valued (Ashley's vintage furniture flipping business in CDMX), while rebuilding her chaotic Notion workspace into a clean four-database schema.

**Architecture:** Thin fork of `lovexbytes/hermes-railway-template`. Most behavior changes live as markdown prompts seeded onto the Railway volume on container boot. The Notion workspace is restructured manually (one-time) and then maintained by Hermes through ongoing hygiene behaviors defined in the system prompt.

**Tech Stack:** Docker (slim Python base), bash entrypoint, Hermes agent runtime, Notion (data layer), Railway (host), Telegram (channel).

**Spec:** [`docs/superpowers/specs/2026-05-25-hermes-rawvalued-enhancements-design.md`](../specs/2026-05-25-hermes-rawvalued-enhancements-design.md)

**Note on TDD:** This work is primarily configuration, prompts, and manual Notion setup — not unit-testable code. "Verification" steps replace pytest assertions throughout: each one is a concrete Telegram message / Notion state to check before marking the task done.

**Realistic scope for "today":** Tasks 0.x through 1.5.x (Railway setup, UX wins, Notion redesign + initial migration). Tasks 2.x onward typically follow in a subsequent session.

---

## File Structure

What this plan creates or modifies in the fork:

```
Dockerfile                          MODIFY — add TZ env, ensure tzdata,
                                              copy business_context into image
scripts/entrypoint.sh               MODIFY — seed Hermes context files on boot
business_context/                   NEW directory in repo
├── SOUL.md                         NEW — Hermes system prompt (auto-loaded
                                          when seeded to HERMES_HOME root)
├── notion_schema.md                NEW — Notion field names + DB IDs
├── photo_workflow.md               NEW — photo reply rules
└── digest_format.md                NEW — morning digest prompt template
docs/                               (already exists from spec phase)
```

**On-volume layout after first boot:**

```
${HERMES_HOME}/
├── SOUL.md                         seeded from business_context/SOUL.md;
                                    Hermes auto-loads on every conversation
├── business_context/
│   ├── notion_schema.md            read on-demand by Hermes for Notion work
│   ├── photo_workflow.md           read on-demand for photo messages
│   └── digest_format.md            referenced by the cron digest prompt
└── config.yaml                     existing — gains display.tool_progress=off
```

What this plan creates outside the fork:

- 4 Notion databases (Items, Sales, Expenses, Sources) with views and formulas
- 1 Telegram group chat (Fede + Ashley + bot)
- Multiple Railway env-var settings
- Updated Hermes cron entry (replacing existing morning briefing)

---

## Phase 0 — Resolve upstream unknowns

Six concrete unknowns from the spec must be resolved before code changes land. Each is a targeted research task. None requires deploying — these read upstream source and the running container's state.

### Task 0.1: Verify Hermes' system-prompt file path

**Why:** Phase 2 seeds `business_context/system.md` and adds a one-line include to whichever file Hermes loads as its system prompt. The exact path is documented in upstream `NousResearch/hermes-agent`.

**Files:**
- Read: `NousResearch/hermes-agent` source (online, no local clone needed)

- [ ] **Step 1: Check upstream README and config docs**

```bash
gh api repos/NousResearch/hermes-agent/contents/README.md --jq .content | base64 -d | grep -iE "system.prompt|preferences|HERMES_HOME|persona"
```

- [ ] **Step 2: If README is silent, search the source**

```bash
gh api 'search/code?q=repo:NousResearch/hermes-agent+system_prompt+OR+SYSTEM_PROMPT' --jq '.items[].path' | head -20
```

- [ ] **Step 3: Inspect actual load paths**

For the top 2-3 candidate files from step 2:

```bash
gh api repos/NousResearch/hermes-agent/contents/<path> --jq .content | base64 -d | head -80
```

Look for `HERMES_HOME` joins, file reads, and obvious "system prompt" or "preferences" loading.

- [ ] **Step 4: Record finding**

Update the "Open items" section of the spec to replace item #1 with the concrete answer.

Expected outcome: a precise file path like `${HERMES_HOME}/preferences.md` or `${HERMES_HOME}/system_prompt.md`. If Hermes uses a different mechanism (e.g., a config field rather than a separate file), record that instead.

- [ ] **Step 5: Commit the spec update**

```bash
git add docs/superpowers/specs/2026-05-25-hermes-rawvalued-enhancements-design.md
git commit -m "docs(spec): resolve Hermes system-prompt file path"
```

### Task 0.2: Verify `HERMES_TOOL_PROGRESS` valid values

**Why:** The existing entrypoint already passes through `HERMES_TOOL_PROGRESS` and `HERMES_TOOL_PROGRESS_MODE`, but we don't know which value suppresses tool traces.

- [ ] **Step 1: Search upstream source for the env var name**

```bash
gh api 'search/code?q=repo:NousResearch/hermes-agent+HERMES_TOOL_PROGRESS' --jq '.items[].path'
```

- [ ] **Step 2: Inspect each result to find the parse logic**

For each path returned:

```bash
gh api repos/NousResearch/hermes-agent/contents/<path> --jq .content | base64 -d | grep -nA 5 -B 2 HERMES_TOOL_PROGRESS
```

Look for an `if ... == "false"` / `in {"silent", "off", ...}` style check.

- [ ] **Step 3: Record finding**

Note the exact valid value(s) and what each does. Often there are two: one to silence the feed entirely, one to dim it to a single status line.

- [ ] **Step 4: Commit the spec update**

```bash
git add docs/superpowers/specs/2026-05-25-hermes-rawvalued-enhancements-design.md
git commit -m "docs(spec): resolve HERMES_TOOL_PROGRESS valid values"
```

### Task 0.3: Verify Hermes cron mechanism

**Why:** Phase 4 replaces the existing morning-briefing cron entry; Phase 5 creates new cron entries from natural language. We need to know how cron entries are stored and modified.

- [ ] **Step 1: SSH into the running Railway container**

```bash
railway ssh
```

- [ ] **Step 2: Inspect the cron directory**

```bash
ls -la "${HERMES_HOME}/cron/"
```

- [ ] **Step 3: If files exist, inspect one**

```bash
cat "${HERMES_HOME}/cron/<some-file>"
```

This reveals the on-disk format (JSON? YAML? plain prompt with a schedule header?).

- [ ] **Step 4: Check available Hermes CLI commands**

```bash
hermes --help
hermes cron --help 2>/dev/null || hermes schedule --help 2>/dev/null
```

- [ ] **Step 5: Record finding**

Document: (a) on-disk format, (b) CLI commands to list/add/remove/modify cron entries, (c) whether changes require a Hermes restart.

- [ ] **Step 6: Commit the spec update**

```bash
git add docs/superpowers/specs/2026-05-25-hermes-rawvalued-enhancements-design.md
git commit -m "docs(spec): resolve Hermes cron mechanism"
```

### Task 0.4: Choose FX rate source

**Why:** Component 7 hygiene rules require Hermes to auto-fill the other currency when Ashley provides one. We need a reliable, free, no-auth FX source.

**Decision:** Use [frankfurter.app](https://www.frankfurter.app/) — free, no API key, ECB-sourced daily rates, supports MXN.

- [ ] **Step 1: Smoke-test the endpoint**

```bash
curl -s 'https://api.frankfurter.app/latest?from=USD&to=MXN'
```

Expected: JSON response with `"rates":{"MXN":<value>}`.

- [ ] **Step 2: Verify Hermes can call HTTP from inside the container**

While SSHed in (from Task 0.3):

```bash
curl -s 'https://api.frankfurter.app/latest?from=USD&to=MXN'
```

Expected: same JSON. Confirms egress works from the Railway environment.

- [ ] **Step 3: Document in the spec**

Replace open item #6 with: "FX rate source: `https://api.frankfurter.app/latest`, USD↔MXN. Cached for 24h."

- [ ] **Step 4: Commit the spec update**

```bash
git add docs/superpowers/specs/2026-05-25-hermes-rawvalued-enhancements-design.md
git commit -m "docs(spec): pin FX rate source to frankfurter.app"
```

---

## Phase 1 — Point Railway at the fork + UX wins

### Task 1.1: Snapshot `/data` before any changes

**Files:** none in the fork — operations on the live container.

- [ ] **Step 1: SSH into Railway container**

```bash
railway ssh
```

- [ ] **Step 2: Create the snapshot**

```bash
tar czf /tmp/hermes-backup-$(date +%F).tgz /data/.hermes
ls -lh /tmp/hermes-backup-*.tgz
```

Expected: a `.tgz` file of at least a few KB (likely a few MB).

- [ ] **Step 3: Copy snapshot to your laptop**

In a new local terminal (not SSHed):

```bash
railway run cat /tmp/hermes-backup-$(date +%F).tgz > ~/hermes-backup-$(date +%F).tgz
ls -lh ~/hermes-backup-*.tgz
```

Verify the local file size matches. Keep it until everything's verified working.

### Task 1.2: Switch Railway source to your fork

**Files:** none — Railway dashboard operation.

- [ ] **Step 1: In Railway dashboard, open the Hermes service settings**

- [ ] **Step 2: Change the connected GitHub repo from `lovexbytes/hermes-railway-template` to `igutierrezp/hermes-railway-template`**

- [ ] **Step 3: Trigger a redeploy**

- [ ] **Step 4: Watch the deploy log**

Expected: successful build (same as before, since the fork is identical to upstream at this point) and "Starting Hermes gateway..." in the runtime log.

- [ ] **Step 5: Verify bot responds**

Send a Telegram message: `hello`. Expected: bot replies within a few seconds.

If it doesn't respond, **do not proceed**. Roll back the source change in Railway and investigate.

### Task 1.3: Create the 3-person Telegram group

**Files:** none — Telegram client operation.

- [ ] **Step 1: In Telegram, create a new group**

Add: Ashley, Fede, the Raw Valued bot.

- [ ] **Step 2: Find the group's chat ID**

The simplest method: send a message in the group, then visit `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates` in a browser. Look for `"chat":{"id":-<some negative number>,...}`. Group chat IDs are negative.

- [ ] **Step 3: Record the chat ID**

You'll use this in Task 1.5.

### Task 1.4: Update Dockerfile with TZ

**Files:**
- Modify: `Dockerfile` (runtime stage)

- [ ] **Step 1: Edit Dockerfile**

Find this block in the runtime stage:

```dockerfile
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gh \
    nodejs \
    npm \
    tini \
  && rm -rf /var/lib/apt/lists/*
```

Change to add `tzdata`:

```dockerfile
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gh \
    nodejs \
    npm \
    tini \
    tzdata \
  && rm -rf /var/lib/apt/lists/*
```

Then find the block of `ENV` declarations and add `TZ`:

```dockerfile
ENV PATH="/opt/venv/bin:${PATH}" \
  PYTHONUNBUFFERED=1 \
  HERMES_HOME=/data/.hermes \
  HOME=/data \
  TZ=America/Mexico_City
```

- [ ] **Step 2: Commit**

```bash
git add Dockerfile
git commit -m "feat: set container timezone to America/Mexico_City

Cron-scheduled messages now interpret times in CDMX local time
instead of UTC. Required for the morning digest and reminders to
fire at the wall-clock time Ashley specifies."
```

- [ ] **Step 3: Push to fork**

```bash
git push origin <branch>
```

### Task 1.5: Set Railway env vars

**Files:** none — Railway dashboard operation.

- [ ] **Step 1: In Railway dashboard, open the service Variables tab**

- [ ] **Step 2: Set the routing variable**

```
TELEGRAM_HOME_CHANNEL=<chat-id-from-task-1.3>
```

**Note on tool-progress suppression:** Per Task 0.2's finding, `HERMES_TOOL_PROGRESS` is deprecated. The new mechanism is `display.tool_progress` in `${HERMES_HOME}/config.yaml`. Two ways to set it:

**Option A — leverage Hermes' auto-migration (easier).** Set the deprecated env var `HERMES_TOOL_PROGRESS=false` in Railway. On the next startup, Hermes detects the deprecated var and writes `display.tool_progress=off` into config.yaml automatically. You can then remove the env var.

**Option B — set the config directly.** SSH into the running container after Phase 0:

```bash
hermes config set display.tool_progress off
```

Then redeploy.

Choose A for less manual work. Either way: verify in Step 5.

- [ ] **Step 3: Trigger a redeploy**

Either save the env vars (which auto-redeploys) or click Deploy. Wait for completion.

- [ ] **Step 4: Verify TZ inside the running container**

```bash
railway ssh
date
```

Expected: a CDMX-local timestamp (CST/CDT depending on season).

- [ ] **Step 5: Verify tool-progress suppression**

Send the bot a message that requires a tool call, e.g., `what's in my Notion inventory?`. Expected: clean reply, no `🔍 session_search: recall…` lines in chat.

- [ ] **Step 6: Verify routing to group**

In the group chat (not DM), trigger the existing morning-briefing cron entry manually (mechanism from Task 0.3). Expected: the briefing lands in the group, not in Fede's DM.

- [ ] **Step 7: Verify reminder timing**

In the bot DM:

```
You: Remind me one minute from now to confirm timezone fix
```

Wait one minute (use a stopwatch). Expected: the reminder arrives at the correct wall-clock time, in the group chat.

If TZ is wrong, the reminder will arrive 6+ hours off. If routing is wrong, it'll come to a DM not the group.

---

## Phase 1.5 — Notion structural redesign

This phase is manual work in Notion. No code changes. Track each step.

### Task 1.5.1: Create the Items database

**Files:** none — Notion UI operation.

- [ ] **Step 1: In the Raw Valued workspace, create a new database**

Name: `Items`. Type: Full page database (not inline).

- [ ] **Step 2: Add the following properties, in this order**

Use the property types specified — these are critical for views and formulas to work.

| Property name | Type | Configuration |
|---|---|---|
| Item ID | Unique ID | Prefix: `ITM-` |
| Short name | Title | (this is the default title property; rename it from "Name") |
| Photos | Files & media | |
| Category | Select | Options: Art, Details, Glassware, Lighting, Rugs, Seating, Storage, Tables |
| Era / style | Text | |
| Materials | Multi-select | Starter options: wood, metal, glass, velvet, rattan, brass, leather, ceramic, cane, fabric, marble |
| Status | Select | Options (with colors): Sourcing (gray), In stock (blue), Listed (yellow), Sold (green), Held (purple) |
| Purchase price MXN | Number | Format: Number with commas |
| Purchase price USD | Number | Format: Number with commas |
| Asking price MXN | Number | Format: Number with commas |
| Asking price USD | Number | Format: Number with commas |
| Sale price MXN | Number | Format: Number with commas |
| Sale price USD | Number | Format: Number with commas |
| Date acquired | Date | |
| Date listed | Date | |
| Date sold | Date | |
| Listing platforms | Multi-select | Starter options: FB Marketplace, Instagram, Chairish, In-person, Website |
| Notes | Text | |

(Relations and rollups are added in later tasks once the other databases exist.)

- [ ] **Step 3: Verify**

The Items database now exists with all 17 above properties. No data yet.

### Task 1.5.2: Create the Sales database

- [ ] **Step 1: Create a new database called `Sales`**

- [ ] **Step 2: Add properties**

| Property name | Type | Configuration |
|---|---|---|
| Sale ID | Unique ID | Prefix: `SAL-` |
| Item | Relation | → Items database (set up in 1.5.5) |
| Buyer name | Title | (rename default Name) |
| Sale price MXN | Number | |
| Sale price USD | Number | |
| Platform | Select | Options: FB Marketplace, Instagram, Chairish, In-person, Website, Other |
| Sale date | Date | |
| Delivery method | Select | Options: Pickup, Delivery, In-person, Shipping |
| Notes | Text | |

Skip the Item relation for now — added in Task 1.5.5.

- [ ] **Step 3: Verify Sales DB exists with 8 properties (Item to come)**

### Task 1.5.3: Create the Expenses database

- [ ] **Step 1: Create a new database called `Expenses`**

- [ ] **Step 2: Add properties**

| Property name | Type | Configuration |
|---|---|---|
| Expense ID | Unique ID | Prefix: `EXP-` |
| Description | Title | (rename default Name) |
| Amount MXN | Number | |
| Amount USD | Number | |
| Category | Select | Options: Item cost, Repair, Supplies, Transport, Fees, Other |
| Date | Date | |
| Related item | Relation | → Items database (set up in 1.5.5) |
| Receipt | Files & media | |

- [ ] **Step 3: Verify Expenses DB exists with 7 properties (Related item to come)**

### Task 1.5.4: Create the Sources database

- [ ] **Step 1: Create a new database called `Sources`**

- [ ] **Step 2: Add properties**

| Property name | Type | Configuration |
|---|---|---|
| Source name | Title | (rename default Name) |
| Type | Select | Options: Market, Vendor, Online, Gift, Found |
| Notes | Text | |

(Rollups added in Task 1.5.6.)

- [ ] **Step 3: Verify Sources DB exists with 3 properties**

### Task 1.5.5: Wire up relations between databases

- [ ] **Step 1: On Sales → add "Item" relation property**

In Sales, add property "Item" → Relation → choose Items database. Enable "Show on Items" so the reverse relation appears on Items as well (name the reverse: `Sales`).

- [ ] **Step 2: On Expenses → add "Related item" relation property**

In Expenses, add "Related item" → Relation → Items. Show on Items as `Expenses`.

- [ ] **Step 3: On Items → add "Source" relation property**

In Items, add "Source" → Relation → Sources. Show on Sources as `Items sourced`.

- [ ] **Step 4: Verify**

Open Items. Confirm three new relation columns visible: `Sales`, `Expenses`, `Source`. Each shows blank values (correct — no data yet).

### Task 1.5.6: Add formulas and rollups

- [ ] **Step 1: On Items → add rollup "Total expenses MXN"**

Rollup → relation: `Expenses` → property: `Amount MXN` → calculate: `Sum`. Empty cells default to 0.

- [ ] **Step 2: On Items → add formula "Profit MXN"**

Formula:

```
if(empty(prop("Sale price MXN")), 0,
   prop("Sale price MXN")
   - prop("Purchase price MXN")
   - prop("Total expenses MXN"))
```

(Adapt to Notion's current formula syntax — Notion has migrated to a newer expression form recently; check what works in the UI. The intent is: if not sold, profit shows 0; if sold, profit = sale − purchase − all expenses.)

- [ ] **Step 3: On Sources → add rollup "Items sourced (count)"**

Rollup → relation: `Items sourced` → calculate: `Count all`.

- [ ] **Step 4: On Sources → add rollup "Avg profit MXN"**

Rollup → relation: `Items sourced` → property: `Profit MXN` → calculate: `Average`. Only meaningful once items have sold.

- [ ] **Step 5: Verify**

Add one dummy Item with sale_price_mxn = 1000, purchase_price_mxn = 400, and one related Expense with Amount MXN = 100. Confirm:
- Items.Total expenses MXN shows 100
- Items.Profit MXN shows 500
- Sources rollups behave sensibly when you assign this dummy Item to a dummy Source

Delete the dummy records after verifying.

### Task 1.5.7: Create the named views on Items

- [ ] **Step 1: View "By status" — Board view**

New view → Board. Group by `Status`. This becomes the default operational view.

- [ ] **Step 2: View "Stale listings" — Table view with filter**

New view → Table. Filter: `Status` is `Listed` AND `Date listed` is more than `14` days ago.

- [ ] **Step 3: View "Missing data" — Table view**

New view → Table. Filter: (`Status` is `Listed` OR `Sold`) AND (`Photos` is empty OR `Category` is empty OR `Purchase price MXN` is empty).

- [ ] **Step 4: View "This month's sales"**

New view → Table. Filter: `Date sold` is within `This month`. Sort: `Date sold` descending.

- [ ] **Step 5: View "Profit ranking"**

New view → Table. Sort: `Profit MXN` descending. Filter: `Status` is `Sold`.

- [ ] **Step 6: View on Sources "Source quality"**

On the Sources database, new view → Table. Sort: `Avg profit MXN` descending.

### Task 1.5.8: Ruthless migration of existing data

**Mindset:** quality over completeness. Anything that's currently active inventory in her chaotic list gets a clean record in Items. Anything that's stale/untracked/unclear is **archived, not migrated**.

- [ ] **Step 1: Open the existing chaotic list side-by-side with the new Items DB**

- [ ] **Step 2: Identify active items**

These are items that meet ALL of:
- Physically in her possession or recently sold (last 60 days)
- She can identify what they are (has a photo OR a clear description)
- Worth tracking going forward

- [ ] **Step 3: For each active item, create a new Items record**

Fill in everything you can identify. Required minimum: Short name, Category, Status, at least one photo. Other fields filled if known; left blank if not.

- [ ] **Step 4: Archive (don't delete) the old list**

In the old list, rename it to `_archive — old inventory (pre-migration 2026-05-25)` and move it to a top-level "Archive" page in the workspace. Do not delete. It's a safety net.

- [ ] **Step 5: Verify**

Items database now has at least 10 records (or however many active items she actually has). The old list is archived but accessible.

### Task 1.5.9: Capture schema details for `notion_schema.md`

**Why:** Phase 2's business context file references specific Notion field names. Hermes uses the Notion API which often needs database IDs (not just names).

- [ ] **Step 1: Capture the Notion database IDs**

For each of the 4 databases, open it as a full page, copy the URL. The database ID is the 32-character hex string in the URL path (between the workspace and the `?v=...`).

Record:

```
Items DB ID:    <id>
Sales DB ID:    <id>
Expenses DB ID: <id>
Sources DB ID:  <id>
```

- [ ] **Step 2: Screenshot one fully-populated Items record**

Save the screenshot. It'll be the visual reference when filling in `notion_schema.md` in Task 2.2.

- [ ] **Step 3: Verify Notion integration access**

The Hermes Notion integration must have access to the new databases. In Notion: open each new database → ⋯ menu → Connections → ensure the Hermes integration is connected. (If it isn't, click "Add connections" and select it.)

Repeat for all 4 databases.

---

## Phase 2 — Business context (the brain transplant)

### Task 2.1: Create `business_context/SOUL.md`

**Files:**
- Create: `business_context/SOUL.md`

**Why SOUL.md:** Per upstream Hermes (resolved in Task 0.1), `${HERMES_HOME}/SOUL.md` is auto-loaded as the global personality on every conversation. No config flag or include line needed.

- [ ] **Step 1: Create the file with this content**

```markdown
You are the ops assistant for Raw Valued, a vintage and found-objects
design studio in Mexico City. The founder, Ashley, runs sourcing,
styling, and sales; you help her stay organized, do the math, and keep
Notion clean.

# Reference docs

Operational reference material lives at ${HERMES_HOME}/business_context/.
Read these files (use your file-reading tool) when their topic comes up:
- notion_schema.md — exact Notion field names + database IDs.
  Read before any Notion read/write to avoid invented fields.
- photo_workflow.md — how to respond when Ashley sends a photo.
  Read on every photo message.
- digest_format.md — the morning digest template (used by cron jobs).

# Operating rules
- Notion is the single source of truth. Never invent fields. If a field
  is ambiguous, ask before writing.
- Do financial math yourself. Never route through Excel or Sheets.
- When you're missing a critical field (purchase price, category,
  status), ask for it before logging.

# Language
- Reply to Ashley in English (she's learning Spanish).
- When drafting customer-facing copy — Instagram captions, FB Marketplace
  listings, buyer messages, search keywords — write in Spanish. Her CDMX
  audience is Spanish-speaking.
- Spanish object terms (mecedora, butaca, taburete, vitrolero) are
  welcome inline anywhere they're the more natural word. Don't translate
  Spanish proper nouns or brand names.
- If she asks "translate this" or "how do I say X," answer directly
  without switching the rest of the conversation to Spanish.

# The business
- Eight product categories: Art, Details, Glassware, Lighting, Rugs,
  Seating, Storage, Tables. Confirm category if unsure.
- Typical price band: $45–$350 USD. Anything outside is worth flagging.
- Local pickup/delivery in CDMX only — default any listing draft to that.

# Profit formula
profit (MXN) = sale_price_mxn − purchase_price_mxn − total_related_expenses_mxn
where total_related_expenses includes repairs, supplies, transport, and
platform fees logged against the item.
Show your work briefly when reporting profit, and always quote profit
in MXN (her actual cash flow).

# Voice
Refined, warm, concise. Match the brand: "layered, personal, refined."
Short replies for quick logging. Longer ones only for digests or drafts.
Warmth is welcome but skip cheesy or cliché pep talks.

# Notion hygiene
- Before creating a new Item, search for similar entries (same category +
  similar short name + recent date). If found, ask if this is the same
  item being re-photographed or a true duplicate.
- Fill every field you can infer from her message. Ask for missing
  required fields (category, purchase price, source) before writing.
- If she mentions a sale in passing ("I sold the brass lamp yesterday
  for $180"), offer to create the corresponding Sales record AND update
  the Item's status/sale price/date sold in one go.
- Sources field is low-friction: if she says "found this at Lagunilla,"
  look up the existing Lagunilla Source and link it. Only create a new
  Source if it doesn't exist.
- Use the established multi-select vocabularies for Materials and
  Listing platforms. If a new term is needed, ask: "I don't see 'cane'
  in your Materials list — should I add it as a new option?"
- For prices: she may give either MXN or USD. Use a current FX rate
  (cached daily, source: api.frankfurter.app) to auto-fill the other
  currency. Always show the conversion before writing so she can correct.
```

- [ ] **Step 2: Commit**

```bash
git add business_context/SOUL.md
git commit -m "feat: add Raw Valued SOUL.md (Hermes system prompt)"
```

### Task 2.2: Create `business_context/notion_schema.md` from the captured details

**Files:**
- Create: `business_context/notion_schema.md`

- [ ] **Step 1: Create the file**

Use the IDs and field names captured in Task 1.5.9. Template:

```markdown
# Notion schema — Raw Valued workspace

Source of truth for Hermes when reading or writing Notion records.

## Database IDs

- Items:    `<paste Items DB ID>`
- Sales:    `<paste Sales DB ID>`
- Expenses: `<paste Expenses DB ID>`
- Sources:  `<paste Sources DB ID>`

## Items database

Fields (exact property names — case and spacing matter):

| Property | Type | Required at write? |
|---|---|---|
| Item ID | Unique ID (auto) | no — Notion generates |
| Short name | Title | yes |
| Photos | Files & media | not required, but ask if missing |
| Category | Select | yes |
| Era / style | Text | no |
| Materials | Multi-select | no |
| Status | Select | yes — default to "In stock" if unclear |
| Purchase price MXN | Number | yes — at acquisition |
| Purchase price USD | Number | yes — auto-filled from MXN via FX |
| Asking price MXN | Number | yes — at listing |
| Asking price USD | Number | yes — auto-filled |
| Sale price MXN | Number | yes — at sale |
| Sale price USD | Number | yes — auto-filled |
| Date acquired | Date | yes |
| Date listed | Date | yes — at listing |
| Date sold | Date | yes — at sale |
| Listing platforms | Multi-select | yes — at listing |
| Notes | Text | no |
| Source | Relation → Sources | yes |
| Sales | Relation → Sales | auto via Sales records |
| Expenses | Relation → Expenses | auto via Expenses records |
| Total expenses MXN | Rollup (sum) | auto |
| Profit MXN | Formula | auto |

Select options:
- Category: Art / Details / Glassware / Lighting / Rugs / Seating / Storage / Tables
- Status: Sourcing / In stock / Listed / Sold / Held
- Materials (multi): wood, metal, glass, velvet, rattan, brass, leather, ceramic, cane, fabric, marble
- Listing platforms (multi): FB Marketplace, Instagram, Chairish, In-person, Website

## Sales database

| Property | Type |
|---|---|
| Sale ID | Unique ID |
| Buyer name | Title |
| Item | Relation → Items |
| Sale price MXN | Number |
| Sale price USD | Number |
| Platform | Select (FB Marketplace, Instagram, Chairish, In-person, Website, Other) |
| Sale date | Date |
| Delivery method | Select (Pickup, Delivery, In-person, Shipping) |
| Notes | Text |

## Expenses database

| Property | Type |
|---|---|
| Expense ID | Unique ID |
| Description | Title |
| Amount MXN | Number |
| Amount USD | Number |
| Category | Select (Item cost, Repair, Supplies, Transport, Fees, Other) |
| Date | Date |
| Related item | Relation → Items |
| Receipt | Files & media |

## Sources database

| Property | Type |
|---|---|
| Source name | Title |
| Type | Select (Market, Vendor, Online, Gift, Found) |
| Notes | Text |
| Items sourced | Relation → Items (reverse) |
| Items sourced (count) | Rollup |
| Avg profit MXN | Rollup (avg of Items.Profit MXN) |

## Standard query patterns

When asked "what's selling well this month," query Items filtered by
Status=Sold AND Date sold within the current month, sorted by Profit MXN
desc.

When asked "what's stale," query Items filtered by Status=Listed AND
Date listed > 14 days ago.

When asked to "log a new item," create a new Items row with as many
fields as possible filled from the user's message. Ask for any required
fields (see "Required at write?" column above) that aren't provided.
```

- [ ] **Step 2: Commit**

```bash
git add business_context/notion_schema.md
git commit -m "feat: add Notion schema reference for Hermes"
```

### Task 2.3: Create `business_context/photo_workflow.md`

**Files:**
- Create: `business_context/photo_workflow.md`

- [ ] **Step 1: Create the file**

```markdown
# Photo workflow

When Ashley sends one or more photos (with or without text):

1. **Use accompanying text first.** If she wrote "found at Lagunilla,
   $300," don't re-ask.

2. **Multiple photos in one Telegram media group = one item.** Treat
   them together — don't create separate records.

3. **Compose ONE reply with these parts, in this order:**

   - **ITEM ID — English working notes**: category (one of the 8),
     likely era/style, materials, visible condition signals. 2–3
     sentences max.

   - **PRICE BAND — $X–$Y MXN** (and $X–$Y USD): a range, never a single
     point. Include one-line reasoning anchored in either (a) past sold
     comps from Items DB (`Status=Sold`, same category, same era if
     possible) or (b) the $45–$350 USD category norm. Use the FX rate
     for the dual quote.

   - **📸 IG caption (Spanish, brand voice, refined)**: 1–3 short lines.
     Brand voice cues: layered, personal, refined. Use Spanish object
     vocabulary inline (mecedora, butaca, taburete, etc.).

   - **🛒 FB Marketplace listing line (Spanish, search-optimized)**: one
     line, the keywords a CDMX vintage shopper would actually search.

4. **Ask for purchase price** if not provided.

5. **Ask for sourcing location** if not in her text (extract if
   present — e.g., "Lagunilla" → look up existing Source).

6. **Wait for confirmation** before writing to Notion. Accept "yes",
   "log it", "👍", "yep but price is $1200" (apply the override), etc.

7. **After writing, return the Notion record URL** so she can tweak the
   record directly.

## Price band honesty

- Visible damage → suggest the low end of the band.
- Excellent condition + sought-after style → suggest the high end.
- Unknown era → widen the band and say "I'd narrow this once you
  confirm what era it is."

## Currency in the band

Always show both: `$X–$Y MXN ($A–$B USD)`. Use the cached daily FX rate.
```

- [ ] **Step 2: Commit**

```bash
git add business_context/photo_workflow.md
git commit -m "feat: add photo workflow rules"
```

### Task 2.4: Create `business_context/digest_format.md`

**Files:**
- Create: `business_context/digest_format.md`

- [ ] **Step 1: Create the file**

```markdown
# Morning digest format

Fires at 9:00 CDMX daily, routed via `TELEGRAM_HOME_CHANNEL` to the
group chat (Fede + Ashley + bot).

## The prompt that runs at cron time

```
You are generating Ashley's morning briefing for Raw Valued.

Step 1 — Read the Notion Items database. You MUST do this before writing
anything.

Step 2 — Compose the briefing using ONLY facts from what you read.

Required sections (in this order):
1. One-line greeting (warm, brief, no cheese).
2. Sales yesterday: list items sold (Items where Date sold = yesterday)
   with name + sale price MXN + profit MXN. Or: "No sales logged yesterday."
3. Inventory needing attention:
   - Stale (Status=Listed AND Date listed > 14 days ago): list by name
   - Missing photos (Status ∈ {Listed, Sold} AND Photos empty)
   - Missing price (Status=Listed AND Asking price MXN empty)
4. Numbers:
   - Items sold this week: count
   - Items sold MTD: count
   - Revenue MTD MXN (sum of Sale price MXN for sales this month)
   - Profit MTD MXN (sum of Profit MXN for sales this month)
   - Avg days-to-sell, last 10 sold: (Date sold − Date listed) average
5. Today's focus: 1–3 SPECIFIC actions drawn from sections 2–4. E.g.:
   "Re-photograph the cobra lamp — listed 18 days, no photo."

RULES:
- No generic sourcing tips. No "search for vintage pendant lamps" unless
  the data shows lighting is her best-selling category AND she's
  currently out of it.
- No cliché pep talks. Warmth is fine; cheese is not.
- If Notion is unreachable, send ONLY: "Couldn't reach Notion this
  morning, will retry tomorrow." Nothing else.
- Reply in English. Keep it under 120 words on a quiet day.
- Address Ashley by name; address the group as "Ashley & Fede" only
  if you have something specifically for Fede.
```
```

- [ ] **Step 2: Commit**

```bash
git add business_context/digest_format.md
git commit -m "feat: add morning digest format"
```

### Task 2.5: Update `entrypoint.sh` to seed Hermes context files on boot

**Files:**
- Modify: `scripts/entrypoint.sh`
- Modify: `Dockerfile`

**Seeding model:** `SOUL.md` goes to `${HERMES_HOME}/SOUL.md` (Hermes auto-loads it from there). The three reference docs go to `${HERMES_HOME}/business_context/` (read by Hermes on-demand via tool calls). All copies use `cp -n` (no-clobber) so on-volume edits persist across redeploys.

- [ ] **Step 1: Find this line in `scripts/entrypoint.sh` (around line 13)**

```bash
mkdir -p "${HERMES_HOME}" "${HERMES_HOME}/logs" "${HERMES_HOME}/sessions" "${HERMES_HOME}/cron" "${HERMES_HOME}/pairing" "${DEFAULT_TERMINAL_CWD}"
```

Add the business_context subdir below it:

```bash
mkdir -p "${HERMES_HOME}" "${HERMES_HOME}/logs" "${HERMES_HOME}/sessions" "${HERMES_HOME}/cron" "${HERMES_HOME}/pairing" "${DEFAULT_TERMINAL_CWD}"
mkdir -p "${HERMES_HOME}/business_context"
```

- [ ] **Step 2: Add the seeding block before the final `exec hermes gateway` line**

Find:

```bash
echo "[bootstrap] Starting Hermes gateway..."
unset MESSAGING_CWD
exec hermes gateway
```

Insert this block before it:

```bash
# Seed Hermes context files on first boot (cp -n preserves volume edits)
if [[ -d /app/business_context ]]; then
  echo "[bootstrap] Seeding Hermes context (no-clobber)..."
  # SOUL.md goes to HERMES_HOME root — auto-loaded by Hermes
  if [[ -f /app/business_context/SOUL.md ]]; then
    cp -n /app/business_context/SOUL.md "${HERMES_HOME}/SOUL.md" 2>/dev/null || true
  fi
  # Reference docs go to HERMES_HOME/business_context — read on-demand
  for f in /app/business_context/*.md; do
    base="$(basename "$f")"
    [[ "$base" == "SOUL.md" ]] && continue
    cp -n "$f" "${HERMES_HOME}/business_context/${base}" 2>/dev/null || true
  done
fi

echo "[bootstrap] Starting Hermes gateway..."
unset MESSAGING_CWD
exec hermes gateway
```

- [ ] **Step 3: Update Dockerfile to copy `business_context/` into the image**

In Dockerfile runtime stage, find:

```dockerfile
WORKDIR /app
COPY scripts/entrypoint.sh /app/scripts/entrypoint.sh
RUN chmod +x /app/scripts/entrypoint.sh
```

Change to:

```dockerfile
WORKDIR /app
COPY scripts/entrypoint.sh /app/scripts/entrypoint.sh
COPY business_context /app/business_context
RUN chmod +x /app/scripts/entrypoint.sh
```

- [ ] **Step 4: Commit**

```bash
git add scripts/entrypoint.sh Dockerfile
git commit -m "feat: seed SOUL.md + business_context onto volume on boot

SOUL.md lands at HERMES_HOME root where Hermes auto-loads it as the
global personality. notion_schema.md / photo_workflow.md /
digest_format.md land in HERMES_HOME/business_context/ where Hermes
reads them on demand via tool calls. cp -n preserves on-volume edits."
```

### Task 2.6: Verify SOUL.md auto-loading

**Why simplified:** Task 0.1 confirmed Hermes auto-loads `${HERMES_HOME}/SOUL.md` from the volume — no config flag, env var, or include file needed. This task is now just verification.

- [ ] **Step 1: SSH into Railway and verify SOUL.md exists**

```bash
railway ssh
ls -la "${HERMES_HOME}/SOUL.md"
head -20 "${HERMES_HOME}/SOUL.md"
```

Expected: file exists, content matches `business_context/SOUL.md` from the repo.

- [ ] **Step 2: Verify Hermes loaded it**

In the bot DM, send: `What is your operating brief?`

Expected: response references "Raw Valued ops assistant" and the contents of SOUL.md. If response is generic, SOUL.md wasn't loaded — check (a) file is at the right path, (b) container was restarted after seeding, (c) `HERMES_MD_NAMES` env var hasn't been overridden.

### Task 2.7: Deploy and verify Phase 2

- [ ] **Step 1: Push to fork**

```bash
git push origin <branch>
```

- [ ] **Step 2: Watch Railway redeploy logs**

Expected:
- `[bootstrap] Seeding business_context files (no-clobber)...` appears
- `[bootstrap] Starting Hermes gateway...` follows
- Gateway connects to Telegram successfully

- [ ] **Step 3: SSH and verify file presence**

```bash
railway ssh
ls -la "${HERMES_HOME}/business_context/"
```

Expected: 4 .md files present.

- [ ] **Step 4: Test that the bot now knows the business**

In the bot DM, send:

```
What's my profit formula?
```

Expected reply references: `sale_price_mxn − purchase_price_mxn − total_related_expenses_mxn`, mentions MXN as the reporting currency.

Then:

```
What categories do I sell?
```

Expected reply lists exactly: Art, Details, Glassware, Lighting, Rugs, Seating, Storage, Tables.

If either reply is generic or misses the specifics, the system prompt isn't being loaded — re-check Task 2.6.

- [ ] **Step 5: Verify hygiene behavior**

Send:

```
Log a new item: green velvet chair
```

Expected: bot asks for category (if not obvious from name), purchase price, and source — not just a one-shot "logged it." If it auto-writes, the hygiene rules aren't being followed.

---

## Phase 3 — Photo workflow

No new files. This phase exercises the photo_workflow.md rules already deployed in Phase 2.

### Task 3.1: Send a test photo without context

- [ ] **Step 1: Pick a real item from Ashley's current inventory and send its photo to the bot DM**

No accompanying text.

- [ ] **Step 2: Verify the reply structure**

Expected sections in the reply, in order:
- ITEM ID — English working notes (category + era/style + materials + condition)
- PRICE BAND — `$X–$Y MXN ($A–$B USD)` with one-line reasoning
- 📸 IG caption (Spanish)
- 🛒 FB Marketplace listing line (Spanish)
- Follow-up question asking for purchase price
- Follow-up question asking for sourcing location

- [ ] **Step 3: Reply with purchase price + source**

Example: `$1200 MXN, found at Lagunilla`

- [ ] **Step 4: Verify the bot offers to log to Notion (does NOT auto-log)**

Expected: a clear confirmation prompt like "Log this to Notion?" — should NOT write immediately.

- [ ] **Step 5: Confirm and verify the Notion record**

Reply `yes` (or `log it`, `👍`). The bot should write to Notion and return the record URL.

Click the URL. Verify in Notion:
- Item created with correct category, materials, photos
- Purchase price MXN populated; USD auto-filled
- Source field linked to "Lagunilla" (or new Source if it didn't exist)
- Status defaulted appropriately

### Task 3.2: Send a photo WITH context

- [ ] **Step 1: Send a photo with text**

Example: `Got this teal lamp at Tianguis del Chopo for 350 pesos`

- [ ] **Step 2: Verify the bot does NOT re-ask for purchase price or source**

It already has both. The reply should still produce all the working notes / captions / listing copy but skip the redundant questions.

- [ ] **Step 3: Confirm + check Notion**

Verify the record reflects what was in her text.

### Task 3.3: Send a Telegram media group (multiple photos of one item)

- [ ] **Step 1: From the camera roll, select 3–5 photos of the same item and send as one Telegram message (media group)**

- [ ] **Step 2: Verify ONE reply, ONE Notion record**

Expected: a single reply analyzing the item across all photos. Crucially: only one record created in Notion (not 3–5 duplicates).

---

## Phase 4 — Digest replacement

### Task 4.1: List existing cron entries

- [ ] **Step 1: SSH and inspect**

Use the mechanism resolved in Task 0.3. Likely either:

```bash
ls "${HERMES_HOME}/cron/"
```

or:

```bash
hermes cron list
```

- [ ] **Step 2: Identify the morning briefing entry**

You're looking for the entry that produces the "Buenos dias Fede & Ashley! ☀️" output. Note its name/ID.

### Task 4.2: Replace the morning briefing prompt

- [ ] **Step 1: Modify the existing cron entry**

Use the mechanism from Task 0.3. The new prompt is the one in `business_context/digest_format.md` (the "Step 1 — Read the Notion Items database..." prompt).

If the cron mechanism is file-based, edit the file directly to replace the old prompt with the new one. Keep the same schedule (9am CDMX).

If CLI-based, something like:

```bash
hermes cron update <id> --prompt-file /data/.hermes/business_context/digest_format.md
```

(adapt to actual CLI).

- [ ] **Step 2: Verify the schedule is 9am CDMX**

Re-read the entry after editing. Confirm the cron expression resolves to 09:00 local time.

### Task 4.3: Trigger the digest manually and verify

- [ ] **Step 1: Run the cron entry on-demand**

Use the mechanism from Task 0.3 (likely `hermes cron run <id>` or similar).

- [ ] **Step 2: Verify the message lands in the group chat (not Fede's DM)**

- [ ] **Step 3: Verify the message content**

Acceptance criteria:
- References real item names from her Items DB (or honestly says "no sales logged yesterday")
- Numbers are real — open Notion and spot-check at least one number
- No generic sourcing tips ("vintage pendant lamps are underpriced") unless data-backed
- Under ~120 words on a quiet day
- No cheesy pep talks

If the digest still generates generic fluff, the prompt didn't fully replace OR the bot isn't actually reading Notion before composing. Re-check both.

### Task 4.4: Let it fire naturally tomorrow morning

- [ ] **Step 1: Wait until 9am CDMX the next day**

- [ ] **Step 2: Verify the digest arrives at 9am CDMX local (not 9am UTC)**

If it arrives at 3am or 4pm, the TZ fix from Task 1.4 didn't take effect — investigate.

---

## Phase 5 — Reminders

This phase exercises the reminder capability that the system prompt enables. The mechanism is Hermes cron entries created on the fly from natural language.

### Task 5.1: One-shot reminder

- [ ] **Step 1: Send to bot DM**

```
Remind me 2 minutes from now to confirm reminders work
```

- [ ] **Step 2: Verify the bot confirms back**

Expected reply: "Set. <date> <time CDMX> — Confirm reminders work. Reply 'cancel' to remove it." (or similar)

- [ ] **Step 3: Wait 2 minutes**

- [ ] **Step 4: Verify the reminder fires in the group chat**

If it fires in the DM instead of the group, the routing for cron-triggered messages still needs work — re-check `TELEGRAM_HOME_CHANNEL`.

- [ ] **Step 5: Verify it does NOT fire again 2 minutes later**

One-shots should self-delete after firing. Wait a few minutes and confirm no duplicate.

### Task 5.2: Conditional reminder

- [ ] **Step 1: Pick a real Items record with Status=Listed.**

Note its Short name.

- [ ] **Step 2: Send to bot DM**

```
Remind me 3 minutes from now to drop the price on the <short name> if it
hasn't sold.
```

- [ ] **Step 3: Verify the bot's confirmation acknowledges the condition**

The reply should mention something like "fires only if status is still Listed."

- [ ] **Step 4: Wait, confirm it fires**

Expected: reminder fires in group with the conditional logic explained.

- [ ] **Step 5 (optional): Test the negative path**

Mark the item Sold in Notion. Set a new conditional reminder. Verify it does NOT fire (or fires with a "skipping — already sold" note).

### Task 5.3: Recurring reminder

- [ ] **Step 1: Send to bot DM**

```
Every Monday at 9am, remind me to do an inventory walk-through.
```

- [ ] **Step 2: Verify the bot confirms recurrence**

Expected confirmation explicitly mentions "every Monday".

- [ ] **Step 3: Verify entry exists**

SSH and list cron entries. The new entry should be present and not flagged as self-deleting.

### Task 5.4: List and cancel

- [ ] **Step 1: Send to bot DM**

```
What reminders do I have set?
```

Expected: plain-English list of active reminders (e.g., "Every Monday at 9am — inventory walk-through.")

- [ ] **Step 2: Cancel one**

```
Cancel the Monday inventory reminder.
```

Expected: confirmation of cancellation.

- [ ] **Step 3: Verify it's gone**

Re-ask "what reminders do I have set?" — the cancelled entry should no longer appear.

---

## Final acceptance

- [ ] **Use the bot in normal operation for one week**

Don't add features during this week. Just watch how it behaves.

- [ ] **At end of week, audit:**

- Did the morning digest cause Ashley to take at least one action she wouldn't have taken otherwise?
- Did the photo workflow save her from writing IG/FB copy from scratch?
- Did she set at least one reminder organically (without you prompting her)?
- Did she encounter any tool-progress trace in chat? (Should be zero.)
- Did she mention Excel? (Should be zero.)
- Did Notion records grow with consistent schema, or did drift creep back in?

- [ ] **Commit a one-line acceptance note to the spec**

```bash
git add docs/superpowers/specs/2026-05-25-hermes-rawvalued-enhancements-design.md
git commit -m "docs(spec): mark Hermes enhancements accepted after 1-week trial"
```
