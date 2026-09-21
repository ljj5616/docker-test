# 작은 메모장

Node.js 기본 모듈만 사용하는 간단한 메모장 웹 서비스입니다. 단어나 문장을 입력하고 **메모 저장**을 누르면 목록에 추가됩니다. 새로고침하거나 서버를 재시작해도 메모가 남습니다.

이번 단계는 컨테이너 도입 전의 애플리케이션과 CI/CD 구성입니다. Docker, Compose, ECR은 아직 포함하지 않습니다.

## 로컬 실행

Node.js 24 LTS와 npm을 설치한 후 실행합니다.

```sh
npm ci
npm start
```

브라우저에서 http://localhost:3000 을 엽니다. 개발 중 자동 재시작은 `npm run dev`, 종료는 Ctrl+C입니다.

```sh
npm run check
npm test
```

메모는 기본적으로 `data/notes.json`에 저장됩니다. Git에는 포함되지 않습니다. 저장 작업을 순차 처리하고 임시 파일을 교체하므로 같은 프로세스의 동시 요청으로 메모가 덮어써지는 것을 방지합니다. 하나의 저장 경로에는 서버 프로세스 하나만 실행하세요.

| 환경 변수 | 기본값 | 용도 |
| --- | --- | --- |
| PORT | 3000 | HTTP 포트 |
| HOST | 127.0.0.1 | 수신 주소 |
| DATA_DIR | 프로젝트의 data 폴더 | 메모 저장 위치 |

PowerShell에서 설정하는 예시:

```powershell
$env:PORT = '3001'
npm start
```

## API

| 메서드 | 경로 | 동작 |
| --- | --- | --- |
| GET | /health | 프로세스 상태 확인 |
| GET | /api/notes | 최신순 메모 목록 |
| POST | /api/notes | 메모 저장 |

저장 요청은 `Content-Type: application/json`, 본문은 `{"content":"안녕하세요"}`입니다. 메모는 공백을 제외하고 1~10,000자로 제한하며, 요청 본문은 최대 64 KiB입니다. 정상 저장 시 201과 `id`, `content`, `createdAt`을 반환합니다.

## CI: GitHub Actions

`.github/workflows/pipeline.yml`에서 main 브랜치의 push와 PR마다 다음을 실행합니다.

1. Node.js 24 설정 및 `npm ci`
2. JavaScript 구문 검사
3. 저장·조회·동시 저장·재시작 영속성·잘못된 입력 테스트
4. 배포용 `app.tar.gz` 아티팩트 생성

별도 컴파일이 필요 없는 순수 JavaScript 앱이므로 테스트한 실행 파일을 그대로 패키징합니다.

## CD: 일반 Linux 서버에 배포

Amazon Linux 2023의 systemd 서버를 기준으로 합니다. GitHub 제공 runner가 SSH로 EC2에 접속하므로 EC2에 Actions runner를 설치할 필요가 없습니다. CI가 성공한 main 브랜치 커밋만 배포하며, PR은 배포하지 않습니다. 서버 준비 전에는 `ENABLE_CD`가 없어 CD가 자동으로 건너뛰어집니다.

### 1. 서버 준비

서버에 Node.js 24, npm, curl, tar를 설치하고 `node --version`, `command -v node`를 확인합니다. 서비스 파일은 `/usr/bin/node`를 사용합니다. 설치 경로가 다르면 `deploy/notepad.service`의 ExecStart를 수정하세요.

아래 예시는 SSH 접속 계정이 `ec2-user`인 경우입니다. 기존 `npm start`를 Ctrl+C로 종료한 뒤 프로젝트 루트에서 실행하세요. `notepad` 사용자가 이미 있으면 useradd는 생략합니다.

```sh
sudo useradd --system --home /var/lib/notepad --shell /usr/sbin/nologin notepad
sudo install -d -o ec2-user -g ec2-user -m 755 /opt/notepad /opt/notepad/releases /opt/notepad/incoming
sudo install -d -o notepad -g notepad -m 700 /var/lib/notepad
sudo install -m 644 deploy/notepad.service /etc/systemd/system/notepad.service
sudo systemctl daemon-reload
sudo systemctl enable notepad
```

이 명령은 서버에 체크아웃한 프로젝트 루트에서 실행합니다. 최초 배포 전에는 `current`가 없으므로 아직 서비스를 시작하지 않습니다.

