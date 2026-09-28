"""Deploy the complete Snowflake data layer over one authenticated connection.

This complements deploy.ps1 for environments where external-browser OAuth cannot
cache credentials between individual Snow CLI processes.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import snowflake.connector

ROOT = Path(__file__).resolve().parents[1]
SQL_FILES = (
    "01_raw_tables.sql",
    "02_load.sql",
    "03_marts.sql",
    "04_documents.sql",
    "04b_snowpark_features.sql",
    "05_semantic.sql",
    "06_actions_and_agent.sql",
    "06b_application_views.sql",
    "07_automation.sql",
    "08_validation.sql",
)
OPTIONAL_SQL_FILES = ("09_agent_smoke_tests.sql", "10_workflow_smoke_tests.sql")


def execute_file(connection, filename: str) -> None:
    path = ROOT / "snowflake" / filename
    print(f"\n==> {filename}", flush=True)
    with path.open(encoding="utf-8") as source:
        for cursor in connection.execute_stream(source):
            rows = cursor.fetchall() if cursor.description else []
            print(f"  query={cursor.sfqid} rows={len(rows)}", flush=True)
            for row in rows[:20]:
                safe_row = str(row).encode("ascii", errors="backslashreplace").decode("ascii")
                print(f"    {safe_row[:4000]}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--connection", default="EL85412")
    parser.add_argument("--start-at", choices=SQL_FILES, default=SQL_FILES[0])
    parser.add_argument("--only", choices=OPTIONAL_SQL_FILES)
    parser.add_argument("--run-workflow-smoke", action="store_true")
    args = parser.parse_args()
    connection = snowflake.connector.connect(
        connection_name=args.connection,
        client_store_temporary_credential=False,
    )
    try:
        if args.only:
            execute_file(connection, args.only)
            return
        start_index = SQL_FILES.index(args.start_at)
        if start_index == 0:
            execute_file(connection, SQL_FILES[0])
            cursor = connection.cursor()
            csv_path = (ROOT / "data" / "generated").as_posix()
            document_path = (ROOT / "data" / "generated" / "documents").as_posix()
            for label, statement in (
                (
                    "CSV fixtures",
                    f"PUT file://{csv_path}/*.csv @VERICARGO_ONETRUTH.RAW.CSV_STAGE "
                    "AUTO_COMPRESS=FALSE OVERWRITE=TRUE",
                ),
                (
                    "document fixtures",
                    f"PUT file://{document_path}/*.pdf @VERICARGO_ONETRUTH.RAW.DOCUMENT_STAGE "
                    "AUTO_COMPRESS=FALSE OVERWRITE=TRUE",
                ),
            ):
                print(f"\n==> Uploading {label}", flush=True)
                cursor.execute(statement)
                print(f"  query={cursor.sfqid}", flush=True)
            start_index = 1
        for filename in SQL_FILES[start_index:]:
            execute_file(connection, filename)
        if args.run_workflow_smoke:
            execute_file(connection, "10_workflow_smoke_tests.sql")
    finally:
        connection.close()


if __name__ == "__main__":
    main()
