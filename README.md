# PayChecQ

[![Ruby Style Guide](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-community-brightgreen.svg)](https://rubystyle.guide)

## Local Development

### Prerequisites

* rbenv
* nodenv
* postgresql

### Installation

#### rbenv
```shell
rbenv install
```

#### nodenv
```shell
nodenv install
```

#### postgresql
```shell
psql -d postgres -c "CREATE USER admin WITH PASSWORD 'password';"
psql -d postgres -c "ALTER USER admin WITH SUPERUSER;"
```

#### yarn
```shell
npm install --global yarn
nodenv rehash
```

#### rails
```shell
gem install bundler
./bin/setup
```

### Start Server
```shell
./bin/dev
```

Visit http://localhost:3000
