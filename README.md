# PayChecQ

Welcome! You've found the source code to the PayChecQ.com application.

This application is a _simple_ tool that helps people budget better by automatically bucketing money into specific expenses/goals per payday.

Afterward, it gives the user a _simple_ safe-to-speed total that is the money in their account minus the money that is artificially moved into those expenses/goals.

That's it!

## Local Development

### Prerequisites

* Java SDK 23 (Currently using OpenJDK 23.0.1)
* Maven 3 (Currently using Maven 3.9.9)
* PostgreSQL 16 (Currently PostgreSQL 16.4)
    * Superuser `admin` with password `password`
      ```sql
      CREATE USER admin WITH PASSWORD 'password';
      ALTER USER admin WITH SUPERUSER;
      ```

### Running Locally

To start the server using the following command:
```console
mvn spring-boot:run
```

To run tests use the following command:
```console
mvn test
```