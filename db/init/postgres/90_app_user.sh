#!/bin/bash
# mydata 앱 계정: 읽기·추가·수정만. DDL(02) 다음에 한 번만 실행된다
set -euo pipefail
psql -v ON_ERROR_STOP=1 -U postgres -d mydata <<SQL
CREATE ROLE mydata_app LOGIN PASSWORD '${MYDATA_DB_PASSWORD}';
GRANT CONNECT ON DATABASE mydata TO mydata_app;
GRANT USAGE ON SCHEMA public TO mydata_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO mydata_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO mydata_app;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
SQL
