# docker-test — 간단한 메모장

Node.js로 메모를 입력하고 JSON 파일에 저장하는 웹 서비스입니다.

## 로컬 실행

```sh
npm ci
npm start
```

Node.js 24를 사용합니다. http://localhost:3000 으로 접속합니다.

## Docker 수동 실행

```sh
docker build -t docker-test .
docker run -d --name docker-test-web --restart unless-stopped -p 3000:3000 -v docker-test-data:/app/data docker-test
```

PM2 등 다른 프로세스가 3000번 포트를 사용 중이면 먼저 중지합니다. 메모는 docker-test-data 볼륨에 저장됩니다. 컨테이너를 교체해도 볼륨을 재사용하면 유지됩니다. 이전 PM2의 data/notes.json은 자동 복사되지 않습니다.

## GitHub Actions → ECR → EC2

이미지 저장소: `514287510278.dkr.ecr.ap-northeast-2.amazonaws.com/docker-test`

1. **ci**: Node.js 테스트 → Docker 빌드 → 컨테이너 저장·재시작 테스트
2. **publish**: 검증한 이미지를 ECR에 업로드 (태그: 커밋SHA-실행번호-시도번호)
3. **deploy**: SSH로 EC2 접속 → 해당 이미지 pull → 컨테이너 교체

PR은 CI만 실행하고, main push/merge 또는 main 수동 실행은 업로드와 배포까지 진행합니다. EC2에서 git pull하거나 PM2를 재시작하는 방식은 더 이상 사용하지 않습니다. EC2의 Git 작업 폴더가 갱신되지 않아도 정상입니다.

**처음에는 [AWS 인증 설정 안내](deploy/aws/README.md)를 완료해야 합니다.** ECR 접근 권한이 있는 IAM 사용자 액세스 키를 GitHub Secrets에 등록합니다. OIDC와 IAM 역할은 사용하지 않습니다. EC2에 AWS 키나 AWS CLI를 설치할 필요도 없습니다.

기존 Repository secrets는 유지합니다.

| 이름 | 값 |
| --- | --- |
| EC2_HOST | EC2 공인 IP 또는 DNS |
| EC2_USER | ec2-user |
| EC2_SSH_KEY | EC2 접속용 PEM 개인키 |
| EC2_KNOWN_HOSTS | EC2주소 ssh-ed25519 호스트공개키 |
| AWS_ACCESS_KEY_ID | IAM 사용자 액세스 키 ID |
| AWS_SECRET_ACCESS_KEY | 해당 비밀 액세스 키 |

ENABLE_CD 변수, production 환경, EC2 self-hosted runner 등록은 필요 없습니다. SSH 호스트 공개키는 신뢰할 수 있는 EC2 터미널에서 `sudo cat /etc/ssh/ssh_host_ed25519_key.pub`로 확인하고 앞에 EC2_HOST와 같은 주소를 붙입니다.

## 실행 확인

```sh
docker ps
docker logs docker-test-web
curl http://127.0.0.1:3000/health
```

브라우저에서 `http://EC2공인IP:3000`에 접속합니다. 보안 그룹은 브라우저의 TCP 3000 및 GitHub 실행기의 SSH(TCP 22) 접근을 허용해야 합니다. 내 PC IP만 허용한 SSH 규칙으로는 GitHub 실행기가 접속할 수 없습니다.

배포는 기존 docker-test-data 볼륨을 유지합니다. 교체 중 잠시 중단이 발생하며, 새 컨테이너 상태 확인 실패 시 이전 컨테이너가 있으면 복원합니다. Docker 이미지와 볼륨을 임의로 정리하지 않습니다.

## 개발 및 테스트

```sh
npm run check
npm test
```

- GET /health: 상태 확인
- GET /api/notes: 메모 목록
- POST /api/notes: JSON `{"content":"메모 내용"}` 저장

메모는 1~10,000자까지 저장됩니다. 파일 저장 방식이므로 앱은 하나만 실행합니다. 로그인 없는 학습용 서비스입니다.

## 과제 진행 상태

- Dockerfile 및 컨테이너 실행: 구성 완료
- GitHub Actions Docker CI 및 ECR 배포: 코드 작성 완료, AWS 액세스 키 등록 후 실제 실행 확인 필요
- Compose 웹·DB 연동: 다음 단계

제출용 캡처 목록은 [AWS 설정 안내](deploy/aws/README.md)의 마지막 항목을 참고하세요.
