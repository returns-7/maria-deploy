#!/usr/bin/env bash
# 사용법: ./deploy.sh <maria|mydata|return-securities|risk> <이미지 태그(커밋 SHA)>
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
  risk)              VAR=RISK_TAG ;;
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

# risk는 배치와 같은 잠금(/data/prices.batch.lock)을 교체가 끝날 때까지 쥔다.
# /health의 batch_running 조회만으로는 조회 직후 시작하는 배치와 경쟁하므로 잠금 자체로 막는다.
# 못 쥐면 배치가 도는 중이므로 아무것도 바꾸지 않고 끝낸다. 파일을 지우거나 바꾸지 않는다.
# 잠금 보유는 risk 이미지(UID 10001, 첫 배포 때 빈 볼륨 권한도 이미지 기준)의 python이 맡는다
if [ "$SERVICE" = risk ]; then
  LOCK_HOLDER=risk-deploy-lock
  trap 'docker rm -f "$LOCK_HOLDER" >/dev/null 2>&1 || true' EXIT
  docker rm -f "$LOCK_HOLDER" >/dev/null 2>&1 || true
  docker run -d --name "$LOCK_HOLDER" --user 10001:10001 -v maria-app_risk-data:/data \
    "ghcr.io/returns-7/risk:${TAG}" python -c "import fcntl,sys,time
f=open('/data/prices.batch.lock','a+b')
try: fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)
except OSError: sys.exit(75)
print('locked',flush=True); time.sleep(1800)" > /dev/null
  locked=false
  for _ in $(seq 1 20); do
    if docker logs "$LOCK_HOLDER" 2>/dev/null | grep -q locked; then locked=true; break; fi
    [ "$(docker inspect -f '{{.State.Running}}' "$LOCK_HOLDER")" = true ] || break
    sleep 0.5
  done
  if [ "$locked" != true ]; then
    echo "배치 잠금을 얻지 못해 배포하지 않습니다 (배치 실행 중이거나 잠금 컨테이너 실패)" >&2
    docker logs --tail 5 "$LOCK_HOLDER" >&2 || true
    exit 4
  fi
fi

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
