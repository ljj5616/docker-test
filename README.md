# docker-test — Compose 웹 + MySQL 메모장

메모를 입력하고 저장하면 MySQL에 저장되는 Node.js 웹 서비스입니다. Docker Compose가 웹과 DB를 함께 실행합니다. ECR 이미지 빌드·배포는 GitHub Actions가 수행합니다.

## 1. EC2에 Docker Compose 설치

Docker는 이미 설치되어 있는 Amazon Linux 2023 x86_64 기준입니다. ec2-user로 실행하세요.

```sh
mkdir -p ~/.docker/cli-plugins
curl -fSL https://github.com/docker/compose/releases/download/v5.5.0/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose
docker compose version
```

MySQL을 EC2에 직접 설치하지 않습니다. Compose가 mysql:8.4 이미지를 다운로드합니다. ARM 인스턴스에서는 바이너리 파일 이름의 x86_64를 aarch64로 바꿉니다. 수동 설치한 Compose는 업데이트도 수동으로 합니다.

## 2. 자동 배포

기존 GitHub Repository secrets 6개를 그대로 사용합니다.

- EC2_HOST, EC2_USER, EC2_SSH_KEY, EC2_KNOWN_HOSTS
- AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY

변경 코드를 main에 push하면 다음 순서로 실행합니다.

1. **ci**: API 테스트 → Docker 빌드 → Compose 웹·MySQL 저장 및 데이터 유지 테스트
2. **publish**: 테스트한 이미지를 ECR에 업로드
3. **deploy**: Compose 파일 전송 → 이미지 pull → DB 준비 → 웹 컨테이너 교체

저장소: `514287510278.dkr.ecr.ap-northeast-2.amazonaws.com/docker-test`

태그: 커밋SHA-실행번호-시도번호. 기존 AWS 인증 설정은 [설정 안내](deploy/aws/README.md)를 참고하세요.

EC2의 `~/docker-test/compose.yaml`을 배포 파일로 사용합니다. DB 비밀번호는 최초 배포 때 `~/docker-test/.env`에 자동 생성하고 이후 재사용합니다. 배포 성공 시 WEB_IMAGE도 이 파일에 저장됩니다. .env는 Git에 올리지 않으며 삭제하거나 DB 비밀번호만 임의로 바꾸지 마세요. MySQL 초기화 비밀번호는 기존 DB 볼륨이 있으면 자동 갱신되지 않습니다.

첫 전환에서는 기존 docker-test-web 컨테이너를 중지하고 Compose 웹으로 교체합니다. 이전 JSON 메모 볼륨 docker-test-data는 삭제하지 않지만 DB로 자동 복사하지는 않습니다. 새 MySQL 저장소는 빈 상태로 시작합니다. 기존 PM2 앱은 계속 중지 상태로 두세요.

## 3. EC2에서 실행 확인 및 제출 캡처

```sh
cd ~/docker-test
docker compose ps
curl http://127.0.0.1:3000/health
```

web과 db가 모두 healthy이고 health 응답에 `storage: mysql`이 있으면 웹·DB가 연결된 상태입니다. 브라우저는 기존 `http://EC2공인IP:3000` 주소로 접속합니다. DB 포트는 외부에 공개하지 않으므로 보안 그룹에 3306을 추가하지 않습니다.

웹에서 메모를 저장한 뒤, 실제 DB 내용은 아래 명령으로 조회합니다.

```sh
docker compose exec db sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql --default-character-set=utf8mb4 -u"$MYSQL_USER" "$MYSQL_DATABASE" -e "SELECT id, content, created_at FROM notes ORDER BY sequence_id DESC LIMIT 10;"'
```

제출할 화면:

1. compose.yaml의 web/db 서비스 설정
2. docker compose ps의 웹·DB healthy 상태
3. 브라우저에서 저장한 메모와 위 SQL 조회 결과
4. Actions의 ci → publish → deploy 성공 화면
5. ECR의 커밋별 이미지 목록

웹 컨테이너를 재생성해도 DB 메모가 유지되는지 확인하려면:

```sh
docker compose up -d --no-build --force-recreate --wait web
```

DB 데이터는 docker-test-mysql-data 볼륨에 저장됩니다. `docker compose down`은 컨테이너를 중지·삭제하지만 볼륨을 유지합니다. `docker compose down -v`는 DB 데이터까지 삭제하므로 데이터 유지 확인에 사용하지 마세요.

로그 확인:

```sh
docker compose logs --tail 50 web db
```

배포 실패 시 기존 Compose 이미지가 있으면 이전 이미지로 웹 복원을 시도합니다. 첫 전환이면 기존 단일 컨테이너를 다시 시작합니다. DB 스키마나 데이터는 되돌리지 않습니다. 앱 교체 중 짧은 접속 중단이 발생할 수 있습니다.

## 로컬에서 Compose 실행

```sh
cp .env.example .env
```

.env의 두 비밀번호를 변경한 뒤 실행합니다. PowerShell에서는 `Copy-Item .env.example .env`를 사용할 수 있습니다.

```sh
docker compose up -d --build --wait
```

http://localhost:3000 에 접속합니다. Compose가 MySQL 준비를 확인하고 웹을 실행합니다. 웹은 db:3306에 접속하며 테이블은 앱 시작 시 자동 생성합니다.

## Node.js 단독 개발

```sh
npm ci
npm start
```

DB_HOST를 설정하지 않은 단독 실행은 기존 JSON 저장 방식으로 동작합니다. Compose 실행은 DB_HOST=db가 설정되므로 MySQL을 사용합니다.

```sh
npm run check
npm test
```

- GET /health: MySQL 연결 상태 포함한 상태 확인 (DB 사용 시)
- GET /api/notes: 메모 목록
- POST /api/notes: JSON `{"content":"메모 내용"}` 저장

메모는 1~10,000자까지 저장합니다. 로그인 없는 학습용 서비스입니다. 한글과 이모지는 utf8mb4로 저장하며, SQL은 파라미터 바인딩을 사용합니다.
