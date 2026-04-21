# Mobile API spec (`/api/mobile/*`)

All endpoints accept and return JSON. Unless noted, authenticated endpoints require an `Authorization: Bearer <accessToken>` header.

Base URL (production): `https://myopiamanage.org/api/mobile`
Base URL (dev): `http://localhost:3000/api/mobile`

---

## Auth

### `POST /auth/signup`
Create a parent account with username+password.

Request
```json
{
  "username": "alice",
  "password": "correcthorse",
  "email": "alice@example.com",
  "receive_email_updates": false
}
```

Response `201`
```json
{
  "user": { "id": "uuid", "username": "alice", "email": "alice@example.com", "role": "regular_user" },
  "accessToken": "eyJ...",
  "refreshToken": "opaque-string",
  "accessTokenExpiresIn": 3600
}
```

### `POST /auth/login`
```json
{ "username": "alice", "password": "correcthorse" }
```
Response identical to `/signup`.

### `POST /auth/social`
Exchange a provider token for an app JWT. Creates a user on first use.

Request
```json
{
  "provider": "apple" | "google" | "kakao" | "naver",
  "token": "<id_token or access_token from provider SDK>",
  "receive_email_updates": false
}
```

Response identical to `/signup`.

Server-side verification:
- `apple` – verify JWT signature against keys at `https://appleid.apple.com/auth/keys`, check `aud` matches your iOS bundle ID.
- `google` – verify against `https://www.googleapis.com/oauth2/v3/certs`, check `aud` matches your iOS client ID.
- `kakao` – call `GET https://kapi.kakao.com/v2/user/me` with the access token.
- `naver` – call `GET https://openapi.naver.com/v1/nid/me` with the access token.

### `POST /auth/refresh`
```json
{ "refreshToken": "opaque-string" }
```
Response `{ accessToken, refreshToken, accessTokenExpiresIn }`. Rotates the refresh token.

### `POST /auth/logout`
Invalidates the caller's refresh token.

### `GET /auth/me`
Returns the current user object.

---

## Children (patient records owned by this parent)

### `GET /children`
List all children linked to the current parent.

Response
```json
[
  {
    "childId": "uuid",
    "nickname": "하늘이",
    "dateOfBirth": "2016-05-01",
    "sex": "male",
    "linkedHospitals": [
      { "hospitalId": "uuid", "hospitalName": "샘안과병원", "hospitalCode": "SAM001", "registrationNumber": "123456", "linkedAt": "2026-04-01T00:00:00Z" }
    ]
  }
]
```

### `POST /children`
Create a child profile (no hospital link yet).
```json
{ "nickname": "하늘이", "dateOfBirth": "2016-05-01", "sex": "male" }
```
Response `201` → `{ childId, nickname, dateOfBirth, sex, linkedHospitals: [] }`.

### `PATCH /children/:childId`
Edit nickname / DOB / sex.

### `DELETE /children/:childId`
Unlink + remove the child profile from the parent (does NOT delete the underlying patient record at the hospital).

---

## Hospital linking

### `GET /hospitals`
Public list of hospitals registered on myopiamanage.org. Used in the "Link a hospital" search field.
```json
[{ "hospitalId": "uuid", "name": "샘안과병원", "code": "SAM001", "country": "KR" }]
```

### `POST /children/:childId/hospital-links`
Attempt to link a child to a hospital patient record.

Request
```json
{
  "hospitalCode": "SAM001",
  "registrationNumber": "123456"
}
```

Server logic:
1. Find `hospital` by code.
2. Find `patient` by `(hospital_id, registration_number)`.
3. Verify `patient.date_of_birth == child.date_of_birth` and `patient.sex == child.sex`.
4. If matched, insert into `child_hospital_link` with `status='active'`.
5. If mismatched or not found, return `404` with `{ error: "no matching record" }`.

Response `201`
```json
{ "hospitalId": "uuid", "hospitalName": "샘안과병원", "registrationNumber": "123456", "linkedAt": "2026-04-21T11:00:00Z", "patientId": "uuid" }
```

**Optional v1.1:** instead of a direct link, send a `hospital_link_request` to the hospital's admin for manual approval. The MVP uses the triple-match rule and no manual step.

### `DELETE /children/:childId/hospital-links/:hospitalId`
Remove a hospital link.

---

## Measurements

### `GET /children/:childId/axial-length`
Merged axial-length series across all linked hospitals for a child.

Query params
- `from` (ISO date, optional)
- `to` (ISO date, optional)

Response
```json
[
  {
    "date": "2024-03-01",
    "od": 23.45,
    "os": 23.38,
    "instrumentId": "IOLMaster",
    "hospitalId": "uuid",
    "hospitalName": "샘안과병원"
  }
]
```

### `GET /children/:childId/refractive-error`
Same shape for SE, sphere, cylinder.

### `GET /children/:childId/mean-k`

### `GET /children/:childId/treatments`
Treatment history (read-only).

### `GET /children/:childId/summary`
Bundle of latest-of-each for the detail screen.
```json
{
  "latestAxial": { "date": "...", "od": 23.45, "os": 23.38 },
  "latestRefractive": { ... },
  "riskStatus": "monitoring" | "low" | "moderate" | "high",
  "measurementCount": 14
}
```

---

## Notifications (v2)

### `POST /notifications/device-token`
Register an APNs device token against the current user for push notifications when new measurements arrive.

---

## Screen Time / Near-work (v2)

### `POST /children/:childId/nearwork-samples`
Bulk-upload aggregated near-work samples from the app's Family Controls extension.
```json
{ "samples": [{ "date": "2026-04-20", "minutes": 145 }] }
```
See [`SCREEN_TIME_PLAN.md`](SCREEN_TIME_PLAN.md) for how the samples are derived.

---

## Error format

Non-2xx responses always return
```json
{ "error": "human readable message", "code": "SNAKE_CASE_CODE" }
```

Common codes: `unauthorized`, `forbidden`, `not_found`, `validation_error`, `rate_limited`, `internal_error`.
