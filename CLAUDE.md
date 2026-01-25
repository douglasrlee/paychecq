# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PayChecQ is a Rails 8 budgeting application that helps users allocate paycheck money into expense/goal buckets to track safe-to-spend amounts.

**Stack:** Rails 8.1, Ruby 4.0, PostgreSQL 17, Hotwire (Turbo + Stimulus), Tailwind CSS + DaisyUI, esbuild

## Common Commands

```bash
bin/setup --skip-server          # Initial setup (gems, npm, database)
bin/dev                          # Start dev server (localhost:3000)
bin/rails test                   # Run unit/controller tests (parallel)
bin/rails test:system            # Run system tests (Capybara + Selenium)
bin/rails test test/controllers/sessions_controller_test.rb           # Run single test file
bin/rails test test/controllers/sessions_controller_test.rb:10        # Run single test by line
bin/rubocop                      # Lint Ruby code
bin/rubocop -a                   # Auto-fix lint issues
bin/brakeman                     # Security vulnerability scan
bin/ci                           # Run full CI pipeline locally
```

## Architecture

### Authentication
- Rails 8 built-in authentication via `app/controllers/concerns/authentication.rb`
- Session-based with signed cookies (permanent by default)
- `Current` (ActiveSupport::CurrentAttributes) holds thread-safe request context
- `allow_unauthenticated_access` macro skips auth for specific actions
- Rate limiting on login attempts (10 per 3 minutes)

### Data Model
- All tables use UUID primary keys (pgcrypto extension)
- Paper Trail tracks changes on User and Transaction models
- PostgreSQL extensions: pgcrypto, pg_trgm (full-text search), citext

### Key Models
- **User**: has_secure_password, has_many sessions/transactions
- **Session**: tracks login sessions with IP/user_agent
- **Transaction**: budget line items (name, amount, pending status)

### Frontend
- Hotwire for SPA-like interactions without a JS framework
- Stimulus controllers in `app/javascript/controllers/`
- Tailwind CSS with DaisyUI component classes
- View components in `app/views/components/`

### Dev Server (Procfile.dev)
`bin/dev` runs three parallel processes via foreman:
1. Rails server with debugger
2. esbuild JS watcher
3. Tailwind CSS watcher

### Email
- Templates use MJML (`mjml-rails` gem) for responsive emails — files are `.html.mjml`
- Mailer previews available at http://localhost:3000/rails/mailers
