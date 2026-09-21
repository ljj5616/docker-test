# 간단한 ECR 인증 설정

역할과 OIDC 대신 IAM 사용자 액세스 키를 사용합니다. EC2에는 별도 AWS 설정이 필요 없습니다.

## 1. IAM 사용자 만들기

AWS IAM → 사용자 → 사용자 생성에서 `docker-test-deploy`를 만듭니다. AWS 콘솔 로그인 권한은 필요 없습니다.

사용자 상세 → 권한 → 권한 추가 → 인라인 정책 생성 → JSON에 같은 폴더의 `github-ecr-push.json`을 붙여넣고 `docker-test-ecr`로 저장합니다. 이 정책은 docker-test ECR 저장소의 업로드·다운로드만 허용합니다.

## 2. 액세스 키 생성

사용자 상세 → 보안 자격 증명 → 액세스 키 만들기에서 GitHub Actions처럼 AWS 외부에서 사용하는 용도에 맞는 항목을 선택합니다. 생성된 액세스 키 ID와 비밀 액세스 키를 다음 단계에 사용합니다. 루트 계정 키를 만들 필요는 없습니다.

## 3. GitHub Secrets 두 개 추가

Settings → Secrets and variables → Actions → New repository secret:

| 이름 | 값 |
| --- | --- |
| AWS_ACCESS_KEY_ID | 액세스 키 ID |
| AWS_SECRET_ACCESS_KEY | 비밀 액세스 키 |

키는 코드나 채팅, 제출 캡처에 넣지 않습니다. 기존 EC2_HOST, EC2_USER, EC2_SSH_KEY, EC2_KNOWN_HOSTS는 그대로 사용합니다.

## 4. 변경 코드 push

변경 코드를 main에 반영하면 새로운 워크플로가 실행됩니다. 이전 OIDC 실행을 재실행하면 이전 코드를 사용하므로, 반드시 변경한 코드로 실행하세요.

GitHub는 액세스 키로 ECR에 이미지를 업로드합니다. 배포 때는 ECR 로그인 토큰만 SSH로 EC2에 전달하고 EC2의 Docker가 이미지를 다운로드합니다. AWS 개인키는 EC2로 복사하지 않습니다.

EC2에 Docker와 Compose가 설치되어 있어야 합니다. 기존 docker-test-web 컨테이너는 첫 배포에서 Compose 웹으로 교체합니다. 기존 JSON 볼륨 docker-test-data는 보존하고 새 MySQL 데이터는 docker-test-mysql-data에 저장합니다. DB 비밀번호는 EC2의 ~/docker-test/.env에 최초 한 번 자동 생성합니다. 기존 PM2는 중지 상태여야 합니다. GitHub 실행기의 SSH 접근도 허용되어 있어야 합니다.

태그는 커밋SHA-실행번호-시도번호로 생성합니다. GitHub Actions에서 ci → publish → deploy 성공을 확인하세요.

## 과제 캡처

- Actions의 ci, publish, deploy 성공 화면
- ECR의 서로 다른 커밋 이미지 태그 목록
- EC2의 docker compose ps 결과와 브라우저 메모 저장 화면
- MySQL 테이블에서 같은 메모를 조회한 화면

Compose 설치 및 DB 조회 명령은 프로젝트 README.md에 있습니다.
