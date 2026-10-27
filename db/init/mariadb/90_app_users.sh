#!/bin/bash
# 앱별 최소 권한 계정. DDL(01, 03) 다음에 한 번만 실행된다
set -euo pipefail
mariadb -uroot -p"${MARIADB_ROOT_PASSWORD}" <<SQL
CREATE USER 'maria_app'@'%' IDENTIFIED BY '${MARIA_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ria_admin.* TO 'maria_app'@'%';

CREATE USER 'securities_app'@'%' IDENTIFIED BY '${SECURITIES_DB_PASSWORD}';
GRANT SELECT ON securities.* TO 'securities_app'@'%';

FLUSH PRIVILEGES;
SQL
