#!/usr/bin/env python3
"""Compare candidate SQL variants: result equality + timing.

Usage:
  python3 scripts/bench_candidate_sql.py
  python3 scripts/bench_candidate_sql.py --patterns 'a*,b*,c*' --offset 0,5 --runs 50
  python3 scripts/bench_candidate_sql.py --explain
"""

from __future__ import annotations

import argparse
import sqlite3
import statistics
import string
import sys
import time
from pathlib import Path

DEFAULT_DB = Path.home() / "Library/Application Support/com.qwertyyb.inputmethod.Fire/dict.sqlite"

SQL_V1 = """
select
    max(wbcode),
    text,
    type, min(query) as query,
    max(spell) as spell,
    max(pinyin) as pinyin,
    max(is_gb2312) as is_gb2312
from wb_py_dict
where query glob :queryLike
    and not exists (select 1 from blocked_words b where b.text = wb_py_dict.text)
group by text
order by query, min(id)
limit :offset, 5
"""

SQL_V2 = """
WITH top_texts AS (
    SELECT 
        text,
        MIN(query) AS query,
        MIN(id) AS min_id,
        MIN(CASE WHEN query = :queryRaw THEN 0 ELSE 1 END) AS zrank
    FROM wb_py_dict
    WHERE query glob :queryLike                     -- 改用 LIKE，更易利用索引
      AND text NOT IN (SELECT text FROM blocked_words)  -- 排除屏蔽词
    GROUP BY text
    ORDER BY zrank, query, min_id                    -- 与原始排序一致
    LIMIT :offset, 5                                   -- 提前截断，只取前5个 text
)
SELECT 
    (select max(wbcode) from wb_py_dict where text = t.text and query glob :queryLike group by text),
    d.text,
    d.type      AS type,                  -- 假设 type 在组内相同，否则需明确逻辑
    t.query,
    d.spell     AS spell,
    d.pinyin    AS pinyin,
    d.is_gb2312 AS is_gb2312
FROM wb_py_dict d
JOIN top_texts t ON d.id = t.min_id
ORDER BY t.zrank, t.query, t.min_id;                   -- 保持原始排序
"""

COLUMNS = ("wbcode", "text", "type", "query", "spell", "pinyin", "is_gb2312")


def parse_csv_list(value: str) -> list[str]:
    return [part.strip() for part in value.split(",") if part.strip()]


def parse_offsets(value: str) -> list[int]:
    return [int(part.strip()) for part in value.split(",") if part.strip()]


def percentile(sorted_vals: list[float], p: float) -> float:
    if not sorted_vals:
        return float("nan")
    if len(sorted_vals) == 1:
        return sorted_vals[0]
    k = (len(sorted_vals) - 1) * p
    f = int(k)
    c = min(f + 1, len(sorted_vals) - 1)
    if f == c:
        return sorted_vals[f]
    return sorted_vals[f] + (sorted_vals[c] - sorted_vals[f]) * (k - f)


def fetch_all(conn: sqlite3.Connection, sql: str, query_like: str, query_raw: str, offset: int) -> list[tuple]:
    cur = conn.execute(sql, {"queryLike": query_like, "queryRaw": query_raw, "offset": offset})
    return cur.fetchall()


def time_query(
    conn: sqlite3.Connection,
    sql: str,
    query_like: str,
    query_raw: str,
    offset: int,
    runs: int,
    warmup: int,
) -> list[float]:
    for _ in range(warmup):
        fetch_all(conn, sql, query_like, query_raw, offset)
    samples: list[float] = []
    for _ in range(runs):
        # Drop page cache effects within SQLite by clearing statement cache is hard;
        # still useful to compare relative cost under same connection settings.
        t0 = time.perf_counter()
        fetch_all(conn, sql, query_like, query_raw, offset)
        samples.append((time.perf_counter() - t0) * 1000.0)
    return samples


def summarize(samples: list[float]) -> tuple[float, float, float]:
    ordered = sorted(samples)
    return ordered[0], statistics.median(ordered), percentile(ordered, 0.95)


def rows_equal(a: list[tuple], b: list[tuple], keys: set[str] | None) -> list[str]:
    diffs: list[str] = []
    if len(a) != len(b):
        diffs.append(f"row count: v1={len(a)} v2={len(b)}")
    n = max(len(a), len(b))
    idxs = range(len(COLUMNS)) if keys is None else [COLUMNS.index(k) for k in COLUMNS if k in keys]
    for i in range(n):
        ra = a[i] if i < len(a) else None
        rb = b[i] if i < len(b) else None
        if ra is None or rb is None:
            diffs.append(f"row[{i}]: only in {'v1' if rb is None else 'v2'}: {ra or rb}")
            continue
        for j in idxs:
            if ra[j] != rb[j]:
                diffs.append(
                    f"row[{i}].{COLUMNS[j]}: v1={ra[j]!r} v2={rb[j]!r} "
                    f"(text={ra[1]!r}/{rb[1]!r})"
                )
    return diffs


def print_explain(conn: sqlite3.Connection, label: str, sql: str, query_like: str, offset: int) -> None:
    print(f"\n--- EXPLAIN QUERY PLAN {label} ({query_like!r}, offset={offset}) ---")
    plan_sql = f"EXPLAIN QUERY PLAN {sql}"
    for row in conn.execute(plan_sql, {"queryLike": query_like, "offset": offset}):
        print("  ", row)


