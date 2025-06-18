# DNS & 수학 연산 WebSocket 서버

Redis를 사용한 DNS 서버와 수학 연산 기능을 제공하는 Vapor 웹 서버입니다.

## 프로젝트 개요

이 프로젝트는 Swift Vapor를 사용하여 구현된 다기능 서버입니다:
1. **DNS 서버**: Local DNS와 Upper DNS를 구현한 2단계 DNS 조회 시스템
2. **수학 연산 서버**: 실시간 수학 표현식 계산 서비스

## 주요 기능

### DNS 서버 기능
- **2단계 DNS 조회**: Local DNS → Upper DNS 순서로 도메인 조회
- **Redis 저장소**: 도메인-IP 매핑을 Redis에 저장
- **도메인 등록**: 클라이언트에서 새로운 도메인-IP 매핑 등록
- **캐시 기능**: Upper DNS에서 찾은 결과를 Local DNS에 자동 캐시
- **TTL 지원**: Time To Live를 통한 캐시 만료 관리

### 수학 연산 기능
- **실시간 WebSocket 통신**: 클라이언트와 서버 간 실시간 양방향 통신
- **수학 표현식 계산**: 복잡한 수학 식의 파싱 및 계산
- **연산자 우선순위**: 올바른 수학적 연산 순서 처리
- **괄호 처리**: 중첩된 괄호 표현식 지원
- **오류 처리**: 잘못된 표현식에 대한 명확한 오류 메시지

## DNS 사용 예제

### 지원되는 DNS 기능
- **도메인 조회**: 등록된 도메인의 IP 주소 조회
- **도메인 등록**: 새로운 도메인-IP 매핑 등록
- **도메인 목록**: 등록된 모든 도메인 조회

### DNS 요청/응답 예제

#### 도메인 조회
```json
// 요청
{"type": "query", "domain": "google.com"}

// 응답 (성공)
{
  "domain": "google.com",
  "ipAddress": "8.8.8.8",
  "success": true,
  "message": "상위 DNS에서 발견됨 (로컬에 캐시됨)",
  "source": "upper_dns",
  "timestamp": "2024-01-01T12:00:00Z"
}

// 응답 (실패)
{
  "domain": "nonexistent.com",
  "ipAddress": null,
  "success": false,
  "message": "도메인을 찾을 수 없습니다",
  "source": "not_found",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

#### 도메인 등록
```json
// 요청
{
  "type": "register", 
  "domain": "mysite.com", 
  "ipAddress": "192.168.1.100",
  "recordType": "A"
}

