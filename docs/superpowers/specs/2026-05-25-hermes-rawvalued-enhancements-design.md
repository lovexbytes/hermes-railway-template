# Hermes Agent Enhancements for Raw Valued

**Date:** 2026-05-25
**Author:** Fede (igutierrezp)
**Owner / End user:** Ashley
**Repo:** Fork of `lovexbytes/hermes-railway-template` (currently identical to upstream)

---

## Context

Raw Valued is Ashley's vintage and found-objects design studio in Mexico City. She uses a Hermes agent (deployed on Railway, accessed via Telegram) as an ops assistant — primarily to manage inventory in a Notion database and to caption product photos.

The current setup works but feels limited:

- It's effectively just a Notion writer with a captioning feature.
- It is reactive only — no proactive surfacing of stale listings, missing data, or actionable summaries.
- An attempt to use it for P&L work via Excel keeps failing because the Excel integration's auth token expires.
- The existing morning briefing is generic LLM fluff ("vintage pendant lamps are underpriced") with no grounding in Ashley's actual inventory data.
- Tool-call traces (`🔍 session_search: recall…`) leak into the Telegram chat, creating noise for a non-technical user.
- The briefing is also routed to Fede instead of Ashley.

This spec describes a set of targeted enhancements that turn the bot into a useful proactive ops assistant for the product side of Raw Valued, while keeping the fork as thin as possible to minimize maintenance burden.

## Scope

**In scope:**
- Business-context system prompt seeded into Hermes on container boot
- Replacement of generic morning digest with a data-grounded one
- Enriched photo workflow (multi-part reply: category, price band, IG caption, FB listing)
- Lightweight natural-language reminders
- UX fixes: suppress tool-call noise, fix routing, fix timezone
- **Target Notion schema** (four linked databases: Items, Sales, Expenses, Sources) with dual MXN/USD currency tracking
- **Hermes ongoing hygiene behaviors** to prevent schema drift and duplicate records

**Explicitly out of scope:**
- Styling/sourcing client-services side of the business (products only)
- New external integrations beyond what Hermes already supports (no email pipeline, no FireCrawl scraping, no Google Sheets, no calendar)
- Image processing or auto-posting
- Forking the upstream `NousResearch/hermes-agent` repo (only the Railway template fork is modified)
- **Bulk migration of existing Notion records** into the new schema — handled separately as a one-time data-entry session, not part of the code rollout

## Philosophy: thin fork, fat volume

The single guiding principle for this design is: **minimize what lives in the fork's code; maximize what lives as data on the Railway volume.** Every line added to the fork must be reconciled later if upstream `lovexbytes` changes. Every markdown prompt or cron entry on the volume can be edited freely without touching the repo.

Estimated repo footprint when complete: one new `business_context/` folder (~4 files), ~10 lines added to `entrypoint.sh`, one line added to `Dockerfile` (TZ), one small seeding script. No new dependencies, no upstream Hermes patches.

## Architecture

```
igutierrezp/hermes-railway-template (the fork)
├── Dockerfile                  (+ ENV TZ=America/Mexico_City)
├── scripts/
│   └── entrypoint.sh           (+ seed business_context on boot)
├── business_context/           (NEW)
│   ├── system.md               (the brain — loaded as Hermes system prompt)
│   ├── notion_schema.md        (Notion field reference, filled by Fede from a screenshot)
│   ├── photo_workflow.md       (rules for photo replies)
│   └── digest_format.md        (template for the morning briefing)
└── (rest unchanged)
```

The existing digest cron entry is updated in-place via Hermes CLI during rollout (Phase 4), so no in-repo cron-seeding script is needed.

At container boot, `entrypoint.sh` copies `business_context/*.md` into `${HERMES_HOME}/business_context/` using `cp -n` (no-clobber), so:
- First boot after deploy: files seed into the volume.
- Future boots: if Ashley or Fede edited a copy on the volume, the redeploy doesn't overwrite their edits.
- New files added in a future deploy: seed alongside existing ones without disruption.

Hermes' actual system-prompt file (exact path to be verified during planning against the upstream `NousResearch/hermes-agent` source) gets one line: `Load and follow ${HERMES_HOME}/business_context/system.md as your operating brief.`

## Component 1: Business context

Four markdown files seeded into `${HERMES_HOME}/business_context/`.

### `system.md` — the brain

```
You are the ops assistant for Raw Valued, a vintage and found-objects
design studio in Mexico City. The founder, Ashley, runs sourcing,
styling, and sales; you help her stay organized, do the math, and keep
Notion clean.

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
- Typical price band: $45–$350. Anything outside is worth flagging.
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
```

### `notion_schema.md` — Notion field reference

Templated file with TODOs Fede fills in from one Notion screenshot. Contains exact field names and types so the bot stops guessing. Bot reads this on every Notion write/read.

