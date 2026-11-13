#!/bin/bash
# 지금 DB 상태를 db/backup/ 에 "되돌릴 기준점"으로 저장한다(덮어씀). DB 서버(학원은 VM)의 db 폴더에서 실행한다.
# 앱이 떠 있어도 되지만, 시연 직전처럼 데이터가 바뀌지 않는 때에 뜨는 게 좋다.
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./.env; set +a
mkdir -p backup
C="docker compose"

$C exec -T mariadb mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" --default-character-set=utf8mb4 \
  --single-transaction --routines --triggers --databases ria_admin securities > backup/maria.sql
$C exec -T postgres pg_dump -U postgres -Fc mydata > backup/mydata.dump
# 업무시계는 흐르므로 지금의 업무시각을 따로 적어 두고, 복원할 때 이 시각부터 다시 흐르게 한다
$C exec -T mariadb mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -N -e \
  "SELECT DATE_FORMAT(current_datetime + INTERVAL TIMESTAMPDIFF(SECOND, reference_real_datetime, NOW()) SECOND, '%Y-%m-%d %H:%i:%s') FROM ria_admin.system_clock" > backup/clock.txt

echo "저장 완료: $(du -h backup/maria.sql backup/mydata.dump | tr '\n' ' ') 업무시계 $(cat backup/clock.txt)"
