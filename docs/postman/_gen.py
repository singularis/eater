#!/usr/bin/env python3
"""Build Eater Postman collection + local environment. Token from EATER_POSTMAN_TOKEN."""
from __future__ import annotations

import json
import os
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent
HEX_RANGE = "0a0a32302d30362d32303236120a32302d30392d32303236"


def uid() -> str:
    return str(uuid.uuid4())


def encode_string(field: int, value: str) -> bytes:
    payload = value.encode("utf-8")
    return bytes([(field << 3) | 2, len(payload)]) + payload


PRE_REQUEST = r'''// Collection file has no JWT. Resolve token and set Authorization, or fail
// before the server returns {"message":"Token is missing"}.
function resolvedToken() {
  const raw =
    (typeof pm.variables.get === "function" && pm.variables.get("token")) ||
    pm.environment.get("token") ||
    pm.collectionVariables.get("token") ||
    (typeof pm.globals !== "undefined" && pm.globals.get("token")) ||
    "";
  return String(raw || "").replace(/^Bearer\s+/i, "").trim();
}

if (pm.info.requestName !== "eater_auth") {
  const token = resolvedToken();
  if (!token) {
    throw new Error(
      "Token is missing. Import Eater.postman_environment.json and select environment \"Eater prod TEST_USER\" (top-right dropdown). Or paste the JWT into that environment's token variable, or Collection → Authorization → Bearer Token. Do not put the JWT in the collection JSON."
    );
  }
  pm.request.headers.upsert({ key: "Authorization", value: "Bearer " + token });
}

// Encode proto3 bodies for named requests. Dates: dd-MM-yyyy.
// JS bitwise >> is 32-bit — use Math.floor(n/128) for timestamps.
function encodeVarint(value) {
  let n = Math.trunc(Number(value));
  if (!isFinite(n) || n < 0) n = 0;
  const bytes = [];
  while (n >= 128) {
    bytes.push((n % 128) + 128);
    n = Math.floor(n / 128);
  }
  bytes.push(n);
  return bytes;
}

function utf8Bytes(str) {
  const s = unescape(encodeURIComponent(String(str)));
  const out = [];
  for (let i = 0; i < s.length; i++) out.push(s.charCodeAt(i));
  return out;
}

function tag(field, wire) {
  return encodeVarint((field << 3) | wire);
}

function encodeString(field, value) {
  if (value === undefined || value === null || value === "") return [];
  const b = utf8Bytes(value);
  return tag(field, 2).concat(encodeVarint(b.length), b);
}

function encodeInt(field, value) {
  if (value === undefined || value === null || value === "") return [];
  return tag(field, 0).concat(encodeVarint(value));
}

function encodeBool(field, value) {
  const on = value === true || value === "true" || value === 1 || value === "1";
  if (!on) return [];
  return tag(field, 0).concat([1]);
}

function encodeFloat(field, value) {
  if (value === undefined || value === null || value === "") return [];
  const buf = new ArrayBuffer(4);
  new DataView(buf).setFloat32(0, Number(value), true);
  return tag(field, 5).concat(Array.from(new Uint8Array(buf)));
}

function encodeDouble(field, value) {
  if (value === undefined || value === null || value === "") return [];
  const buf = new ArrayBuffer(8);
  new DataView(buf).setFloat64(0, Number(value), true);
  return tag(field, 1).concat(Array.from(new Uint8Array(buf)));
}

function toBinaryString(bytes) {
  return bytes.map((b) => String.fromCharCode(b)).join("");
}

function v(key) {
  return pm.environment.get(key) || pm.collectionVariables.get(key) || "";
}

function applyProtoBody(bytes, contentType) {
  if (!bytes.length) {
    throw new Error(
      "Empty protobuf body. This server waits ~30s then returns 500. Set the date/fields on the environment."
    );
  }
  pm.request.body.update({ mode: "raw", raw: toBinaryString(bytes) });
  pm.request.headers.upsert({ key: "Content-Type", value: contentType });
}

const name = pm.info.requestName;
const grpc = "application/grpc+proto";
const pb = "application/protobuf";

if (name === "get_statistics_range") {
  const start = v("start_date");
  const end = v("end_date");
  if (!start || !end) {
    throw new Error("Set start_date and end_date (dd-MM-yyyy). Empty body hangs ~30s then 500.");
  }
  applyProtoBody(encodeString(1, start).concat(encodeString(2, end)), grpc);
  pm.request.headers.upsert({ key: "Accept", value: grpc });
} else if (name === "alcohol_range") {
  applyProtoBody(encodeString(1, v("start_date")).concat(encodeString(2, v("end_date"))), grpc);
  pm.request.headers.upsert({ key: "Accept", value: grpc });
} else if (name === "get_food_custom_date") {
  applyProtoBody(encodeString(1, v("custom_date")), pb);
} else if (name === "get_recommendation") {
  applyProtoBody(encodeInt(1, v("rec_days")).concat(encodeString(2, v("language_code"))), pb);
} else if (name === "meal_suggest") {
  applyProtoBody(
    encodeInt(1, 7)
      .concat(encodeString(2, v("language_code")))
      .concat(encodeInt(3, v("meal_variant") || 0))
      .concat(encodeInt(4, v("remaining_kcal") || 600))
      .concat(encodeDouble(5, v("remaining_protein") || 40))
      .concat(encodeDouble(6, v("remaining_carbs") || 60))
      .concat(encodeDouble(7, v("remaining_fats") || 20))
      .concat(encodeDouble(8, v("remaining_sugar") || 10))
      .concat(encodeInt(9, v("meals_today") || 2)),
    pb
  );
} else if (name === "set_language") {
  applyProtoBody(encodeString(1, v("test_user_email")).concat(encodeString(2, v("language_code"))), pb);
} else if (name === "manual_weight") {
  applyProtoBody(encodeFloat(1, v("manual_weight") || 75).concat(encodeString(2, v("test_user_email"))), pb);
} else if (name === "food_health_level") {
  applyProtoBody(encodeInt(1, v("food_time")).concat(encodeString(2, v("food_name") || "salad")), pb);
} else if (name === "feedback") {
  applyProtoBody(
    encodeString(1, new Date().toISOString())
      .concat(encodeString(2, v("test_user_email")))
      .concat(encodeString(3, v("feedback_text") || "postman test")),
    pb
  );
} else if (name === "addfriend") {
  applyProtoBody(encodeString(1, v("friend_email")), pb);
} else if (name === "sharefood") {
  applyProtoBody(
    encodeInt(1, v("food_time"))
      .concat(encodeString(2, v("test_user_email")))
      .concat(encodeString(3, v("friend_email")))
      .concat(encodeInt(4, v("share_percentage") || 50)),
    pb
  );
} else if (name === "modify_food_record") {
  applyProtoBody(
    encodeInt(1, v("food_time"))
      .concat(encodeString(2, v("test_user_email")))
      .concat(encodeInt(3, v("portion_percentage") || 100))
      .concat(encodeBool(4, v("is_try_manually")))
      .concat(encodeString(5, v("manual_food_name")))
      .concat(encodeString(8, v("image_id")))
      .concat(encodeFloat(9, v("added_sugar_tsp") || 0)),
    pb
  );
} else if (name === "delete_food") {
  applyProtoBody(encodeInt(1, v("food_time")), pb);
} else if (name === "delete_user") {
  applyProtoBody(encodeString(1, v("test_user_email")), pb);
}
'''

