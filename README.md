# PayChecQ

[![Rails Style Guide](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop-rails)
[![Ruby Checks](https://github.com/douglasrlee/paychecq/actions/workflows/ruby-checks.yml/badge.svg)](https://github.com/douglasrlee/paychecq/actions/workflows/ruby-checks.yml)

Welcome! You've found the source code to the PayChecQ.com application.

This application is a _simple_ tool that helps people budget better by automatically bucketing money into specific expenses/goals per payday.

Afterward, it gives the user a _simple_ safe-to-speed total that is the money in their account minus the money that is artificially moved into those expenses/goals.

That's it!

## Local Development

### Prerequisites

* Ruby (Currently using Ruby 3.4.1)
* Rails (Currently using Rails 8.0.1)
* PostgreSQL 16 (Currently PostgreSQL 16.4)
    * Superuser `admin` with password `password`
      ```sql
      CREATE USER admin WITH PASSWORD 'password';
      ALTER USER admin WITH SUPERUSER;
      CREATE DATABASE paychecq_development;
      ```

### Running Locally

To start the server using the following command:
```console
./bin/dev
```
