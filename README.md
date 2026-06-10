# Baby Tracker

A family baby tracking web app built with vanilla JS and Supabase. Track feeds, nappy changes, vitamins, pumping sessions, measurements, and vaccines — shared in real time across all family members.

**Live app:** https://rafehjeelani.github.io/baby-tracker/

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Single-page HTML + vanilla JS (no framework) |
| Backend / DB | Supabase (PostgreSQL + Auth + Row Level Security) |
| Hosting | GitHub Pages (auto-deploys on push to `main`) |
| Auth | Supabase email/password + magic link |

---

## Features

### Authentication
- Email/password sign-up and sign-in
- Password reset via email
- Auto-profile creation on first sign-up (trigger on `auth.users`)
- Invite link flow — share a token link, recipient joins your family on sign-in

### Families
- Create a family with one or more babies in a single step (SECURITY DEFINER RPC avoids RLS bootstrapping issues)
- Multiple families per account (switch from the families screen)
- Edit family name (admin only)
- Colour-coded header bar per family — 8 colour themes, saved to Supabase and synced across devices

### Members & Roles
- Roles: **Admin** (creator) and **Member**
- Admins can generate invite links (30-day expiry), remove members, add/delete babies
- Members can view and log data
- Role tags per member: Mother, Father, Grandmother, Grandfather, Aunt, Uncle, Nanny, Other — displayed as coloured chips, saved to `family_members.tag`

### Daily Tab
- Date navigation bar (sticky, always visible while scrolling) with ‹ Today › controls — timezone-safe date arithmetic
- **Glance bar** — scrollable summary chips showing total ml, urine count, potty count, vitamin count, and per-baby ml for the selected day
- **Baby cards** — one card per baby, coloured by their assigned theme
  - Latest feed time shown in the card header (e.g. 🍼 2:30 PM)
  - Summary chips in header: total ml · urine · potty · vitamins
  - Add-entry area pinned at the top of the card (above the log)
  - Entry type pills: 🍼 Milk · 💧 Urine · 💩 Potty · 💊 Vitamin · 🩹 Medicine
  - Custom 12h time picker (hour / minute / AM–PM selects — works correctly on all mobile locales)
  - For milk: **BM** (breast milk) and **FM** (formula milk) multi-select tags — both can be selected for a mixed feed; stored in the `note` field as `"BM"`, `"FM"`, or `"BM+FM"`; displayed as coloured chips in the log
  - Log entries sorted reverse-chronologically (latest first)
  - Inline edit on any log entry — tap ✏️ to edit time, ml, BM/FM tags, or medicine name; saves to Supabase
  - Delete any log entry
- **Pump Log section** — below the baby cards; log pump sessions with time, ml, and optional note; shows total ml pumped today
- **Daily Notes** — free-text note per day, auto-saved with debounce

### Growth Tab
- **Measurement filter pills** — All · ⚖️ Weight · 📏 Length · 🧠 Head (filters both charts and table)
- Per-baby measurement cards showing:
  - Latest reading badges (weight kg, length cm, head cm)
  - **Trend charts** — SVG line charts for weight and length over time, coloured in the baby's theme, with axis labels and data point tooltips
  - History table (most recent 10 records for the active filter)
  - Add measurement form (date, type, value)
- **Vaccine section** with baby filter pills (All · per baby)
  - Vaccine history table: date, baby, vaccine name, notes
  - Add vaccine form

### Summary Tab
- **Date range filter pills** — **7 days · 14 days · 30 days** (default 7 days)
- Rows sorted reverse-chronologically — today at the top, oldest at the bottom
- Queries the selected date range of entries and pump sessions in parallel
- Table columns:
  - **Date**
  - Per-baby milk: feed count (e.g. `3×`) + bar chart + ml total, coloured in each baby's theme
  - **🤱 ml** — total pumped ml for the day with session count
  - Per-baby urine (💧) counts
  - Per-baby potty (💩) counts
- Column headers use baby initials (e.g. 🌸 AY) to keep the table compact
- Latest Growth cards — most recent weight/length/head per baby
- Recent Vaccines list (last 8)

### Settings Tab
- **Family Name** — edit and save (admin only)
- **Members** — list all members with role badge and role tag; admins can assign/change tags and remove members
- **Invite Someone** — generate a shareable link (admin only); one-click copy
- **Header Colour** — 8 swatches to colour the family name bar (admin only); saved to Supabase
- **Babies** — colour swatches per baby (8 themes); add new baby with emoji, name, DOB; delete baby (admin only)
- **Sign Out / Switch Family**

### Colour System
8 themes: Pink · Blue · Mint · Peach · Purple · Sky · Rose · Sage. Each has three shades (light, mid, dark) used for card backgrounds, chips, charts, and text. Baby colours sync to `babies.color` in Supabase. Family header colour syncs to `families.color`.

---

## Database Schema

Run **`setup.sql`** in the Supabase SQL Editor to create all tables, triggers, RLS policies, and helper functions from scratch.

### Tables

| Table | Purpose |
|-------|---------|
| `profiles` | User display name, email, avatar emoji |
| `families` | Family name, creator, header colour |
| `family_members` | User ↔ family membership, role (admin/member), role tag |
| `babies` | Baby name, emoji, DOB, colour theme |
| `entries` | Daily log entries (milk, urine, potty, vitamin, medicine) |
| `measurements` | Weight / length / head measurements |
| `vaccines` | Vaccine records per baby |
| `daily_notes` | One free-text note per family per day |
| `invitations` | Invite tokens (30-day expiry) |
| `pump_sessions` | Pump log entries (time, ml, note) |

### RPC Functions

| Function | Purpose |
|----------|---------|
| `create_family(p_name, p_babies)` | Creates family + admin member + babies atomically (SECURITY DEFINER — bypasses RLS chicken-and-egg) |
| `accept_invitation(invite_token)` | Validates token, adds user to family, marks invite accepted |

---

## SQL Migrations (run after initial setup)

These files are in the repo and must be run once in the Supabase SQL Editor:

| File | What it does |
|------|-------------|
| `create_family_rpc.sql` | Creates the `create_family` SECURITY DEFINER function |
| `pump_sessions.sql` | Creates the `pump_sessions` table with RLS |
| `add_member_tag.sql` | `ALTER TABLE family_members ADD COLUMN IF NOT EXISTS tag text` |
| `add_family_color.sql` | `ALTER TABLE families ADD COLUMN IF NOT EXISTS color text` |
| `fix_rls.sql` | (Legacy — superseded by `create_family_rpc.sql`, kept for reference) |

> Also run: `ALTER TABLE babies ADD COLUMN IF NOT EXISTS color text;` if not already present from `setup.sql`.

---

## Local Development

No build step required — it's a single HTML file.

```bash
git clone https://github.com/rafehjeelani/baby-tracker.git
cd baby-tracker
# open index.html in a browser, or serve with:
npx serve .
```

The Supabase project URL and anon key are hardcoded in `index.html` around line 138–139. For a fork, replace them with your own project credentials.

---

## Deployment

Pushes to `main` automatically deploy via GitHub Pages (configured under repo Settings → Pages → Deploy from branch: `main`, folder: `/`).

---

## Project Structure

```
index.html          ← entire app (HTML + CSS + JS, ~1400 lines)
setup.sql           ← full Supabase schema, RLS, triggers
create_family_rpc.sql
pump_sessions.sql
add_member_tag.sql
add_family_color.sql
fix_rls.sql
README.md
```