COLLECTION_TEST = r'''const ct = (pm.response.headers.get("Content-Type") || "").toLowerCase();
if (pm.response.code === 401 || (ct.indexOf("json") !== -1 && (pm.response.text() || "").indexOf("Token is missing") !== -1)) {
  console.warn("Token is missing. Import Eater.postman_environment.json and select Eater prod TEST_USER (top right). Do not commit the JWT. Do not screenshot it.");
}
'''

TODAY_TEST = r'''pm.test("status 200", function () {
  pm.response.to.have.status(200);
});
pm.test("body is not empty", function () {
  pm.expect(pm.response.size().body).to.be.above(0);
});
'''

RANGE_TEST = r'''pm.test("status 200 (empty proto body is 500 after ~30s)", function () {
  pm.response.to.have.status(200);
});
pm.test("body is not empty", function () {
  pm.expect(pm.response.size().body).to.be.above(0);
});
'''

DANGER_FOOD = r'''throw new Error("Blocked: delete_food. Remove this Pre-request Script if you really mean it.");
'''

DANGER_USER = r'''throw new Error("Blocked: delete_user. Remove this Pre-request Script if you really mean it.");
'''


def lines(script: str) -> list[str]:
    return script.replace("\r\n", "\n").split("\n")


def event(listen: str, script: str) -> dict:
    return {
        "listen": listen,
        "script": {"type": "text/javascript", "exec": lines(script)},
    }