`sudo visudo -f /etc/sudoers.d/notepad-deploy`로 아래 한 줄을 추가합니다. `/usr/bin/systemctl` 경로도 서버에서 확인하세요.

```text
ec2-user ALL=(root) NOPASSWD: /usr/bin/systemctl restart notepad
```

### 2. GitHub 설정

- Settings → Secrets and variables → Actions → Secrets에 아래 값을 등록합니다. 개인키는 저장소나 채팅에 붙여넣지 않습니다.

| Secret | 값 |
| --- | --- |
| EC2_HOST | EC2 공인 IPv4 또는 DNS 이름 (프로토콜과 포트 제외) |
| EC2_USER | ec2-user |
| EC2_SSH_KEY | EC2 접속용 PEM 개인키 전체 내용 (암호 입력 없이 사용하는 키) |
| EC2_KNOWN_HOSTS | 검증한 EC2 SSH 호스트 키 항목 |

`EC2_KNOWN_HOSTS`는 AWS 콘솔 등 신뢰할 수 있는 경로로 접속한 EC2 터미널에서 아래 명령으로 만듭니다. `YOUR_EC2_HOST`는 위 EC2_HOST와 동일하게 바꿉니다. 출력된 한 줄을 Secret 값으로 저장합니다.

```sh
sudo awk '{print "YOUR_EC2_HOST " $1 " " $2}' /etc/ssh/ssh_host_ed25519_key.pub
```

EC2는 GitHub runner에서 접근 가능한 주소여야 하며, 보안 그룹에서 해당 배포 실행기의 SSH(TCP 22) 접근을 허용해야 합니다. 내 PC IP만 허용한 규칙으로는 GitHub runner가 접속할 수 없습니다. 일반 GitHub 제공 runner의 출발 IP는 고정되지 않으므로 허용할 네트워크 범위를 별도로 계획하세요.

- Settings → Environments에서 `production`을 생성합니다. 필요하면 배포 승인자를 지정합니다.
- Settings → Secrets and variables → Actions → Variables에 `ENABLE_CD`를 값 `true`로 추가합니다.
- main 브랜치에 push하거나 Actions에서 워크플로를 main으로 수동 실행합니다.

GitHub runner가 CI 아티팩트를 다운로드하고 SCP로 `/opt/notepad/incoming/<실행번호>-<시도번호>`에 전송합니다. SSH로 배포 스크립트를 실행해 `/opt/notepad/releases/<실행번호>-<시도번호>`에 풀고, `current` 링크를 교체하고 systemd 서비스를 재시작합니다. 상태 및 메모 조회 API를 확인하며, 실패하면 이전 릴리스가 있는 경우 복원합니다. 첫 배포 실패 시에는 이전 버전이 없으므로 로그를 확인해야 합니다.

메모 파일은 배포 디렉터리 밖인 `/var/lib/notepad/notes.json`에 있어 재배포해도 유지됩니다. 기존 수동 실행의 `data/notes.json`은 자동 이동되지 않습니다. 기존 메모가 필요하면 서버를 종료한 상태에서 해당 파일을 새 저장 위치로 복사하고 소유자를 `notepad:notepad`로 설정하세요. 릴리스와 incoming 파일은 자동 삭제하지 않습니다. 오래된 파일은 현재 및 복구용 버전을 남기고 관리하세요.

### 3. 접속 및 확인

기본 서비스는 서버 내부에서만 접근합니다. 로컬 PC에서 SSH 터널을 열면 브라우저로 확인할 수 있습니다.

```sh
ssh -L 3000:127.0.0.1:3000 user@your-server
```

이후 로컬 브라우저에서 http://localhost:3000 을 엽니다.

```sh
sudo systemctl status notepad
sudo journalctl -u notepad -n 100 --no-pager
curl http://127.0.0.1:3000/health
```

이 앱은 로그인 없이 메모를 공유하는 학습용 서비스입니다. 외부 공개가 필요하면 접근 제어와 HTTPS를 구성하세요.

## 다음 과제 단계

현재 구성의 Node.js 실행 부분을 Docker 이미지로 옮기고, CI에 이미지 빌드 및 ECR 업로드를 추가할 수 있습니다. 여러 컨테이너를 연동할 때에는 JSON 저장소를 별도 데이터베이스로 교체하고 Compose로 웹 앱과 DB를 함께 실행하는 구성을 추가하면 됩니다.
