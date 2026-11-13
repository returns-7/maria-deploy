# maria-deploy

MARIA 서버(앱 서버, DB 서버)에 띄우는 설정 모음. 앱 소스는 들어 있지 않다.

- `db/` : DB 서버. MariaDB + PostgreSQL (docker compose)
- `app/` : 앱 서버. nginx + maria + mydata + return-securities + redis (docker compose)

## 시드 되돌리기

시연 기준 상태를 `db/backup/`에 저장해 두고, 시연·연습으로 데이터가 바뀌면 언제든 그 상태로 되돌린다. 백업 파일은 서버에만 둔다(gitignore).

- `db/seed-snapshot.sh`: 지금 DB(`ria_admin`·`securities`·`mydata`)와 업무시각을 저장한다. 덮어쓴다.
- `db/seed-restore.sh`: 저장한 상태로 되돌린다. 업무시계는 저장 당시 업무시각부터 다시 흐른다. 관리자 비밀번호 등 저장 시점의 값이 그대로 돌아온다.

되돌리는 순서 (앱이 DB를 쓰는 중에 테이블을 다시 만들지 않도록 앱을 먼저 내린다):

```bash
# 1) 앱 서버(학원은 VM)의 app 폴더: 앱 내리기
docker compose --env-file .env --env-file tags.env stop maria return-securities mydata risk
# 2) DB 서버(학원은 VM)의 db 폴더: 되돌리기
./seed-restore.sh
# 3) 앱 서버의 app 폴더: 캐시 비우고 앱 올리기
docker compose --env-file .env --env-file tags.env exec -T redis redis-cli FLUSHALL
docker compose --env-file .env --env-file tags.env start maria return-securities mydata risk
```

학원 VM은 app 폴더 명령에 `-f compose.yml -f compose.academy.yml`을 붙인다.
