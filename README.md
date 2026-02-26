# Use My Voucher

<p align="center">
  <img src="./public/usemyvoucher.svg" alt="Use My Voucher logo" width="140" />
</p>

Community-powered voucher and coupon sharing app built with Vue 3, TypeScript, and Supabase.

## What this app does

Use My Voucher helps people share unused promo codes so others can save money, while keeping code quality high through reporting, usage tracking, and contributor points.

## Features

- Browse active vouchers by merchant, category, and sort mode (newest, most used, expiring soon)
- Reveal, copy, and mark voucher codes as used
- Submit new vouchers with usage limits and optional expiry/category metadata
- Report invalid or duplicate vouchers
- Track your own vouchers and soft-delete old listings
- Public leaderboard and profile stats to reward contributors
- Google OAuth sign-in with protected routes for member actions

## Points and leaderboard system

Points are updated by Supabase database triggers, so scoring happens server-side and stays consistent.

- **+10 points** when you submit a new voucher
- **+5 points** when you mark someone else's voucher as used
- **+2 points** bonus to the original submitter when another user marks their voucher as used
- **-10 points** if you mark your own voucher as used (self-use)
- Self-use also soft-deletes that voucher so it no longer appears in active listings

Leaderboard ranking is based on total `profiles.points` in descending order, returned through the `get_public_leaderboard` RPC.

## Tech stack

- Vue 3 + TypeScript
- Vite
- Vue Router (hash mode)
- Tailwind CSS v4
- Nuxt UI
- Supabase (Auth + Postgres + RPC)

## Project structure

```text
src/
  components/      # shared UI (nav, modals, cards, toasts)
  composables/     # auth, toasts, login prompt state
  views/           # route pages (browse, submit, profile, etc.)
  router/          # app routes and auth guards
  lib/supabase.ts  # typed Supabase client
  types/           # generated Supabase DB types
public/
  usemyvoucher.svg # app logo
```

## Getting started

### 1) Install dependencies

```bash
npm install
```

### 2) Configure environment variables

Create a `.env` file in the project root:

```bash
VITE_SUPABASE_URL=your_supabase_project_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

### 3) Start development server

```bash
npm run dev
```

Open the local URL shown by Vite.

## Supabase setup notes

To run this project successfully, your Supabase project should include:

- Tables used by the app: `profiles`, `vouchers`, `voucher_uses`, `voucher_views`, `voucher_reports`
- Server-side logic expected by the frontend: `soft_delete_voucher` and `get_public_leaderboard`
- Google provider enabled in Supabase Auth

## Available scripts

- `npm run dev` - start local development server
- `npm run build` - type-check and create production build
- `npm run preview` - preview the production build locally

## Routing note

The app uses hash routing (`createWebHashHistory`), so URLs look like `/#/` in production environments without server-side route rewriting.

## License

This project is licensed under the terms in `LICENSE`.
