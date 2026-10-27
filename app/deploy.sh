#!/usr/bin/env bash
# 사용법: ./deploy.sh <maria|mydata|return-securities> <이미지 태그(커밋 SHA)>
# GitHub Actions가 SSH로 호출한다. 그 앱 하나만 바꾸고,
# 헬스체크가 통과했을 때만 tags.env에 기록한다. 실패하면 tags.env의 이전 태그로 되돌린다
set -euo pipefail

SERVICE="$1"
TAG="$2"
cd "$(dirname "$0")"

case "$SERVICE" in
  maria)             VAR=MARIA_TAG ;;
  mydata)            VAR=MYDATA_TAG ;;
  return-securities) VAR=SECURITIES_TAG ;;
  *) echo "알 수 없는 서비스: $SERVICE" >&2; exit 2 ;;
esac

# 00:00~02:30 정산·동기화·세액 배치 시간에는 배포하지 않는다
NOW=$(TZ=Asia/Seoul date +%H%M)
if [ "$((10#$NOW))" -lt 230 ]; then
  echo "배치 시간(00:00~02:30 KST)이라 배포하지 않습니다: $NOW" >&2
  exit 3
fi

# 세 저장소의 배포가 겹치지 않게 서버에서 한 번에 하나만
exec 9>/tmp/maria-deploy.lock
flock -w 600 9

compose() { docker compose --env-file .env --env-file tags.env "$@"; }

wait_healthy() {
  local id status
  id=$(compose ps -q "$SERVICE")
  for _ in $(seq 1 36); do   # 5초 x 36 = 최대 3분
    status=$(docker inspect -f '{{.State.Health.Status}}' "$id")
    [ "$status" = healthy ] && return 0
    sleep 5
  done
  return 1
}

PREV=$(grep "^${VAR}=" tags.env | cut -d= -f2)

# 셸 환경변수가 --env-file 값보다 우선한다 → tags.env는 건드리지 않고 이번 실행만 새 태그
export "$VAR=$TAG"
compose pull "$SERVICE"
compose up -d --no-deps "$SERVICE"

if wait_healthy; then
  sed -i "s/^${VAR}=.*/${VAR}=${TAG}/" tags.env
  docker image prune -f > /dev/null
  echo "배포 성공: $SERVICE $PREV -> $TAG"
else
  echo "헬스체크 실패: $SERVICE $TAG. 로그 마지막 50줄:" >&2
  compose logs --tail 50 "$SERVICE" >&2
  unset "$VAR"
  echo "이전 태그로 되돌립니다: $PREV" >&2
  compose up -d --no-deps "$SERVICE"
  exit 1
fi