// 응답
{
  "domain": "mysite.com",
  "ipAddress": "192.168.1.100",
  "success": true,
  "message": "도메인이 성공적으로 등록되었습니다",
  "source": "local_dns",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

#### 도메인 목록 조회
```json
// 요청
{"type": "list"}

// 응답
{
  "type": "dns_list",
  "records": [
    {
      "domain": "google.com",
      "ipAddress": "8.8.8.8",
      "recordType": "A",
      "ttl": 3600
    },
    {
      "domain": "mysite.com", 
      "ipAddress": "192.168.1.100",
      "recordType": "A",
      "ttl": 3600
    }
  ],
  "count": 2,
  "timestamp": "2024-01-01T12:00:00Z"
}
```

## 수학 연산 사용 예제

### 지원되는 연산
- 기본 사칙연산: `+`, `-`, `*`, `/`
- 괄호를 이용한 연산 순서 제어: `(3+5)*2`
- 복잡한 표현식: `(3+5)/3-74`

### 입력/출력 예제
```
입력: "(3+5)*2-4"
출력: 12

입력: "10/2+3*4"
출력: 17

입력: "(2+3*4)/(1+2)"
출력: 4.666666666666667

입력: "(2+5?3-74"  // 잘못된 형식
출력: "잘못된 문자가 포함되어 있습니다: ?"
```

## API 엔드포인트

### WebSocket
- **URL**: `ws://localhost:8080/ws`
- **프로토콜**: WebSocket
- **메시지 형식**: JSON (DNS 요청) 또는 Plain text (수학 표현식)

### HTTP API (DNS)
- **도메인 조회**: `GET /api/dns/query/:domain`
- **도메인 등록**: `POST /api/dns/register`
- **도메인 목록**: `GET /api/dns/list`

### HTTP (웹 페이지)
- **기본 페이지**: `GET /` - 서버 상태 확인
- **DNS 테스트 페이지**: `GET /dns` - DNS 기능 테스트 인터페이스
- **수학 연산 테스트 페이지**: `GET /hw1` - 수학 연산 테스트 인터페이스

## 메시지 형식

### DNS 메시지 형식

#### 클라이언트 → 서버
```json
// 도메인 조회
{"type": "query", "domain": "example.com"}

// 도메인 등록  
{"type": "register", "domain": "mysite.com", "ipAddress": "192.168.1.100"}

// 도메인 목록
{"type": "list"}
```

#### 서버 → 클라이언트 (DNS)
```json
// DNS 응답
{
  "domain": "example.com",
  "ipAddress": "1.2.3.4",
  "success": true,
  "message": "로컬 DNS에서 발견됨",
  "source": "local_dns",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### 수학 연산 메시지 형식

#### 클라이언트 → 서버
```
수학 표현식 (예: "(3+5)*2-4")
```

#### 서버 → 클라이언트 (수학)
```json
// 성공 응답
{
  "type": "math_result",
  "expression": "(3+5)*2-4",
  "result": "12",
  "success": true
}

// 오류 응답
{
  "type": "math_error",
  "expression": "(2+5?3-74",
  "error": "잘못된 문자가 포함되어 있습니다: ?",
  "success": false
}
```

## 기술 스택

- **Swift**: 6.0
- **Vapor**: 4.115.0
- **Redis**: 7.x (DNS 데이터 저장)
- **WebSocket**: 실시간 통신을 위한 WebSocket 프로토콜
- **SwiftNIO**: 비동기 이벤트 기반 네트워킹
- **Docker**: 컨테이너화된 배포

## 설치 및 실행

### 1. 로컬 실행 (Redis 필요)

#### Redis 설치 및 실행
```bash
# macOS (Homebrew)
brew install redis
brew services start redis

# 또는 Docker로 Redis 실행
docker run -d --name redis -p 6379:6379 redis:7-alpine
```

#### 서버 실행
```bash
# 의존성 설치
swift package resolve

# 서버 실행
swift run

# 또는 Xcode에서 실행
open Package.swift
```

### 2. Docker Compose 실행 (권장)
```bash
# Redis와 함께 전체 시스템 실행
docker compose up --build

# 백그라운드 실행
docker compose up -d --build
```

### 3. 테스트 접속
- DNS 테스트: `http://localhost:8080/dns`
- 수학 연산 테스트: `http://localhost:8080/hw1`

## 사용법

### DNS 기능 사용
1. DNS 테스트 페이지(`http://localhost:8080/dns`)에 접속
2. "연결" 버튼을 클릭하여 WebSocket 연결
3. 도메인 조회, 등록, 목록 기능 사용
4. 결과 확인

### 수학 연산 사용
1. 수학 연산 테스트 페이지(`http://localhost:8080/hw1`)에 접속
2. "연결" 버튼을 클릭하여 WebSocket 연결
3. 수학 표현식 입력 후 계산
4. 결과 확인

## 미리 설정된 상위 DNS 레코드

서버 시작 시 다음 도메인들이 상위 DNS에 자동으로 등록됩니다:
- google.com → 8.8.8.8
- naver.com → 223.130.200.107
- github.com → 140.82.112.4
- stackoverflow.com → 151.101.193.69
- youtube.com → 142.250.207.110
- facebook.com → 157.240.241.35
- amazon.com → 176.32.103.205
- apple.com → 17.253.144.10
- microsoft.com → 20.112.52.29
- netflix.com → 54.155.178.5

## 프로젝트 구조

```
Sources/computer-network-homework-server/
├── configure.swift          # Vapor 애플리케이션 설정 및 Redis 설정
├── entrypoint.swift        # 애플리케이션 진입점
├── routes.swift            # 라우트 정의 및 WebSocket 핸들러
├── DNSModels.swift         # DNS 관련 데이터 모델
├── DNSService.swift        # DNS 서비스 로직 (Local/Upper DNS)
├── MathCalculator.swift    # 수학 표현식 파싱 및 계산 로직
└── WebSocketController.swift # WebSocket 연결 관리 (DNS + 수학)
```

## DNS 서버 동작 원리

1. **클라이언트 도메인 조회 요청**
2. **Local DNS 확인**: Redis의 `local_dns:domain` 키에서 조회
3. **Local DNS에 없으면 Upper DNS 확인**: Redis의 `upper_dns:domain` 키에서 조회
4. **Upper DNS에서 찾으면**: 결과를 Local DNS에 캐시 (TTL 적용)
5. **두 DNS 모두에서 못 찾으면**: "도메인을 찾을 수 없습니다" 오류 반환
6. **도메인 등록 시**: Local DNS에 저장 (`local_dns:domain` 키로 저장)
