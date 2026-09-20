# Eater Postman collection

`{"message":"Token is missing"}` means Postman sent no Bearer JWT. The collection file has no token on purpose.

Fix:

1. Import **both** files: `Eater.postman_collection.json` **and** `Eater.postman_environment.json`
2. Top-right dropdown: select **Eater prod TEST_USER** (not No environment)
3. Re-send `GET eater_get_today`

Or paste the JWT in Postman: collection **Authorization → Type: Bearer Token** (do not save that back into git). Collection → Variables must **not** have an empty `token` (that can shadow the environment).

Do not put the JWT in a screenshot or commit.

TEST_USER: `danteiva3141@gmail.com`. Token is 48h.

## Quick auth check

JSON not needed.

`GET {{baseUrl}}/eater_get_today`

Expect **200**. Body is `TodayFood` protobuf bytes, not JSON.

## Statistics range

- `POST {{baseUrl}}/get_statistics_range`
- Header `Content-Type: application/grpc+proto`
- Body must be **binary protobuf**, not JSON. Empty body waits ~30s then **500**.
- Same proto as `eater/Services/statistics_range.proto` (copy in `protos/`).
- Raw proto3 bytes. **Not** gRPC-framed (no 5-byte prefix).

The collection pre-request script encodes `start_date` + `end_date` (`dd-MM-yyyy`) into proto bytes.

Default `20-06-2026` → `20-09-2026` hex:

```
0a0a32302d30362d32303236120a32302d30392d32303236
```

Manual options:

- Postman Body → binary → select `bodies/get_statistics_range_20-06-2026_20-09-2026.bin` (then remove/disable the collection pre-request overwrite, or keep the same dates).
- Rebuild hex/bin:

```bash
python3 docs/postman/encode_range.py 20-06-2026 20-09-2026 -o docs/postman/bodies/get_statistics_range_20-06-2026_20-09-2026.bin
```

If Postman appends `; charset=utf-8` to Content-Type and the server 500s, send as binary file body or keep the collection script (it upserts `application/grpc+proto` with no charset).

A **200** with an empty body is a valid empty `GetStatisticsRangeResponse` (no days). That is not the empty-request 500.

## After 48h

Paste a new JWT into the environment `token` value only. Or:

```bash
EATER_POSTMAN_TOKEN='...' python3 docs/postman/_gen.py
```

That rewrites the gitignored environment. It does not put the token in the collection.

## Writes

Folder **Writes (mutates TEST_USER)** changes real data for that account.

Folder **Danger** (`delete_food`, `delete_user`) throws in a pre-request guard until you delete that script.
