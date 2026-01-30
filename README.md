# <img src=".github/README/PayChecQ Logo.png" alt="PayChecQ Logo" height="32"> PayChecQ

[![CI](https://github.com/douglasrlee/paychecq/actions/workflows/ci.yml/badge.svg)](https://github.com/douglasrlee/paychecq/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/douglasrlee/paychecq/badge.svg?branch=main)](https://coveralls.io/github/douglasrlee/paychecq?branch=main)
[![Rails Style Guide](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop-rails)

Welcome! You've found the source code for the main PayChecQ.com application!

A _simple_ budgeting application that allows you to take money from each of your paychecks and _virtually_ place the money in buckets of expenses and goals that then allow you to see how much money is safe-to-spend.

## Requirements

- Ruby 4.0.1
- Node.js 24.13.0
- PostgreSQL 17

## Setup

1. Install the required Ruby version (using rbenv, asdf, or your preferred version manager)

2. Install the required Node.js version (using nvm, asdf, or your preferred version manager)

3. Install PostgreSQL and ensure it's running

4. Run the setup script:

```bash
bin/setup --skip-server
```

This will:
- Install Ruby gem dependencies
- Install JavaScript dependencies via NPM
- Create and prepare the database

## Running the Application

Start the development server:

```bash
bin/dev
```

This runs the Rails server along with JavaScript and CSS build watchers. The application will be available at http://localhost:3000.

## Running Tests

Run the test suite:

```bash
bin/rails test
```

Run system tests:

```bash
bin/rails test:system
```

## Code Quality

Run the linter:

```bash
bin/rubocop
```

Run security audit:

```bash
bin/brakeman
bin/bundler-audit
```

## Email in Development

Mailer previews (for viewing email templates without sending) are available at http://localhost:3000/rails/mailers.
