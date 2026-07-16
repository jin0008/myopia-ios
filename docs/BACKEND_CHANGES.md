# Backend changes on myopiamanage.org (for 마이오닥 · MyoDoc iOS)

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
| POST | `/api/mobile/chat` | Bearer JWT |
| GET  | `/api/mobile/hospitals/search` | public |
| GET  | `/api/mobile/columns` · `/api/mobile/columns/:id` | public |

### 2a. AI chatbot (`POST /api/mobile/chat`) — RAG, not fine-tuning

`POST /api/mobile/chat` is a faithful TypeScript port of the prototype's
`api/chat.php`. It is **retrieval-augmented, not fine-tuned**: the clinician-
reviewed Q&A corpus is small, changes as clinicians revise it, and every answer
must cite the exact source items it used (the "답변의 근거" badge). RAG lets us
swap the corpus (`src/assets/chat/qa_index.json`) at any time without retraining,
keeps the model grounded on reviewed text, and returns the source item ids in
`refs` — none of which a fine-tuned model would give us. The flow: (1) emergency
keyword pre-filter answers dangerous symptoms with fixed guidance before any LLM
call; (2) a per-user (30/day) + global (500/day) file-based counter caps cost;
(3) the question is embedded and the top-8 Q&A items are prepended to the system
prompt; (4) Gemini `generateContent` returns structured JSON `{mode,answer,refs,
suggestions}`; (5) `general`-mode answers optionally get a Google-search
grounding second pass (skipped gracefully on the free tier). All counter/log
writes are best-effort so a file failure never blocks a reply.

**Static assets** live at `src/assets/chat/qa_index.json` and
`src/assets/chat/prompt_base.txt` (copied from the prototype's `api/`), plus the
reviewed source docs at `src/assets/chat/columns/*.md` that back the columns
endpoints. `npx tsc` does not copy non-`.ts` files into `dist/`, so the loader
probes both the compiled layout and the `src/assets/chat` source tree; if the
build pipeline is later changed to strip the source tree, add a copy step to the
`build` script.

`GET /api/mobile/hospitals/search` maps the partner `hospital` table into the
finder's `places` shape (clinics only for now; optical/lasik return an empty list
with the same shape). `GET /api/mobile/columns[/:id]` serves seed columns derived
from the reviewed Q&A docs, since no article table exists yet.

## 3. Environment variables on the VM

```
# JWT
MOBILE_JWT_SECRET=<64-char random>
MOBILE_JWT_ISSUER=myopiamanage.org

# Apple Sign In
APPLE_BUNDLE_ID=org.myopiamanage.MyoDoc

# Google (you already have a web client; add the iOS client ID)
GOOGLE_IOS_CLIENT_ID=<yourproject>.apps.googleusercontent.com

# Kakao / Naver — no server-side secret needed, tokens are verified via
# each provider's public userinfo endpoint.

# AI chatbot (POST /api/mobile/chat)
# If GEMINI_API_KEY is unset the endpoint runs in mock mode (canned answers),
# so the app UI works without a key.
GEMINI_API_KEY=<Gemini API key from https://aistudio.google.com>
CHAT_MODEL=gemini-3.1-flash-lite          # optional, default gemini-3.1-flash-lite
CHAT_EMBEDDING_MODEL=gemini-embedding-001 # optional, default gemini-embedding-001
CHAT_SEARCH_FALLBACK=true                 # optional, default true (set "false"/"0" to disable Google-search grounding)
CHAT_DATA_DIR=/var/lib/myodoc/chat        # optional, default <cwd>/data/chat (usage counters + jsonl logs)
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

## 8. Hospital geo columns (기관 찾기 finder)

Migration `prisma/migrations/20260716120000_hospital_geo/migration.sql` adds four
**nullable, additive** columns to `hospital` (existing rows/web routes unaffected):

```sql
ALTER TABLE "hospital" ADD COLUMN IF NOT EXISTS "address"   TEXT;
ALTER TABLE "hospital" ADD COLUMN IF NOT EXISTS "phone"     TEXT;
ALTER TABLE "hospital" ADD COLUMN IF NOT EXISTS "latitude"  DOUBLE PRECISION;
ALTER TABLE "hospital" ADD COLUMN IF NOT EXISTS "longitude" DOUBLE PRECISION;
```

`GET /api/mobile/hospitals/search` now maps these; hospitals with coordinates get
markers + haversine `distanceKm` sorting on the apps (iOS MapKit, Android Google
Maps). Rows still lacking coordinates return `null` and fall back to name order.

**Populating coordinates**

- *Backfill from address (bulk):* fill each hospital's `address`, then run
  `GEOCODING_API_KEY=<key> npx tsx src/migration/geocode_hospitals.ts`. It geocodes
  only rows that have an address and are missing lat/lng (safe to re-run). The key
  is a Google Cloud key with the **Geocoding API** enabled — keep it server-side,
  separate from the Android Maps SDK key.
- *Manual (per hospital):*
  ```sql
  UPDATE "hospital"
     SET address = '서울시 강남구 …', phone = '02-000-0000',
         latitude = 37.4979, longitude = 127.0276
   WHERE code = 'HOSP_CODE';
  ```

**New env var**

```
GEOCODING_API_KEY=<Google Cloud key with Geocoding API enabled>   # only for the backfill script
```

After editing `prisma/schema.prisma`, run `npx prisma generate` (and `prisma migrate deploy` in each environment) so the Prisma client picks up the new fields.