def headers(*pairs: tuple[str, str]) -> list[dict]:
    return [{"key": k, "value": v, "type": "text"} for k, v in pairs]


def url(path: str) -> str:
    return "{{baseUrl}}/" + path


def req(
    name: str,
    method: str,
    path: str,
    *,
    desc: str = "",
    hdrs: list[tuple[str, str]] | None = None,
    body: dict | None = None,
    tests: str | None = None,
    prereq: str | None = None,
    auth: dict | None = None,
    proto_behavior: bool = False,
) -> dict:
    hdr_list = list(hdrs or [])
    is_noauth = bool(auth and auth.get("type") == "noauth")
    if not is_noauth and not any(k.lower() == "authorization" for k, _ in hdr_list):
        hdr_list = [("Authorization", "Bearer {{token}}")] + hdr_list
    item: dict = {
        "name": name,
        "request": {
            "method": method,
            "header": headers(*hdr_list),
            "url": url(path),
            "description": desc,
            "auth": auth if auth is not None else {"type": "inherit"},
        },
        "response": [],
    }
    if body is not None:
        item["request"]["body"] = body
    events = []
    if prereq:
        events.append(event("prerequest", prereq))
    if tests:
        events.append(event("test", tests))
    if events:
        item["event"] = events
    if proto_behavior:
        item["protocolProfileBehavior"] = {
            "disabledSystemHeaders": {"content-type": True}
        }
    return item


def json_body(obj: dict) -> dict:
    return {
        "mode": "raw",
        "raw": json.dumps(obj, indent=2),
        "options": {"raw": {"language": "json"}},
    }


def empty_raw() -> dict:
    return {
        "mode": "raw",
        "raw": "",
        "options": {"raw": {"language": "text"}},
    }


def folder(name: str, items: list, desc: str = "") -> dict:
    out = {"name": name, "item": items}
    if desc:
        out["description"] = desc
    return out


