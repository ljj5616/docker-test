# docker-test — 간단한 메모장

Node.js 입력창과 저장 버튼으로 구성한 메모장입니다. 메모는 JSON 파일에 저장됩니다. Node.js 또는 Docker로 실행할 수 있으며 DB 설치는 필요 없습니다.

## Docker로 실행

Docker가 실행 중인 환경에서 프로젝트 루트의 Dockerfile로 이미지를 만듭니다.

```sh
docker build -t docker-test .
docker run -d --name docker-test-web -p 3000:3000 -v docker-test-data:/app/data docker-test
```

로컬에서는 http://localhost:3000, EC2에서는 `http://EC2공인IP:3000`으로 접속합니다. EC2 보안 그룹에서 3000번 포트 접근이 허용되어 있어야 합니다.

이미 PM2 앱이 3000번 포트를 사용 중이라면 먼저 `pm2 stop docker-test`를 실행하세요. 기존 앱을 유지한 채 시험하려면 `-p 3001:3000`으로 실행하고 3001번 포트로 접속할 수 있습니다.

`-v docker-test-data:/app/data`는 메모를 Docker 볼륨에 저장합니다. 컨테이너를 삭제해도 해당 볼륨을 다시 연결하면 메모가 유지됩니다. 기존 PM2 앱의 data/notes.json은 이 볼륨으로 자동 복사되지 않습니다.

```sh
docker logs docker-test-web
docker stop docker-test-web
docker start docker-test-web
```

컨테이너에서는 PM2 없이 Node.js를 직접 실행합니다. 현재 GitHub Actions 배포는 기존 PM2 방식이며, Docker 자동 배포는 다음 단계에서 변경합니다.

## 로컬 실행

Node.js 24 기준입니다.

```sh
npm install
npm start
```

http://localhost:3000 에 접속합니다. 기본 수신 주소는 `0.0.0.0:3000`입니다.

## EC2 최초 설정 (한 번만)

Amazon Linux의 ec2-user 계정, Node.js와 Git이 설치되어 있고 저장소가 `~/docker-test`에 clone된 상태를 기준으로 합니다.

기존 `npm start`는 Ctrl+C로 종료하세요. 이전 안내대로 notepad 서비스를 등록했다면 먼저 `sudo systemctl disable --now notepad`로 중지합니다. 등록하지 않았다면 생략합니다. 이전 /opt/notepad 폴더를 삭제할 필요는 없습니다.

```sh
cd ~/docker-test
git pull --ff-only origin main
sudo npm install -g pm2
npm ci
pm2 startOrRestart ecosystem.config.cjs --update-env
pm2 save
```

PM2가 앱을 실행하므로 SSH 터미널을 닫아도 유지됩니다. EC2 재부팅 후에도 자동 실행하려면 `pm2 startup`을 실행하고 출력되는 sudo 명령을 실행한 뒤 `pm2 save`를 실행하세요. 서비스 파일을 직접 작성할 필요는 없습니다.

기존 수동 실행의 메모는 같은 data/notes.json을 사용합니다. 이전 systemd 방식으로 저장한 /var/lib/notepad/notes.json은 자동 이동되지 않습니다. 필요하면 앱을 중지하고 기존 데이터를 백업한 뒤 옮기세요.

## GitHub 자동 배포

main에 push 또는 merge하면 **테스트 → SSH 접속 → git pull → 테스트 → PM2 재시작**을 실행합니다. PR에서는 테스트만 실행합니다. ENABLE_CD 변수, production 환경, EC2 runner 등록은 필요 없습니다.

Settings → Secrets and variables → Actions → Repository secrets에 다음 값을 등록합니다. 이미 등록했다면 그대로 사용합니다.

| 이름 | 값 |
| --- | --- |
| EC2_HOST | EC2 공인 IP 또는 DNS (프로토콜과 포트 제외) |
| EC2_USER | ec2-user |
| EC2_SSH_KEY | EC2 접속용 PEM 개인키 전체 내용 |
| EC2_KNOWN_HOSTS | EC2 주소와 SSH 호스트 공개키로 구성한 한 줄 |

호스트 키는 신뢰할 수 있는 EC2 터미널에서 `sudo cat /etc/ssh/ssh_host_ed25519_key.pub`로 확인합니다. 출력 앞에 EC2_HOST와 동일한 주소와 공백을 붙입니다: `EC2주소 ssh-ed25519 공개키문자열`.

EC2에서 `git pull --ff-only origin main`이 암호 입력 없이 성공해야 합니다. 비공개 저장소는 EC2의 GitHub 읽기 권한(예: 읽기 전용 deploy key)을 별도로 설정해야 합니다. EC2 접속용 PEM 키와 GitHub 저장소 접근 권한은 서로 다릅니다. EC2 프로젝트는 main 브랜치로 유지하고 코드는 로컬 PC에서 수정해 push하세요.

배포 시점의 최신 main을 가져와 EC2에서도 테스트한 뒤 재시작합니다. 실패하면 Actions가 실패로 표시되며 자동 버전 복원은 하지 않습니다.

## 접속 및 확인

EC2 보안 그룹에서 접속할 PC에 TCP 3000을 허용한 뒤 `http://EC2공인IP:3000`으로 접속합니다. 자동 배포에는 GitHub 실행기에서 SSH(TCP 22)로 접근할 수 있어야 합니다. SSH 규칙이 내 PC IP만 허용한다면 GitHub에서 접속할 수 없습니다. 일반 GitHub 제공 실행기의 IP는 고정되지 않으므로 배포용 접근 범위를 별도로 설정해야 합니다.

```sh
pm2 status
pm2 logs docker-test --lines 30
curl http://127.0.0.1:3000/health
```

GitHub Actions에서 ci와 deploy가 모두 초록색이면 배포 완료입니다. 최초 설정 후 Actions → Node.js CI and CD → Run workflow → main으로 실행할 수도 있습니다.

## 개발 및 테스트

```sh
npm run dev
npm run check
npm test
```

- GET /health: 상태 확인
- GET /api/notes: 메모 목록
- POST /api/notes: JSON `{"content":"메모 내용"}` 저장

메모는 1~10,000자까지 저장합니다. 파일 저장 방식이므로 앱 프로세스는 하나만 실행합니다. data/는 Git에서 제외되어 재배포 시 유지됩니다. 로그인 없는 학습용 공유 메모장입니다.
