# PayChecQ

Welcome! You've found the source code to the PayChecQ.com application.

This application is a _simple_ tool that helps people budget better by automatically bucketing money into specific expenses/goals per payday.

Afterward, it gives the user a _simple_ safe-to-speed total that is the money in their account minus the money that is artificially moved into those expenses/goals.

That's it!

## Local Development

### Prerequisites

* Ruby (Currently using Ruby 3.4.2)
* Rails (Currently using Rails 8.0.1)
* PostgreSQL 16 (Currently PostgreSQL 16.4)
    * Superuser `admin` with password `password`
      ```sql
      CREATE USER admin WITH PASSWORD 'password';
      ALTER USER admin WITH SUPERUSER;
      ```

### Running Locally

To setup initially run the following command:
```console
./bin setup --skip-server
```

To start the server using the following command:
```console
./bin/dev
```

To run the tests use the following command:
```console
./bin/rails test test:system
```
