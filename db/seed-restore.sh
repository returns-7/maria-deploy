#!/bin/bash
# db/backup/ 에 저장한 기준점으로 DB를 되돌린다. 실행 전에 앱(maria, return-securities, mydata, risk)을 내리고,
# 끝나면 redis를 비우고 앱을 다시 올린다(순서는 maria-deploy README "시드 되돌리기").
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./.env; set +a
C="docker compose"
for f in backup/maria.sql backup/mydata.dump backup/clock.txt; do
  [ -s "$f" ] || { echo "$f 가 없습니다. 먼저 seed-snapshot.sh 를 실행하세요." >&2; exit 1; }
done

# maria.sql 은 테이블마다 DROP TABLE IF EXISTS 를 포함한다. 앱 계정·권한(mysql DB)은 건드리지 않는다
$C exec -T mariadb mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" --default-character-set=utf8mb4 < backup/maria.sql
# DB를 지우지 않고 객체만 지우고 다시 만든다 → mydata_app 의 DB 접속 권한이 그대로 남는다
$C exec -T postgres pg_restore -U postgres -d mydata --clean --if-exists --no-owner < backup/mydata.dump
$C exec -T mariadb mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e \
  "UPDATE ria_admin.system_clock SET current_datetime='$(cat backup/clock.txt)', reference_real_datetime=NOW()"

echo "복원 완료: 업무시계 $(cat backup/clock.txt)에서 다시 출발. 이제 redis를 비우고 앱을 올리세요."
