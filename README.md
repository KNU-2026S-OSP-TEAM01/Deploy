# Open Park Deploy Repository

Open Park의 프론트엔드, 백엔드, PostgreSQL을 Docker Compose로 운영 배포하기 위한 저장소입니다.

프론트엔드와 백엔드 이미지는 GitHub Container Registry(GHCR)에서 받아오며, GitHub Actions 배포 워크플로우가 서버에 접속해 배포 스크립트를 실행하는 것을 전제로 합니다.

배포 시 `tags/prod.versions`에 정의된 이미지 태그와 GitHub Actions secret 또는 서버 환경변수를 합쳐 `.env.runtime`을 생성한 뒤 Docker Compose로 서비스를 갱신합니다.

## 구성

```text
.
├── docker-compose.yml      # Open Park 서비스 정의
├── scripts/
│   ├── deploy.sh           # 배포 실행 스크립트
│   └── env.sh              # .env.runtime 생성 스크립트
├── tags/
│   └── prod.versions       # 운영 이미지 태그 파일
├── .env.example            # 필요한 환경변수 예시
└── README.md
```

## 서비스

| 서비스 | 이미지 | 역할 | 기본 컨테이너 포트 |
| --- | --- | --- | --- |
| `parking-lot-frontend` | `ghcr.io/knu-2026s-osp-team01/parking-lot-frontend:${FRONTEND_TAG}` | 웹 프론트엔드 | `80` |
| `parking-lot-backend` | `ghcr.io/knu-2026s-osp-team01/parking-lot-backend:${BACKEND_TAG}` | API 서버 | `8000` |
| `postgresql` | `postgres:16` | PostgreSQL 데이터베이스 | 내부 네트워크 |

모든 서비스는 `openpark-net` Docker 네트워크에 연결됩니다. PostgreSQL 데이터는 `postgres_data` 볼륨에 저장됩니다.

## 배포 환경

- 배포 서버에 Docker 및 Docker Compose v2가 설치되어 있어야 합니다.
- GitHub Actions에서 배포 서버에 SSH로 접속할 수 있어야 합니다.
- 배포 서버 또는 GitHub Actions secret에 GHCR 이미지를 pull 할 수 있는 인증 정보가 준비되어 있어야 합니다.
- 운영 환경변수는 GitHub Actions secret 또는 배포 서버의 환경변수로 주입합니다.

## 환경변수

`.env.example`은 GitHub Actions secret 또는 서버 환경변수로 준비해야 하는 값의 예시입니다.

주요 환경변수는 다음과 같습니다.

| 변수 | 설명 |
| --- | --- |
| `PORT_PARKING_LOT_FRONTEND` | 프론트엔드 외부 노출 포트 |
| `PORT_PARKING_LOT_BACKEND` | 백엔드 외부 노출 포트 |
| `POSTGRES_DB` | PostgreSQL 데이터베이스 이름 |
| `POSTGRES_USER` | PostgreSQL 사용자명 |
| `POSTGRES_PASSWORD` | PostgreSQL 비밀번호 |
| `SECRET_KEY` | 백엔드 애플리케이션 secret key |
| `AES_KEY` | AES 암호화 키 |
| `HMAC_KEY` | HMAC 키 |
| `PARKING_LOT_FRONTEND_URL` | 프론트엔드 접근 URL |
| `PARKING_LOT_BACKEND_URL` | 백엔드 접근 URL |
| `GHCR_USERNAME` | GHCR 로그인용 GitHub 사용자명 |
| `GHCR_READ_PAT` | GHCR 이미지 pull 권한이 있는 PAT |
| `SERVER_HOST` | 배포 서버 호스트 |
| `SERVER_USER` | 배포 서버 사용자 |
| `SERVER_PORT` | SSH 포트 |
| `SERVER_SSH_KEY` | SSH private key |
| `SERVER_PASSWORD` | 서버 비밀번호가 필요한 경우 사용 |

> 주의: 현재 `docker-compose.yml`은 `PORT_FRONTEND`, `PORT_BACKEND`를 참조하지만, `scripts/env.sh`와 `.env.example`은 `PORT_PARKING_LOT_FRONTEND`, `PORT_PARKING_LOT_BACKEND`를 사용합니다. 배포 전 변수명을 한쪽으로 통일해야 합니다.

## 이미지 태그 관리

운영 배포에 사용할 프론트엔드/백엔드 이미지 태그는 `tags/prod.versions`에 작성합니다.

예시:

```env
FRONTEND_TAG=latest
BACKEND_TAG=latest
```

특정 커밋, 릴리스, 빌드 번호로 배포하려면 해당 태그 값을 변경한 뒤 배포합니다.

## 배포 흐름

GitHub Actions 워크플로우는 일반적으로 다음 흐름으로 이 저장소의 배포 스크립트를 실행합니다.

1. 프론트엔드 또는 백엔드 저장소에서 이미지가 빌드되어 GHCR에 push 됩니다.
2. 배포 워크플로우가 이 저장소의 `tags/prod.versions`에 배포할 이미지 태그를 반영합니다.
3. GitHub Actions가 배포 서버에 접속합니다.
4. 서버에서 `scripts/deploy.sh`가 실행됩니다.
5. `scripts/env.sh`가 `tags/prod.versions`와 환경변수를 합쳐 `.env.runtime`을 생성합니다.
6. Docker Compose가 최신 이미지를 pull 하고 서비스를 갱신합니다.
7. 사용하지 않는 Docker 이미지를 정리합니다.

`scripts/deploy.sh` 내부 동작은 다음과 같습니다.

| 단계 | 내용 |
| --- | --- |
| 환경 파일 생성 | `scripts/env.sh "$TARGET_ENV"` 실행 |
| 이미지 pull | `docker compose -p openpark --env-file .env.runtime -f docker-compose.yml pull` |
| 서비스 갱신 | `docker compose -p openpark --env-file .env.runtime -f docker-compose.yml up -d --remove-orphans` |
| 이미지 정리 | `docker image prune -f` |

## GHCR 로그인

Private GHCR 이미지를 사용하는 경우 GitHub Actions 또는 배포 서버에서 GHCR 로그인이 선행되어야 합니다. 토큰에는 최소한 대상 패키지를 읽을 수 있는 권한이 필요합니다.

## 운영 주의사항

- `.env.runtime`은 배포 시 생성되는 런타임 환경 파일입니다. 민감정보가 포함되므로 커밋하지 않습니다.
- `.env`는 로컬 확인용 예시 기반 파일로만 사용하고 커밋하지 않습니다.
- PostgreSQL 데이터는 Docker named volume인 `postgres_data`에 저장됩니다.
- `docker image prune -f`가 배포 마지막에 실행되어 사용하지 않는 이미지를 정리합니다.
- 프론트엔드와 백엔드는 같은 Docker 네트워크에서 통신할 수 있습니다.
