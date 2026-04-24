# Backend changes on myopiamanage.org (for Eyelog iOS)

> **Status:** ✅ Applied. The reference implementation lives in the `myopiaBackend` repo and is summarized below for iOS-side context. For the actionable deploy instructions see **`myopiaBackend/MOBILE_API_SETUP.md`** — this file is kept for architectural reference only.

All changes are additive — no existing web route, table, or column was modified.

## 1. New database tables (PostgreSQL)

Four new tables added via `prisma/migrations/20260421100000_mobile_api/migration.sql`:

```sql
-- 1) Child profile owned by a parent user (role = 'normal_user')
CREATE TABLE parent_child_link (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
  nickname      TEXT NOT NULL,
  date_of_birth DATE NOT NULL,
  sex           sex  NOT NULL,            -- existing enum
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_parent_child_link_user ON parent_child_link(user_id);

-- 2) Links a child to a real patient record at a hospital.
--    CASCADE on parent_child_link_id (removing a child drops its links)
--    NO ACTION on hospital_id / patient_id (preserves hospital data)
CREATE TABLE child_hospital_link (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_child_link_id UUID NOT NULL REFERENCES parent_child_link(id) ON DELETE CASCADE,
  hospital_id          UUID NOT NULL REFERENCES hospital(id)           ON DELETE NO ACTION,
  patient_id           UUID NOT NULL REFERENCES patient(id)            ON DELETE NO ACTION,
  status               TEXT NOT NULL DEFAULT 'active',  -- 'active' | 'pending' | 'revoked'
  linked_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (parent_child_link_id, hospital_id)
);

-- 3) Refresh tokens for the mobile JWT flow (access tokens are stateless)
CREATE TABLE mobile_refresh_token (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
  token_hash   TEXT NOT NULL UNIQUE,       -- sha256 of the opaque refresh token
  expires_at   TIMESTAMPTZ NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  rotated_from UUID REFERENCES mobile_refresh_token(id),
  revoked_at   TIMESTAMPTZ
);
CREATE INDEX idx_refresh_user ON mobile_refresh_token(user_id);

-- 4) Unified OAuth identities across Apple / Google / Kakao / Naver
CREATE TABLE oauth_identity (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
  provider   TEXT NOT NULL CHECK (provider IN ('apple','google','kakao','naver')),
  subject    TEXT NOT NULL,                -- provider's stable user id
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (provider, subject)
);
```

### Why NO ACTION on `patient_id` / `hospital_id`?

A parent using the app is a `normal_user`. They never own the clinical record — they just have a view into it. If a parent deletes their child profile (or the parent is deleted, cascading to `parent_child_link`), the DB must **refuse to touch** the `patient` row or any of its `measurement` / `refractive_error` / `patient_k` / `patient_treatment` rows. `ON DELETE NO ACTION` at the FK level enforces this; application code double-checks.

## 2. New route module

`src/routes/mobile.ts` is mounted at `/api/mobile` in `src/index.ts`:

```ts
import mobileRoutes from "./routes/mobile";
app.use("/api/mobile", mobileRoutes);
```

Endpoint surface (matches [API_SPEC.md](API_SPEC.md)):

| Method | Path | Auth |
| ------ | ---- | ---- |
| POST | `/api/mobile/auth/signup` | public |
| POST | `/api/mobile/auth/login`  | public |
| POST | `/api/mobile/auth/social` | public |
| POST | `/api/mobile/auth/refresh` | public (refresh token) |
| POST | `/api/mobile/auth/logout` | Bearer JWT |
| GET  | `/api/mobile/auth/me`     | Bearer JWT |
| GET / POST / PATCH / DELETE | `/api/mobile/children[/...]` | Bearer JWT |
| GET  | `/api/mobile/hospitals` | public |
| POST / DELETE | `/api/mobile/children/:id/hospital-links[/...]` | Bearer JWT |
| GET  | `/api/mobile/children/:id/{axial-length,refractive-error,mean-k,treatments,summary}` | Bearer JWT |

## 3. Environment variables on the VM

```
# JWT
MOBILE_JWT_SECRET=<64-char random>
MOBILE_JWT_ISSUER=myopiamanage.org

# Apple Sign In
APPLE_BUNDLE_ID=org.myopiamanage.Eyelog

# Google (you already have a web client; add the iOS client ID)
GOOGLE_IOS_CLIENT_ID=<yourproject>.apps.googleusercontent.com

# Kakao / Naver — no server-side secret needed, tokens are verified via
# each provider's public userinfo endpoint.
```

## 4. Token verification logic (summary)

- **Apple**: verify the `id_token` JWT against Apple's JWKS (`https://appleid.apple.com/auth/keys`), check `iss=https://appleid.apple.com` and `aud=APPLE_BUNDLE_ID`. `sub` is the stable user id.
- **Google**: `google-auth-library` `OAuth2Client.verifyIdToken` with audience array `[GOOGLE_IOS_CLIENT_ID, GOOGLE_CLIENT_ID]`.
- **Kakao**: `GET https://kapi.kakao.com/v2/user/me` with `Authorization: Bearer <access_token>`. Use `id` as subject.
- **Naver**: `GET https://openapi.naver.com/v1/nid/me` with `Authorization: Bearer <access_token>`. Use `response.id` as subject.

Implemented in `src/lib/socialAuth.ts` using `jose` for Apple and `google-auth-library` for Google.

## 5. CORS

The web server restricts CORS to the web origin. Mobile apps don't send an `Origin` header for native requests, so no CORS change is needed; the mobile routes don't require a cookie. JWT goes in the `Authorization` header.

## 6. Rate limiting

Recommended — add `express-rate-limit` on `/api/mobile/auth/*` (e.g. 10 req/min per IP) to prevent credential stuffing and token farming. Not enabled in the reference implementation; add before production rollout.

## 7. Rollout plan

1. Apply DB migrations to a staging DB; smoke test `/api/mobile/hospitals`.
2. Deploy the new mobile router; verify `/api/mobile/auth/me` returns 401 without a token.
3. Point the iOS TestFlight build at the staging URL and smoke-test sign-up / link / chart.
4. Apply the migration to prod; deploy the new server build.
5. Submit iOS app to the App Store review with the production URL.
