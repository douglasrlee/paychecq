<p align="center">
  <img width="100" alt="PayChecQ Logo" src="https://github.com/user-attachments/assets/f0e9c4ce-989c-4277-ab7d-59c8cd262bf8" />
</p>

# PayChecQ

Welcome! You’ve found the source code for the PayChecQ.com application!

This is a simple budgeting application that takes the money from your paycheck and divides it appropriately into expenses and goals on a recurring basis, based on how often you get paid — leaving you with a safe-to-spend amount each paycheck.

---

## Local Development

### Prerequisites

- Node.js 22.20.0
  - tailwindcss
    - `npm install -g @tailwindcss/cli`
- Ruby 3.4.7
- PostgreSQL 17
  - admin role
    - `CREATE ROLE admin WITH LOGIN PASSWORD 'password';`
    - `ALTER ROLE admin WITH SUPERUSER;`

### Setup

```bash
./bin/setup --skip-server
```

### Run

```bash
./bin/dev
```
