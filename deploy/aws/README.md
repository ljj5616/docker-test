# ECR 권한 설정 — 최초 한 번

저장소: `514287510278.dkr.ecr.ap-northeast-2.amazonaws.com/docker-test`

GitHub는 업로드 역할, EC2는 다운로드 역할을 사용합니다. 기존 EC2 SSH Secrets 네 개는 그대로 유지합니다. AWS 액세스 키를 GitHub에 추가할 필요가 없는 OIDC 방식입니다.

## 1. GitHub용 역할

1. AWS IAM → 자격 증명 공급자 → 공급자 추가 → OpenID Connect를 선택합니다.
2. 공급자 URL: `https://token.actions.githubusercontent.com`, 대상(Audience): `sts.amazonaws.com`. 같은 공급자가 이미 있으면 재사용합니다.
3. IAM → 정책 → 정책 생성 → JSON에서 `github-ecr-push.json` 내용을 붙여넣고 `docker-test-ecr-push`로 생성합니다.
4. IAM → 역할 → 역할 생성 → 사용자 지정 신뢰 정책에서 `github-trust.json` 내용을 붙여넣습니다.
5. 위 정책을 연결하고 역할 이름을 **github-docker-test-ecr**로 지정합니다. 코드가 이 이름의 ARN을 사용합니다.

신뢰 정책은 `ljj5616/docker-test` 저장소의 main 브랜치만 허용합니다. 다른 저장소 이름이나 브랜치로 변경할 때에는 신뢰 정책도 변경해야 합니다.

## 2. EC2용 역할

1. IAM → 정책 → 정책 생성 → JSON에서 `ec2-ecr-pull.json` 내용을 붙여넣고 `docker-test-ecr-pull`로 생성합니다.
2. IAM → 역할 → 역할 생성 → AWS 서비스 → EC2를 선택합니다.
3. 위 정책을 연결하고 `ec2-docker-test-ecr`로 생성합니다.
4. EC2 → 인스턴스 선택 → 작업 → 보안 → IAM 역할 수정에서 역할을 연결합니다.

이미 EC2에 다른 역할이 연결되어 있다면 기존 역할에 pull 정책을 추가하세요. 기존 역할을 불필요하게 교체하지 않습니다.

EC2에서 확인합니다.

```sh
aws --version
aws sts get-caller-identity
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 514287510278.dkr.ecr.ap-northeast-2.amazonaws.com
```

AWS CLI가 없다면 Amazon Linux 2023에서 `sudo dnf install -y awscli2`로 설치합니다. IAM 역할을 연결하면 EC2에 `aws configure`로 개인 액세스 키를 저장할 필요가 없습니다.

## 3. 배포 전 확인

- Docker 엔진 실행 및 ec2-user의 Docker 실행 권한이 필요합니다. 이미 Docker 수동 실행이 성공했다면 그대로 사용합니다.
- 기존 PM2 앱은 중지 상태여야 합니다. PM2 재부팅 복원을 설정했다면 `pm2 delete docker-test`와 `pm2 save --force`로 이 앱을 PM2 목록에서도 제거합니다. 메모 파일은 삭제되지 않습니다.
- 컨테이너 이름 `docker-test-web`, 데이터 볼륨 `docker-test-data`를 그대로 사용합니다. 다른 이름으로 수동 실행했다면 먼저 실행 상태를 확인하세요.
- 기존 TCP 3000 및 SSH 접근 설정은 그대로 사용합니다.
- 현재 EC2는 x86_64이므로 GitHub의 ubuntu-latest에서 빌드한 linux/amd64 이미지를 사용합니다. ARM EC2로 변경할 때에는 빌드 플랫폼도 변경해야 합니다.

## 4. 실행 및 과제 캡처

AWS 설정을 완료한 후 변경 코드를 main에 push합니다. Actions에서 **ci → publish → deploy**가 성공하는지 확인하세요. 수동 실행 메뉴 이름은 `Docker CI and ECR CD`입니다.

태그는 `커밋SHA-실행번호-시도번호`입니다. 같은 커밋을 다시 실행해도 별도 태그를 사용하므로 ECR의 태그 변경 불가 설정도 사용할 수 있습니다. latest 태그에 의존하지 않습니다.

EC2는 지정된 태그를 pull하고 컨테이너를 교체합니다. git pull이나 Node.js·PM2 설치는 배포에 사용하지 않습니다. 기존 Docker 볼륨을 재사용하며 교체 중 잠시 접속이 끊길 수 있습니다. 새 컨테이너 상태 확인이 실패하면 이전 컨테이너가 있을 경우 다시 시작합니다.

제출 화면:

1. Actions의 ci/publish/deploy 성공 화면과 Docker 빌드·컨테이너 테스트 로그
2. ECR의 커밋별 이미지 태그 목록 (서로 다른 커밋 두 개 권장)
3. `docker ps`에서 ECR 이미지로 실행 중인 화면
4. 브라우저에서 메모 저장 및 재배포 후 유지 확인

Docker Compose와 DB 연결은 아직 구현 전이며 다음 과제 단계입니다.

공식 참고: [GitHub OIDC](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws), [ECR 업로드 권한](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-push-iam.html).