def build_collection() -> dict:
    grpc = "application/grpc+proto"
    pb = "application/protobuf"
    js = "application/json"
    noauth = {"type": "noauth"}

    return {
        "info": {
            "_postman_id": "c8e1b0a2-eater-4c11-90d4-postman-col",
            "name": "Eater",
            "description": (
                "Eateria backend at https://chater.singularis.work\n\n"
                "If the response is {\"message\":\"Token is missing\"} you imported the "
                "collection without the environment (or No Environment is selected).\n"
                "Import Eater.postman_environment.json and select **Eater prod TEST_USER** "
                "in the top-right dropdown. Collection JSON has no JWT on purpose.\n\n"
                "Auth: collection-level Bearer {{token}} (TEST_USER danteiva3141@gmail.com, 48h).\n"
                "Do not put the token in a screenshot or commit. After 48h mint another into the environment.\n\n"
                "Quick auth check: GET /eater_get_today → 200.\n\n"
                "POST /get_statistics_range body is **binary protobuf** "
                "(Content-Type application/grpc+proto), not JSON. "
                "Empty body waits ~30s then 500. Same proto as statistics_range.proto.\n"
                "Default 20-06-2026 → 20-09-2026 hex:\n"
                f"`{HEX_RANGE}`\n"
            ),
            "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json",
        },
        "auth": {
            "type": "bearer",
            "bearer": [{"key": "token", "value": "{{token}}", "type": "string"}],
        },
        "event": [
            event("prerequest", PRE_REQUEST),
            event("test", COLLECTION_TEST),
        ],
        "variable": [
            {"key": "baseUrl", "value": "https://chater.singularis.work"},
            {"key": "test_user_email", "value": "danteiva3141@gmail.com"},
            {"key": "start_date", "value": "20-06-2026"},
            {"key": "end_date", "value": "20-09-2026"},
            {"key": "custom_date", "value": "20-09-2026"},
            {"key": "language_code", "value": "en"},
            {"key": "rec_days", "value": "7"},
            {"key": "activity_date", "value": "2026-09-20"},
            {"key": "image_id", "value": ""},
            {"key": "food_time", "value": ""},
            {"key": "friend_email", "value": ""},
            {"key": "food_name", "value": ""},
            {"key": "manual_weight", "value": "75"},
            {"key": "meal_variant", "value": "0"},
            {"key": "remaining_kcal", "value": "600"},
            {"key": "meals_today", "value": "2"},
        ],
        "item": [
            folder(
                "Auth check",
                [
                    req(
                        "eater_get_today",
                        "GET",
                        "eater_get_today",
                        desc=(
                            "Quick auth check (JSON not needed).\n\n"
                            "GET https://chater.singularis.work/eater_get_today\n"
                            "Authorization: Bearer {{token}}\n\n"
                            "Expect 200. Response is TodayFood protobuf."
                        ),
                        tests=TODAY_TEST,
                    ),
                    req(
                        "eater_auth",
                        "POST",
                        "eater_auth",
                        desc=(
                            "Mint a JWT from a Google/Apple idToken. "
                            "Does not use the collection Bearer token. "
                            "Do not store real provider tokens in git."
                        ),
                        hdrs=[("Content-Type", js)],
                        body=json_body(
                            {
                                "provider": "google",
                                "idToken": "",
                                "email": "{{test_user_email}}",
                                "name": "Dante Iva",
                                "profilePictureURL": "",
                            }
                        ),
                        auth=noauth,
                    ),
                ],
                "Start here. GET eater_get_today must be 200 before range calls.",
            ),
            folder(
                "Statistics",
                [
                    req(
                        "get_statistics_range",
                        "POST",
                        "get_statistics_range",
                        desc=(
                            "Kafka-backed range for week / month / 3-month charts.\n\n"
                            "Header Content-Type: application/grpc+proto\n"
                            "Body must be **binary protobuf**, not JSON. "
                            "Empty body waits ~30s then **500**.\n\n"
                            "Collection pre-request encodes start_date + end_date.\n"
                            "Example body for 20-06-2026 → 20-09-2026 (hex):\n\n"
                            f"{HEX_RANGE}\n\n"
                            "In Postman: Body → binary, or keep this request and let the script build bytes.\n"
                            "Same proto as statistics_range.proto.\n"
                            "Raw proto3 — not gRPC framed."
                        ),
                        hdrs=[
                            ("Content-Type", grpc),
                            ("Accept", grpc),
                        ],
                        body=empty_raw(),
                        tests=RANGE_TEST,
                        proto_behavior=True,
                    ),
                    req(
                        "get_food_custom_date",
                        "POST",
                        "get_food_custom_date",
                        desc="One day (dd-MM-yyyy) as CustomDateFoodRequest protobuf. Variable: custom_date.",
                        hdrs=[("Content-Type", pb)],
                        body=empty_raw(),
                        proto_behavior=True,
                    ),
                ],
                "Range call is binary proto. JSON body will fail.",
            ),
            folder(
                "Alcohol",
                [
                    req(
                        "alcohol_latest",
                        "GET",
                        "alcohol_latest",
                        desc="Latest alcohol day summary. Protobuf response.",
                        hdrs=[("Accept", grpc)],
                    ),
                    req(
                        "alcohol_range",
                        "POST",
                        "alcohol_range",
                        desc="Same date fields as statistics range (start_date, end_date). application/grpc+proto.",
                        hdrs=[
                            ("Content-Type", grpc),
                            ("Accept", grpc),
                        ],
                        body=empty_raw(),
                        proto_behavior=True,
                    ),
                ],
            ),
            folder(
                "Reads (JSON / photo)",
                [
                    req("profile_get", "GET", "profile_get", desc="Nickname, name, profile_picture_id."),
                    req(
                        "activity_summary",
                        "GET",
                        "activity_summary?date={{activity_date}}",
                        desc="ISO date query. JSON.",
                    ),
                    req(
                        "get_photo",
                        "GET",
                        "get_photo?image_id={{image_id}}",
                        desc="JPEG bytes. Set image_id from a dish in eater_get_today.",
                    ),
                    req(
                        "getfriend",
                        "GET",
                        "autocomplete/getfriend",
                        desc="Friends list protobuf.",
                    ),
                    req(
                        "get_all_chess_data",
                        "GET",
                        "autocomplete/get_all_chess_data",
                    ),
                    req(
                        "get_chess_history",
                        "GET",
                        "autocomplete/get_chess_history?limit=50&offset=0",
                    ),
                    req(
                        "get_chess_stats",
                        "POST",
                        "autocomplete/get_chess_stats",
                        hdrs=[("Content-Type", js)],
                        body=json_body(
                            {
                                "user_email": "{{test_user_email}}",
                                "opponent_email": "{{friend_email}}",
                            }
                        ),
                    ),
                    req(
                        "get_recommendation",
                        "POST",
                        "get_recommendation",
                        desc="AI dietary recommendation. Protobuf. rec_days + language_code.",
                        hdrs=[("Content-Type", pb)],
                        body=empty_raw(),
                        proto_behavior=True,
                    ),
                    req(
                        "meal_suggest",
                        "POST",
                        "meal_suggest",
                        desc="Next-meal idea. Protobuf. Timeout on server can be long (~90s in app).",
                        hdrs=[("Content-Type", pb)],
                        body=empty_raw(),
                        proto_behavior=True,
                    ),
                    req(
                        "food_health_level",
                        "POST",
                        "food_health_level",
                        desc="Needs food_time (unix ms) from a dish.",
                        hdrs=[("Content-Type", pb)],
                        body=empty_raw(),
                        proto_behavior=True,
                    ),
                ],
            ),
            folder(
                "Writes (mutates TEST_USER)",
                [
                    req(
                        "nickname_update",
                        "POST",
                        "nickname_update",
                        hdrs=[("Content-Type", js)],
                        body=json_body({"nickname": "Dante"}),
                    ),
                    req(
                        "profile_update",
                        "POST",
                        "profile_update",
                        hdrs=[("Content-Type", js)],
                        body=json_body(
                            {
                                "first_name": "Dante",
                                "last_name": "Iva",
                            }
                        ),
                    ),
                    req(
                        "goal_update",
                        "POST",
                        "goal_update",
                        hdrs=[("Content-Type", js)],
                        body=json_body(
                            {
                                "target_weight": 75,
                                "goal_mode": "lose",
                                "goal_months": 3,
                                "recommended_calories": 1800,
                            }
                        ),
                    ),
                    req(
                        "modify_food_manual",
                        "POST",
                        "modify_food_manual",
                        desc="Rename without re-analysis. Needs food_time.",
                        hdrs=[("Content-Type", js)],
                        body=json_body(
                            {
                                "time": "{{food_time}}",
                                "user_email": "{{test_user_email}}",
                                "manual_food_name": "renamed",
                            }
                        ),
                    ),
                    req(
                        "suggest_dish_names",
                        "POST",
                        "suggest_dish_names",
                        hdrs=[("Content-Type", js)],
                        body=json_body(
                            {
                                "image_id": "{{image_id}}",
                                "current_name": "{{food_name}}",
                                "language_code": "{{language_code}}",
                            }
                        ),
                    ),
                    req(
                        "activity_log",
                        "POST",
                        "activity_log",
                        hdrs=[("Content-Type", js)],
                        body=json_body(
                            {
                                "activity_type": "walk",
                                "value": 30,
                                "calories": 120,
                                "time": 0,
                                "date": "{{activity_date}}",
                            }
                        ),
                    ),
                    req(
                        "record_chess_game",
                        "POST",
                        "record_chess_game",
                        hdrs=[("Content-Type", js)],
                        body=json_body(
                            {
                                "player_email": "{{test_user_email}}",
                                "opponent_email": "{{friend_email}}",
                                "result": "win",
                                "timestamp": 0,
                            }
                        ),
                    ),
                    req(
                        "set_language",
                        "POST",
                        "set_language",
                        hdrs=[("Content-Type", pb)],
                        body=empty_raw(),
                        proto_behavior=True,
                    ),
                    req(
                        "manual_weight",
                        "POST",
                        "manual_weight",
                        desc="Writes weight for TEST_USER. Variable manual_weight.",
                        hdrs=[("Content-Type", pb)],
                        body=empty_raw(),
                        proto_behavior=True,
                    ),
                    req(
                        "modify_food_record",
                        "POST",
                        "modify_food_record",
                        hdrs=[("Content-Type", pb)],
                        body=empty_raw(),
                        proto_behavior=True,
                    ),
                    req(
                        "feedback",
                        "POST",
                        "feedback",
                        hdrs=[("Content-Type", pb)],
                        body=empty_raw(),
                        proto_behavior=True,
                    ),
                    req(
                        "addfriend",
                        "POST",
                        "autocomplete/addfriend",
                        desc="Needs friend_email.",
                        hdrs=[("Content-Type", pb)],
                        body=empty_raw(),
                        proto_behavior=True,
                    ),
                    req(
                        "sharefood",
                        "POST",
                        "autocomplete/sharefood",
                        hdrs=[("Content-Type", pb)],
                        body=empty_raw(),
                        proto_behavior=True,
                    ),
                ],
                "These change TEST_USER data. Prefer Auth check + Statistics for probing.",
            ),
            folder(
                "Danger",
                [
                    req(
                        "delete_food",
                        "POST",
                        "delete_food",
                        desc="Deletes a dish by food_time. Guarded — remove the request pre-request to run.",
                        hdrs=[("Content-Type", pb)],
                        body=empty_raw(),
                        prereq=DANGER_FOOD,
                        proto_behavior=True,
                    ),
                    req(
                        "delete_user",
                        "POST",
                        "delete_user",
                        desc="Deletes the account. Guarded — remove the request pre-request to run.",
                        hdrs=[("Content-Type", pb)],
                        body=empty_raw(),
                        prereq=DANGER_USER,
                        proto_behavior=True,
                    ),
                ],
                "Pre-request throws until you remove the guard.",
            ),
        ],
    }


