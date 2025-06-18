import Vapor
import Foundation

// MARK: - WebSocket Controller
struct WebSocketController: Sendable {
    private let calculator = MathCalculator()
    
    func handleWebSocket(_ request: Request, webSocket: WebSocket) {
        print("🔗 새로운 클라이언트 연결됨")
        
        // 환영 메시지
        let welcomeMessage = """
        {
            "type": "welcome",
            "message": "DNS & 수학 연산 서버에 연결되었습니다. JSON 형식의 DNS 요청 또는 수식을 입력해 주세요.",
            "examples": {
                "dns_query": {"type": "query", "domain": "google.com"},
                "dns_register": {"type": "register", "domain": "example.com", "ipAddress": "192.168.1.1"},
                "dns_list": {"type": "list"},
                "math": "(3+5)*2-4"
            }
        }
        """
        
        webSocket.send(welcomeMessage)
        
        // 메시지 수신 처리
        webSocket.onText { webSocket, text in
            Task {
                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                print("📨 수신된 메시지: \(trimmedText)")
                
                let responseMessage: String
                
                // JSON 메시지인지 확인
                if trimmedText.hasPrefix("{") && trimmedText.hasSuffix("}") {
                    // DNS 요청 처리
                    do {
                        guard let data = trimmedText.data(using: .utf8) else {
                            responseMessage = self.createErrorResponse("잘못된 텍스트 형식입니다")
                            try? await webSocket.send(responseMessage)
                            return
                        }
                        
                        let dnsMessage = try JSONDecoder().decode(DNSMessage.self, from: data)
                        let dnsService = DNSService.create(for: request)
                        
                        switch dnsMessage {
                        case .query(let domain):
                            print("DNS 조회: \(domain)")
                            let dnsResponse = try await dnsService.queryDomain(domain)
                            responseMessage = try self.createJSONResponse(dnsResponse)
                            print("DNS 응답: \(dnsResponse.ipAddress ?? "Not Found")")
                            
                        case .register(let registration):
                            print("DNS 등록: \(registration.domain) -> \(registration.ipAddress)")
                            let dnsResponse = try await dnsService.registerDomain(registration)
                            responseMessage = try self.createJSONResponse(dnsResponse)
                            print("DNS 등록 완료")
                            
                        case .list:
                            print("DNS 목록 조회")
                            let records = try await dnsService.listRegisteredDomains()
                            responseMessage = try self.createListResponse(records)
                            print("총 \(records.count)개 레코드 조회됨")
                        }
                        
                    } catch {
                        responseMessage = self.createErrorResponse("DNS 요청 처리 오류: \(error.localizedDescription)")
                        print("DNS 오류: \(error)")
                    }
                } else {
                    // 수학 연산 처리 (기존 기능)
                    print("🧮 수학 연산: \(trimmedText)")
                    let result = self.calculator.calculate(trimmedText)
                    
                    switch result {
                    case .success(let value):
                        let displayValue = value.truncatingRemainder(dividingBy: 1) == 0 ? 
                            String(format: "%.0f", value) : String(value)
                        
                        responseMessage = """
                        {
                            "type": "math_result",
                            "expression": "\(trimmedText)",
                            "result": "\(displayValue)",
                            "success": true
                        }
                        """
                        print("✅ 계산 완료: \(trimmedText) = \(displayValue)")
                        
                    case .failure(let error):
                        responseMessage = """
                        {
                            "type": "math_error",
                            "expression": "\(trimmedText)",
                            "error": "\(error.message)",
                            "success": false
                        }
                        """
                        print("❌ 계산 오류: \(trimmedText) - \(error.message)")
                    }
                }
                
                // 결과 전송
                try? await webSocket.send(responseMessage)
            }
        }
        
        // 연결 종료 처리
        webSocket.onClose.whenComplete { _ in
            print("🔌 클라이언트 연결 종료됨")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createJSONResponse(_ dnsResponse: DNSResponse) throws -> String {
        let data = try JSONEncoder().encode(dnsResponse)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw Abort(.internalServerError, reason: "JSON 인코딩 실패")
        }
        return jsonString
    }
    
    private func createListResponse(_ records: [DNSRecord]) throws -> String {
        let response = [
            "type": "dns_list",
            "records": records.map { record in
                [
                    "domain": record.domain,
                    "ipAddress": record.ipAddress,
                    "recordType": record.recordType,
                    "ttl": record.ttl
                ]
            },
            "count": records.count,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ] as [String: Any]
        
        let data = try JSONSerialization.data(withJSONObject: response)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw Abort(.internalServerError, reason: "JSON 인코딩 실패")
        }
        return jsonString
    }
    
    private func createErrorResponse(_ message: String) -> String {
        return """
        {
            "type": "error",
            "success": false,
            "message": "\(message)",
            "timestamp": "\(ISO8601DateFormatter().string(from: Date()))"
        }
        """
    }
} 