### `photo_workflow.md` — photo reply rules

```
When Ashley sends a photo (alone or with text):

1. Use accompanying text first. If she wrote "found at Lagunilla, $300,"
   don't re-ask.
2. If multiple photos arrive in one Telegram media group, treat as one
   item — not separate records.
3. Compose ONE reply with these parts:
   - ITEM ID — English working notes: category, likely era/style,
     materials, visible condition signals
   - PRICE BAND — $X–$Y (a range, never a point) + one-line reasoning
     anchored in either past sold comps from Notion or the $45–$350
     category norm
   - IG caption (Spanish, brand voice, refined)
   - FB Marketplace listing line (Spanish, search-optimized)
4. Ask for purchase price if missing.
5. Ask for sourcing location if missing in her text (extract if present).
6. Wait for confirmation before writing to Notion. Accept "yes", "log it",
   "👍", "yep but price is $1200", etc.
7. After writing, return the Notion record URL.

Honesty about price uncertainty:
- Visible damage → suggest the low end of the band
- Excellent condition + sought-after style → suggest the high end
- Unknown style → widen the band and say "I'd narrow this once you
  confirm what era it is"
```

### `digest_format.md` — morning briefing template

Defines the structure for the 9am digest. See Component 2 for the full prompt.

## Component 2: Morning digest

### Routing

`TELEGRAM_HOME_CHANNEL` is set (in Railway env vars) to the chat ID of a new 3-person Telegram group (Fede + Ashley + bot). All scheduled messages route there. Individual DMs to the bot continue to work normally for one-on-one logging.

### Timing

Fires daily at **9am CDMX**, configured as a Hermes cron entry. CDMX time is correctly interpreted because of the container TZ fix (Component 5).

### The prompt that runs at cron time

The current generative prompt ("write a morning briefing with a deal tip, quick win, pep talk") is **replaced** by a reporting prompt that mandates reading Notion before writing anything:

```
You are generating Ashley's morning briefing for Raw Valued.

Step 1 — Read the Notion inventory database. You MUST do this before
writing anything.

Step 2 — Compose the briefing using ONLY facts from what you read.

Required sections:
- Sales yesterday (or "no sales logged yesterday")
- Inventory needing attention: list specific items by name that are
  (a) listed >14 days with no sale, (b) missing photos, (c) missing
  price
- Numbers: items sold this week / MTD; revenue MTD; profit MTD; avg
  days-to-sell (last 10 sold items)
- Today's focus: 1–3 SPECIFIC actions drawn from the above
  (e.g., "re-photograph the cobra lamp — listed 18 days, no photo")

RULES:
- No generic sourcing tips. No "search for vintage pendant lamps"
  unless you've confirmed from data that lighting is her best-selling
  category AND she's currently out of it.
- No cliché pep talks. Warmth is fine; cheese is not.
- If Notion is unreachable, send one sentence: "Couldn't reach Notion
  this morning, will retry tomorrow." Nothing else.
- Reply in English. Keep it under 120 words on a quiet day.
```

### Failure modes designed in

- **Notion down / rate-limited:** one-line graceful message, retry next day.
- **No activity yesterday:** digest still sends ("Quiet day. 3 items still stale."). Provides heartbeat so Ashley trusts the system is alive.
- **First few days post-install:** trailing one-line note that numbers will become meaningful after a week of activity.

### What's explicitly NOT included

- Weekly or monthly digests (YAGNI — nail daily first; revisit later if she wants it).
- Sales / sourcing tips without data grounding.

## Component 3: Enriched photo workflow

Logic and behavior live in `photo_workflow.md` (see Component 1). No code change required beyond the seeding step — this component is a pure prompt change.

Key behavioral change vs. current: the bot **waits for confirmation** before writing to Notion (current behavior auto-writes). Reasoning: the enhanced reply now includes a *suggested price*, and committing a wrong price is a worse failure mode than waiting one extra message. Confirmation must be tolerant of natural variants ("yes", "log it", "👍", "yep but price $1200").

## Component 4: Reminders

Mechanism: Hermes' native cron entries (prompts that fire at a schedule). The bot translates natural-language reminder requests into cron entries and back.

Three shapes:
- **Plain ping** — fires at a moment in time
- **Conditional ping** — checks Notion at fire time, only pings if condition still true
- **Recurring ping** — repeats on a schedule

Lifecycle:
- One-shot reminders self-delete after firing
- Recurring reminders persist until cancelled
- "List my reminders" reads the cron dir and returns plain-English list
- "Cancel X" removes the matching entry

Defaults:
- 9am CDMX if no time specified (same as digest)

## Component 5: UX & infrastructure fixes

Three small but critical changes:

| # | Change | Location | Reason |
|---|---|---|---|
| 5a | `HERMES_TOOL_PROGRESS=false` (exact value TBD) | Railway env var | Suppresses tool-call traces leaking into chat |
| 5b | `ENV TZ=America/Mexico_City` (+ ensure `tzdata` installed) | `Dockerfile` runtime stage | Cron interprets times in CDMX, not UTC |
| 5c | `TELEGRAM_HOME_CHANNEL=<group chat ID>` | Railway env var | Scheduled messages reach Ashley, not just Fede |

These three changes together solve the most painful UX problems Ashley currently experiences, independent of any of the other components.

## Rollout plan

Each phase is independently verifiable and revertible. Each commit can be rolled back without affecting later phases (because each phase's verification confirms it works before moving on).

### Phase 0 — Point Railway at the fork (zero code change)

1. SSH into Railway container, snapshot `/data`: `tar czf /tmp/hermes-backup-$(date +%F).tgz /data/.hermes`, `scp` down.
2. In Railway UI, switch the service's GitHub source from `lovexbytes/hermes-railway-template` to `igutierrezp/hermes-railway-template`.
3. Trigger redeploy. Fork is identical to upstream at this point — rebuilds with no behavior change.
4. **Verify:** Ashley sends a message; bot responds.

### Phase 1 — Free UX wins (Component 5)

One commit (the Dockerfile change) plus two Railway env-var settings.

**Verify:** Send a message that requires a tool call — chat is clean of tool traces. Fire the existing morning digest manually — lands in the new group. Set a test reminder for "1 minute from now" — fires at correct CDMX wall-clock time.

### Phase 1.5 — Notion structural redesign (Section 7)

Not a code change — a one-time setup of the new Notion structure. Blocks Phase 2 because the seeded business context references specific field names.

Sub-steps:
1. Create the four databases (Items, Sales, Expenses, Sources) with the schemas in Section 7.
2. Configure select options (Status values, Material vocabulary, Listing platforms, Source types, Expense categories).
3. Set up the views listed in Section 7.
4. Add formulas: Profit MXN, Total expenses rollup, source avg margin rollup.
5. Capture one populated Item record's screenshot to fill `notion_schema.md` with exact field names + Notion property IDs.
6. Bulk migration of existing items into the new schema. Approach: filter the current chaotic list by what's still active inventory, log those into Items; everything else (truly stale, untracked, unclear) gets dropped or archived. **Do not try to migrate everything — be ruthless.** Quality over completeness.

**Target completion:** same day as Phase 1, before Phase 2 begins.

**Verify:** the four databases exist, are populated with at least 10–20 real items, views work, profit formula computes correctly on a sold item.

### Phase 2 — Business context (Component 1)

One commit adding `business_context/`, the seeding step in `entrypoint.sh`, and the include line in Hermes' system-prompt file.

**Verify:** Ask "what's my profit formula?" — references Raw Valued formula. Ask "what categories do I sell?" — lists the eight. Generic message replies feel less generic.

### Phase 3 — Photo workflow (Component 3)

Update `photo_workflow.md`.

**Verify:** Send a photo of a real item — receive a multi-part reply (category, price band, English notes, Spanish IG caption, Spanish FB listing). Bot asks for purchase price and sourcing location before writing.

### Phase 4 — Digest replacement (Component 2)

Find the existing morning-briefing cron entry; replace its prompt with the reporting prompt.

**Verify:** Manually trigger; output references real item names from Notion (or honestly says "no sales logged"); no generic sourcing tips; under ~120 words on quiet days.

### Phase 5 — Reminders (Component 4)

Mostly exercising the cron mechanism through the new system prompt — no new code. Test all three reminder shapes plus list and cancel.

## Definition of done

Ashley uses the bot for one normal week and:
- The morning digest is actually useful (she takes at least one action from it)
- The photo workflow saves her from writing IG/FB copy from scratch
- She sets at least one reminder organically
- She does not see any tool-progress traces in chat
- She does not mention Excel because she doesn't miss it

## Section 7: Target Notion schema + Hermes hygiene behaviors

The current Notion workspace is a single unstructured list mixing inventory, expenses, and source/seller notes. Items are identified by visual recall, not IDs. Sales are not tracked structurally. This makes the morning digest, photo workflow, and conditional reminders all unreliable — they assume a queryable schema that doesn't exist.

This section defines the *target* schema. The actual migration of existing data is handled separately (see Rollout below).

### Four linked databases, all inside the one Raw Valued Notion workspace

**1. Items** — master inventory (one row = one physical thing)

| Field | Type | Notes |
|---|---|---|
| Item ID | auto-ID | e.g., `ITM-001`. Solves the "which green chair?" problem. |
| Short name | text | Ashley's mnemonic. Not used for ID. |
| Photos | files & media | Multiple per item. |
| Category | select | Art / Details / Glassware / Lighting / Rugs / Seating / Storage / Tables. |
| Era / style | text | "60s–70s mid-century mexicano", "art deco", etc. |
| Materials | multi-select | wood / metal / glass / velvet / rattan / brass / leather / ceramic… |
| Status | select | Sourcing → In stock → Listed → Sold → Held (styling). |
| Purchase price MXN | number | What she paid (primary cash-flow currency). |
| Purchase price USD | number | Same, in USD at acquisition time. |
| Asking price MXN | number | |
| Asking price USD | number | |
| Sale price MXN | number | Populated on sale. |
| Sale price USD | number | Same. |
| Date acquired | date | |
| Date listed | date | Drives stale-listing detection. |
| Date sold | date | |
| Source | relation → **Sources** | Where the piece came from. |
| Sales | relation → **Sales** | |
| Expenses | relation → **Expenses** | Repair costs etc. |
| Total expenses MXN | rollup | Sum of ALL related Expenses (MXN), all categories — repair, supplies, transport, fees. |
| Profit MXN | formula | `sale_price_mxn − purchase_price_mxn − total_expenses_mxn`. |
| Listing platforms | multi-select | FB Marketplace / IG / Chairish / In-person / website. |
| Notes | long text | |

Profit is computed in MXN only — that's her actual cash flow. USD prices are for display / international audience signaling, not internal accounting.

**2. Sales** — one row per sale, linked to Item
- Sale ID (auto), Item (relation), Buyer name, Sale price MXN, Sale price USD, Platform, Sale date, Delivery method (pickup/delivery/in-person), Notes.

**3. Expenses** — one row per cost
- Expense ID (auto), Description, Amount MXN, Amount USD, Category (item-cost / repair / supplies / transport / fees / other), Date, Related item (relation, optional), Receipt (file, optional).

**4. Sources** — one row per seller/market (replaces the current ad-hoc sourcing notes)
- Source name (e.g., "Lagunilla", "Don Memo at Tianguis Pino Suárez"), Type (market / vendor / online / gift / found), Notes, Items sourced (rollup count), Avg profit margin (rollup formula).

### Views to set up on Items

- **By status** (default operational view, kanban-style)
- **Stale listings** (filter: status = Listed AND date listed > 14 days ago)
- **Missing data** (filter: status ∈ Listed/Sold AND any required field is empty)
- **This month's sales** (filter by date sold)
- **Profit ranking** (sort by Profit MXN, descending)
- **Source quality** view on Sources DB, sorted by avg margin

### Currency handling (dual MXN + USD)

Both currencies stored per price field. To minimize Ashley's typing burden, Hermes auto-fills the other currency when she gives one:

```
Ashley: just bought the rattan chair for 1800 pesos
Bot:    Logged purchase price MXN 1,800 / USD ~95 at today's rate (≈18.9 MXN/USD).
        Confirm or correct?
```

She confirms or overrides; both fields get stored. The bot uses a live FX rate at log time (cached daily) so historical records aren't corrupted by rate drift.

### Hermes ongoing hygiene behaviors (added to `system.md`)

```
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
  (cached daily) to auto-fill the other currency. Always show the
  conversion before writing so she can correct it.
```

## Open items — resolution log

These were deferred from the design because answering them required reading upstream source. Findings as they're resolved:

1. **Hermes' system-prompt file location (RESOLVED 2026-05-25):** `${HERMES_HOME}/SOUL.md`. Hermes auto-loads this file on startup as the global personality/persona — no config flag required. Per `HERMES_MD_NAMES` env var, default loaded files are `AGENTS.md,CLAUDE.md,.cursorrules,SOUL.md`. We'll write our business context to SOUL.md.

2. **`HERMES_TOOL_PROGRESS` value (RESOLVED 2026-05-25):** Both `HERMES_TOOL_PROGRESS` and `HERMES_TOOL_PROGRESS_MODE` env vars are **deprecated**. Replaced by the `display.tool_progress` field in `${HERMES_HOME}/config.yaml`, valid values: `off | new | all | verbose`. We want `off`. Three ways to set it:
   - Edit `${HERMES_HOME}/config.yaml` directly (preferred since Hermes already manages it)
   - Run `hermes config set display.tool_progress off` via CLI
   - Set deprecated `HERMES_TOOL_PROGRESS=false` — Hermes' migration code auto-converts to `display.tool_progress=off` on next startup (line 3710 of `hermes_cli/config.py`)

3. **Exact mechanism for creating/modifying Hermes cron entries** — to be resolved in Task 0.3 (requires SSH into running container).

4. **Notion DB internal IDs** — captured during Task 1.5.9.

5. **Group chat ID** — captured during Task 1.3 (Fede creates the Telegram group).

6. **FX rate source (RESOLVED 2026-05-25):** `https://api.frankfurter.app/latest?from=USD&to=MXN` — free, no API key, ECB-sourced daily rates. Cached daily on the volume to minimize calls.