ENV_KEYS = [
    ("baseUrl", "https://chater.singularis.work", "default"),
    ("token", "", "secret"),
    ("test_user_email", "danteiva3141@gmail.com", "default"),
    ("start_date", "20-06-2026", "default"),
    ("end_date", "20-09-2026", "default"),
    ("custom_date", "20-09-2026", "default"),
    ("language_code", "en", "default"),
    ("rec_days", "7", "default"),
    ("activity_date", "2026-09-20", "default"),
    ("image_id", "", "default"),
    ("food_time", "", "default"),
    ("friend_email", "", "default"),
    ("food_name", "", "default"),
    ("manual_weight", "75", "default"),
    ("token_expires_unix", "1790102161", "default"),
    (
        "token_note",
        "TEST_USER JWT, valid 48h from iat. Do not commit. Do not screenshot. Mint another after expiry.",
        "default",
    ),
]


def build_env(token: str) -> dict:
    values = []
    for key, value, typ in ENV_KEYS:
        if key == "token":
            value = token
        values.append({"key": key, "value": value, "type": typ, "enabled": True})
    return {
        "id": "b7f9d1e3-eater-4a22-8c0f-postman-env",
        "name": "Eater prod TEST_USER",
        "values": values,
        "_postman_variable_scope": "environment",
    }


