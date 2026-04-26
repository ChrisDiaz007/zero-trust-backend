# Zero Trust Backend

A Ruby on Rails API implementing Zero Trust security principles with JWT access tokens and rotating refresh tokens.

---

## Stack

- **Ruby on Rails** (API mode)
- **PostgreSQL**
- **Devise** + **devise-jwt** — authentication and JWT issuance
- **jsonapi-serializer** — JSON response formatting

---

## Authentication Architecture

### Token Strategy

| Token | Storage | Expiration | Transport |
|---|---|---|---|
| Access Token (JWT) | Client memory | 15 minutes | `Authorization: Bearer` header |
| Refresh Token | DB + HttpOnly cookie | 7 days | Signed HttpOnly cookie |

### JWT Revocation

The `User` model uses the **JTIMatcher** revocation strategy. Each user has a unique `jti` column. When a user logs out, their `jti` is rotated, immediately invalidating all previously issued access tokens.

---

## API Endpoints

### Auth

| Method | Path | Description | Auth Required |
|---|---|---|---|
| POST | `/api/v1/signup` | Register a new user | No |
| POST | `/api/v1/login` | Login, receive access + refresh token | No |
| DELETE | `/api/v1/logout` | Logout, revoke tokens | Yes |
| POST | `/api/v1/refresh_token` | Rotate refresh token, get new access token | No (uses cookie) |
| DELETE | `/api/v1/signup` | Delete account | Yes |

---

## Authentication Flows

### Login

1. Client sends `POST /api/v1/login` with `email` and `password`
2. Devise validates credentials
3. A **JWT access token** (15-minute expiry) is issued and returned in the response body
4. A **refresh token** (32-byte hex, 7-day expiry) is generated, stored in the database, and set as a signed HttpOnly cookie

**Response:**
```json
{
  "status": { "code": 200, "message": "Logged in." },
  "data": {
    "id": "1",
    "type": "user",
    "attributes": { "email": "user@example.com" }
  },
  "token": "<jwt_access_token>"
}
```

---

### Authenticated Requests

Include the access token in the `Authorization` header:

```
Authorization: Bearer <jwt_access_token>
```

All routes under `Api::V1::BaseController` require a valid JWT via `before_action :authenticate_user!`.

---

### Refresh Token Rotation

When the access token expires, the client can silently obtain a new one:

1. Client sends `POST /api/v1/refresh_token` (refresh token cookie sent automatically)
2. Server reads the refresh token from the signed HttpOnly cookie
3. Server validates the token exists in the database and has not expired
4. **Old refresh token is invalidated**
5. A new refresh token (32-byte hex, 7-day expiry) is generated, saved to the DB, and set in a new cookie
6. A new access token is issued via Warden and returned in the response body

**Response:**
```json
{
  "token": "<new_jwt_access_token>"
}
```

Error responses: `401` if cookie is missing, token is invalid, or token has expired.

---

### Logout

1. Client sends `DELETE /api/v1/logout` with a valid JWT in the `Authorization` header
2. Refresh token is cleared from the database
3. Refresh token cookie is deleted
4. JWT is revoked via JTI rotation — all existing access tokens for this user are immediately invalid

---

## Database Schema (Users)

| Column | Type | Description |
|---|---|---|
| `email` | string | Unique, required |
| `encrypted_password` | string | Bcrypt hashed |
| `jti` | string | JWT ID for revocation (unique) |
| `refresh_token` | string | Current active refresh token (unique) |
| `refresh_token_expires_at` | datetime | Refresh token expiration |
| `reset_password_token` | string | Devise password reset |
| `remember_created_at` | datetime | Devise remember me |

---

## Security Notes

- Refresh tokens are stored in **signed HttpOnly cookies** — inaccessible to JavaScript
- In production, cookies are set with `Secure: true` and `SameSite: :none`
- In development, cookies use `SameSite: :strict`
- Access tokens are short-lived (15 min) to limit exposure if intercepted
- Refresh token rotation means a stolen refresh token can only be used once before it is invalidated
- JTI matching ensures logout immediately invalidates all active access tokens

---

## Setup

### Prerequisites

- Ruby (see `.ruby-version`)
- PostgreSQL

### Install

```bash
bundle install
bin/rails db:create db:migrate
```

### Credentials

Add your JWT secret to Rails credentials:

```bash
bin/rails credentials:edit
```

```yaml
devise_jwt_secret_key: <your_secret_key>
```

### Run

```bash
bin/rails server
```

### Tests

```bash
bin/rails db:test:prepare test
```

---

## CI

GitHub Actions runs on every push to `master` and on all pull requests:

- **Brakeman** — static security analysis
- **bundler-audit** — known gem vulnerability scan
- **RuboCop** — code style linting
- **RSpec/Rails tests** — full test suite against a PostgreSQL service container

The `RAILS_MASTER_KEY` secret must be set in GitHub repository secrets for CI to decrypt credentials.