def main() -> int:
    parser = argparse.ArgumentParser(description="Benchmark & compare candidate SQL variants")
    parser.add_argument(
        "--db",
        type=Path,
        default=DEFAULT_DB,
        help=f"sqlite path (default: {DEFAULT_DB})",
    )
    parser.add_argument(
        "--patterns",
        default=",".join(f"{c}" for c in string.ascii_lowercase),
        help="comma-separated GLOB patterns (default: a*,b*,...,z*)",
    )
    parser.add_argument("--offset", default="0", help="comma-separated offsets (default: 0)")
    parser.add_argument("--runs", type=int, default=20, help="timed runs per case (default: 20)")
    parser.add_argument("--warmup", type=int, default=1, help="warmup runs (default: 1)")
    parser.add_argument(
        "--keys",
        default=",".join(COLUMNS),
        help="columns to compare, comma-separated (default: all)",
    )
    parser.add_argument("--explain", action="store_true", help="print EXPLAIN QUERY PLAN for first case")
    parser.add_argument("--show-rows", action="store_true", help="print result rows when they differ")
    args = parser.parse_args()

    if not args.db.exists():
        print(f"error: db not found: {args.db}", file=sys.stderr)
        return 1

    patterns = parse_csv_list(args.patterns)
    offsets = parse_offsets(args.offset)
    key_set = set(parse_csv_list(args.keys))
    unknown = key_set - set(COLUMNS)
    if unknown:
        print(f"error: unknown compare keys: {sorted(unknown)}", file=sys.stderr)
        return 1

    uri = f"file:{args.db.resolve()}?mode=ro"
    conn = sqlite3.connect(uri, uri=True)
    conn.execute("PRAGMA case_sensitive_like=ON")
    # Align roughly with DictManager cache setting (2MB)
    conn.execute("PRAGMA cache_size=-2000")

    dict_count, blocked = conn.execute(
        "select (select count(*) from wb_py_dict), (select count(*) from blocked_words)"
    ).fetchone()
    print(f"db: {args.db}")
    print(f"wb_py_dict rows: {dict_count:,}  blocked_words: {blocked:,}")
    print(f"patterns: {len(patterns)}  offsets: {offsets}  runs: {args.runs}  warmup: {args.warmup}")
    print(f"compare keys: {', '.join(c for c in COLUMNS if c in key_set)}")
    print()

    if args.explain and patterns and offsets:
        print_explain(conn, "v1", SQL_V1, patterns[0], offsets[0])
        print_explain(conn, "v2", SQL_V2, patterns[0], offsets[0])
        print()

    header = (
        f"{'pattern':<10}{'off':>4}  {'match':<6}  "
        f"{'v1 med':>8}{'v1 p95':>8}  "
        f"{'v2 med':>8}{'v2 p95':>8}  "
        f"{'speedup':>8}   (ms)"
    )
    print(header)
    print("-" * len(header))

    mismatch_cases = 0
    v1_all: list[float] = []
    v2_all: list[float] = []

    for pattern in patterns:
        for offset in offsets:
            rows1 = fetch_all(conn, SQL_V1, pattern + "*", pattern, offset)
            rows2 = fetch_all(conn, SQL_V2, pattern + "*", pattern, offset)
            diffs = rows_equal(rows1, rows2, key_set)
            matched = not diffs
            if not matched:
                mismatch_cases += 1

            s1 = time_query(conn, SQL_V1, pattern + "*", pattern, offset, args.runs, args.warmup)
            s2 = time_query(conn, SQL_V2, pattern + "*", pattern, offset, args.runs, args.warmup)
            v1_min, v1_med, v1_p95 = summarize(s1)
            v2_min, v2_med, v2_p95 = summarize(s2)
            v1_all.extend(s1)
            v2_all.extend(s2)
            speedup = (v1_med / v2_med) if v2_med > 0 else float("inf")

            print(
                f"{pattern:<10}{offset:>4}  "
                f"{'OK' if matched else 'DIFF':<6}  "
                f"{v1_med:7.2f}{v1_p95:8.2f}  "
                f"{v2_med:8.2f}{v2_p95:8.2f}  "
                f"{speedup:7.2f}x"
            )

            if diffs:
                for line in diffs[:12]:
                    print(f"    ! {line}")
                if len(diffs) > 12:
                    print(f"    ! ... {len(diffs) - 12} more diffs")
                if args.show_rows:
                    print("    v1:", rows1)
                    print("    v2:", rows2)

    print("-" * len(header))
    if v1_all and v2_all:
        _, v1_med, v1_p95 = summarize(v1_all)
        _, v2_med, v2_p95 = summarize(v2_all)
        overall = (v1_med / v2_med) if v2_med > 0 else float("inf")
        print(
            f"{'ALL':<10}{'':>4}  "
            f"{'OK' if mismatch_cases == 0 else 'DIFF':<6}  "
            f"{v1_med:7.2f}{v1_p95:8.2f}  "
            f"{v2_med:8.2f}{v2_p95:8.2f}  "
            f"{overall:7.2f}x"
        )
        print(
            f"\nsummary: {mismatch_cases} mismatch case(s); "
            f"overall median speedup v1/v2 = {overall:.2f}x "
            f"(>1 means v2 faster)"
        )

    conn.close()
    return 1 if mismatch_cases else 0


if __name__ == "__main__":
    raise SystemExit(main())