def existing_env_token() -> str:
    path = ROOT / "Eater.postman_environment.json"
    if not path.exists():
        return ""
    data = json.loads(path.read_text(encoding="utf-8"))
    for item in data.get("values", []):
        if item.get("key") == "token":
            return item.get("value") or ""
    return ""


def main() -> None:
    token = os.environ.get("EATER_POSTMAN_TOKEN") or existing_env_token()
    bodies = ROOT / "bodies"
    bodies.mkdir(parents=True, exist_ok=True)
    (ROOT / "protos").mkdir(parents=True, exist_ok=True)

    rng = encode_string(1, "20-06-2026") + encode_string(2, "20-09-2026")
    if rng.hex() != HEX_RANGE:
        raise SystemExit(f"range hex mismatch: {rng.hex()}")
    (bodies / "get_statistics_range_20-06-2026_20-09-2026.bin").write_bytes(rng)

    col_path = ROOT / "Eater.postman_collection.json"
    col_path.write_text(json.dumps(build_collection(), indent=2) + "\n", encoding="utf-8")

    env_path = ROOT / "Eater.postman_environment.json"
    env_path.write_text(json.dumps(build_env(token), indent=2) + "\n", encoding="utf-8")

    if not token:
        print("wrote env with empty token (set EATER_POSTMAN_TOKEN to fill it)")
    else:
        print("wrote env with existing token (not printed)")
    print(f"wrote {col_path}")
    print(f"wrote {env_path}")
    print(f"wrote {bodies / 'get_statistics_range_20-06-2026_20-09-2026.bin'}")


if __name__ == "__main__":
    main()
