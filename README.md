# maria-deploy

MARIA 서버(앱 서버, DB 서버)에 띄우는 설정 모음. 앱 소스는 들어 있지 않다.

- `db/` : DB 서버. MariaDB + PostgreSQL (docker compose)
- `app/` : 앱 서버. nginx + maria + mydata + return-securities + redis (docker compose)

서버에만 두는 파일(`.env`, `app/tags.env`, `app/nginx/admin-allowlist.conf`)은 저장소에 올리지 않는다.
필요한 `.env` 키는 마리아 저장소 `docs/infra-plan.md`(§15-5, §15-7)를 본다.
