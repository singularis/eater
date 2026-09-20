#!/usr/bin/env python3
"""Encode GetStatisticsRangeRequest (start_date, end_date) to raw proto3 bytes.

Dates are dd-MM-yyyy. Output is raw protobuf, not gRPC-framed.
Same layout as eater/Services/statistics_range.proto.

Example (20-06-2026 → 20-09-2026):
  0a0a32302d30362d32303236120a32302d30392d32303236
"""
from __future__ import annotations

import argparse
import pathlib
import sys


def encode_string(field: int, value: str) -> bytes:
    payload = value.encode("utf-8")
    tag = (field << 3) | 2
    if len(payload) >= 128:
        raise ValueError(f"field {field} too long for single-byte length")
    return bytes([tag, len(payload)]) + payload


def encode_range(start: str, end: str) -> bytes:
    return encode_string(1, start) + encode_string(2, end)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("start", help="start date dd-MM-yyyy")
    parser.add_argument("end", help="end date dd-MM-yyyy")
    parser.add_argument(
        "-o",
        "--output",
        type=pathlib.Path,
        help="write binary to this path (also prints hex to stdout)",
    )
    args = parser.parse_args()
    body = encode_range(args.start, args.end)
    sys.stdout.write(body.hex() + "\n")
    if args.output:
        args.output.write_bytes(body)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
