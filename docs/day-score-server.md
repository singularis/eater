# Day food score

The phone only reads. This note is the server work. Do not add a column to `total_for_day`. There is no recommendation table. The advice blob is one Redis value per account (`cache_recommendation`), overwritten each run.

Trust the token email. The phone still sends `user_name`. Ignore it when it does not match the token.

The day key is `yyyy-MM-dd`, the same value as `dishes_day.date`. The phone builds that from the local calendar. It does not send `dd-MM-yyyy`.

## Score in the recommendation job

The job that already builds `get_recommendation` also writes the day scores. Same response. The Food Table is about 7 days (`get_dishes`, `days=7`).

Add one score per date in that table. Each score uses only that date's dishes. Weigh how much was eaten, so a small sweet does not count like a large plate. Round to 0-100. Do not copy one number onto every day.

`recscore` is field 2 on the cached recommendation protobuf. Store only the newest date's score from that run. The next run overwrites the blob.

Also write a new day table: one row per account and `yyyy-MM-dd`, plus the newest dish time included in that score. Group dishes by `dishes_day.date`.

The job can be a little stale. It has a 5-minute cooldown. Leave that as it is.

Gram formula only when writing a past day the model left blank:

`sum(dishScore * grams) / sum(grams)`

Use that only when every scored dish that day has grams. Otherwise use the plain average of the dish scores. No further weight rules. Do not fill today with the gram formula. Today stays empty until the model writes it.

## get_food_score

POST protobuf. Reads the day table. Does not calculate.

Request: `user_name`, `day` (`yyyy-MM-dd`).

Response:

- `has_score` false when that day has no row. Proto3 cannot use 0 for "missing".
- `score` only when `has_score` is true. A stored 0 is a real score.
- `dish_time`, the newest dish time stored with that score.

Days older than the job's window stay without a row until a later run includes them. The phone shows `-` for that.

## Explain

Two prompts. Not the recommendation prompt. Run only when the phone calls `explain_food_score`.

Request: `user_name`, `day`, `language_code`, `dish_time`.

`dish_time` 0 is the day. Load that day's eaten food and write the long reason for the number.

A non-zero `dish_time` is one dish. Load that dish's JSON only. Say why it is good, why it is bad, and why the score is that number. Name the components. If alcohol is in the dish, say what is bad about it. Stay inside that JSON. No free-text question.

Response: `explanation`, `basis_dish_time` (the dish time the text used). Save the text with that time and return the saved text when the same time is asked again. A newer dish time computes again.

Language uses the existing `language_code` injection (`respond_in_language`). The score job does not need a language. Explain does.

## Photos

Photo generation stays on the server. The phone retries `get_photo` on its own. Nothing to change for that retry.
