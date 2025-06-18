# Computer Network HW3: Link State Routing

Swift Vapor로 구현된 Link State 라우팅 알고리즘 서버입니다.

## 주요 기능

- **Dijkstra 알고리즘**: 최단 경로 계산
- **네트워크 토폴로지 관리**: 노드와 링크 정보 관리
- **실시간 시각화**: SVG 기반 네트워크 다이어그램
- **WebSocket 통신**: 실시간 클라이언트-서버 통신

## 기본 네트워크 토폴로지

6개 라우터(A-F)와 8개 양방향 링크:
- A-B(4), A-D(2), B-C(3), B-E(1)
- C-E(2), C-F(6), D-E(5), E-F(1)

## API 엔드포인트

### WebSocket
- **URL**: `ws://localhost:8080/ws`
- **메시지**: JSON 형식

### HTTP API
- **토폴로지 조회**: `GET /api/routing/topology`
- **최단 경로 계산**: `POST /api/routing/shortest-path`
- **웹 인터페이스**: `GET /hw3`

## 메시지 형식

### 토폴로지 전송 (클라이언트 → 서버)
```json
{
  "type": "set_topology",
  "nodes": [
    {"id": "A", "name": "Router A", "x": 100, "y": 200}
  ],
  "links": [
    {"from": "A", "to": "B", "cost": 4, "bidirectional": true}
  ]
}
```

### 최단 경로 계산 (클라이언트 → 서버)
```json
{
  "type": "shortest_path",
  "sourceId": "A",
  "destinationId": "F"
}
```

### 최단 경로 응답 (서버 → 클라이언트)
```json
{
  "success": true,
  "sourceId": "A",
  "destinationId": "F",
  "totalCost": 6,
  "algorithm": "link_state",
  "path": [
    {"nodeId": "A", "nodeName": "Router A", "cumulativeCost": 0},
    {"nodeId": "B", "nodeName": "Router B", "cumulativeCost": 4},
    {"nodeId": "E", "nodeName": "Router E", "cumulativeCost": 5},
    {"nodeId": "F", "nodeName": "Router F", "cumulativeCost": 6}
  ]
}
```

## 사용법

1. 서버 실행: `swift run computer-network-homework-server serve --hostname 0.0.0.0 --port 8080`
2. 웹 접속: `http://localhost:8080/hw3`
3. "연결" 버튼으로 WebSocket 연결
4. "토폴로지 전송" 버튼으로 네트워크 구조 전송
5. 출발/도착 노드 선택 후 "최단 경로 계산"
6. 네트워크 다이어그램에서 시각적 경로 확인

## 시각화 기능

- **색상 코딩**: 출발(파란색), 도착(빨간색), 경로(주황색)
- **애니메이션**: 최단 경로 링크 강조 효과
- **실시간 업데이트**: 계산 결과 즉시 반영

## 기술 스택

- Swift 6.0
- Vapor 4.115.0
- WebSocket
- SVG/CSS3

## 예제 경로

- **A → F**: A → B → E → F (비용: 6)
- **A → C**: A → B → C (비용: 7)
- **A → E**: A → B → E (비용: 5)
