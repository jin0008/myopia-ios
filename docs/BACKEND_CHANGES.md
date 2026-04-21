# Backend changes needed on myopiamanage.org

This document enumerates the changes needed on the existing Node/Express server running on your Google Cloud Compute Engine VM. None of these are breaking — they are additive.

## 1. New database tables (PostgreSQL)

Apply with Prisma migration (or raw SQL if you are not yet using Prisma migrate here):

```sql
-- links a parent user (role='regular_user') to one or more children
CREATE TABLE parent_child_link (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
  nickname      TEXT NOT NULL,
  date_of_birth DATE NOT NULL,
  sex           TEXT NOT NULL CHECK (sex IN ('male','female')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_parent_child_link_user ON parent_child_link(user_id);

-- links a child (parent_child_link.id) to a patient record at a specific hospital
CREATE TABLE child_hospital_link (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_child_link_id UUID NOT NULL REFERENCES parent_child_link(id) ON DELETE CASCADE,
  hospital_id          UUID NOT NULL REFERENCES hospital(id),
  patient_id           UUID NOT NULL REFERENCES patient(id),
  status               TEXT NOT NULL DEFAULT 'active', -- 'active' | 'pending' | 'revoked'
  linked_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (parent_child_link_id, hospital_id)
);

-- refresh tokens for the mobile app (JWT access tokens are stateless)
CREATE TABLE mobile_refresh_token (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
  token_hash     TEXT NOT NULL UNIQUE,     -- sha256 of the opaque refresh token
  expires_at     TIMESTAMPTZ NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  rotated_from   UUID REFERENCES mobile_refresh_token(id),
  revoked_at     TIMESTAMPTZ
);
CREATE INDEX idx_refresh_user ON mobile_refresh_token(user_id);

-- OAuth identities for providers beyond the web app's current Google
CREATE TABLE oauth_identity (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
  provider      TEXT NOT NULL CHECK (provider IN ('apple','google','kakao','naver')),
  subject       TEXT NOT NULL,   -- provider's unique user id
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (provider, subject)
);
```

## 2. New route file

Add `src/api/mobile.ts` (or split per resource). Mount under `/api/mobile` in your Express app entry point.

A starter skeleton that matches [API_SPEC.md](API_SPEC.md) is provided at [`../backend-patches/mobile.ts`](../backend-patches/mobile.ts). Copy it into `/Users/hanjinu/code/myopia/myopia/src/api/mobile.ts` on the web project and mount it:

```ts
// in your Express bootstrap (wherever app.use('/api', ...) lives)
import mobileRouter from "./api/mobile";
app.use("/api/mobile", mobileRouter);
```

## 3. Environment variables to add on the VM

```
# JWT
MOBILE_JWT_SECRET=<64-char random>
MOBILE_JWT_ISSUER=myopiamanage.org

# Apple Sign In
APPLE_BUNDLE_ID=com.yourcompany.MyopiaCareApp
APPLE_TEAM_ID=XXXXXXXXXX
APPLE_KEY_ID=XXXXXXXXXX
APPLE_PRIVATE_KEY_PATH=/etc/secrets/AuthKey_XXXXXXXXXX.p8

# Google (you already have a web client; add the iOS client ID)
GOOGLE_IOS_CLIENT_ID=<yourproject>.apps.googleusercontent.com

# Kakao
KAKAO_REST_API_KEY=<from Kakao developers>

# Naver
NAVER_CLIENT_ID=<from Naver developers>
NAVER_CLIENT_SECRET=<from Naver developers>
```

## 4. Token verification logic (summary)

- **Apple**: verify the id_token JWT against Apple's JWKS (`https://appleid.apple.com/auth/keys`), check `iss=https://appleid.apple.com` and `aud=APPLE_BUNDLE_ID`. `sub` is the stable user id.
- **Google**: verify id_token against `https://www.googleapis.com/oauth2/v3/certs`, check `aud` matches `GOOGLE_IOS_CLIENT_ID`.
- **Kakao**: `GET https://kapi.kakao.com/v2/user/me` with `Authorization: Bearer <access_token>`. Use `id` as subject.
- **Naver**: `GET https://openapi.naver.com/v1/nid/me` with `Authorization: Bearer <access_token>`. Use `response.id` as subject.

The starter [`mobile.ts`](../backend-patches/mobile.ts) includes TODO stubs for each — implement using `jose` for JWT verification (Apple/Google) and `fetch` for Kakao/Naver userinfo.

## 5. CORS

Your existing web server probably restricts CORS to the web origin. Mobile apps don't send an `Origin` header for native requests, so no CORS change is needed; just make sure the mobile routes don't require a cookie. They don't — JWT goes in the `Authorization` header.

## 6. Rate limiting

Add rate limiting on `/api/mobile/auth/*` endpoints (e.g., `express-rate-limit`, 10 req/min per IP) to prevent credential stuffing and token farming.

## 7. Rollout plan

1. Apply DB migrations to a staging DB; smoke test.
2. Deploy the new mobile router behind a feature flag (`ENABLE_MOBILE_API=true`).
3. Publish the app to TestFlight for internal testing pointing at staging.
4. Promote to production DB; flip the flag on.
5. Submit iOS app to the App Store review with the production URL.
