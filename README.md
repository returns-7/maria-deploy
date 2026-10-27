# maria-deploy

MARIA 서버(앱 서버, DB 서버)에 띄우는 설정 모음. 앱 소스는 들어 있지 않다.

- `db/` : DB 서버. MariaDB + PostgreSQL (docker compose)
- `app/` : 앱 서버. nginx + maria + mydata + return-securities + redis (docker compose)
