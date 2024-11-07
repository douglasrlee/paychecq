CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email CITEXT NOT NULL,
  password_hash VARCHAR(300) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX users_email_index
ON users (email);
