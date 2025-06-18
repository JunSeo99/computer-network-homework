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
            "message": "수학 연산 서버에 연결되었습니다. 수식을 입력해 주세요."
        }
        """
        
        _ = webSocket.send(welcomeMessage)
        
        // 메시지 수신 처리
        webSocket.onText { webSocket, text in
            let trimmedExpression = text.trimmingCharacters(in: .whitespacesAndNewlines)
            print("📨 수신된 수식: \(trimmedExpression)")
            
            // 수식 계산
            let result = self.calculator.calculate(trimmedExpression)
            
            let responseMessage: String
            
            switch result {
            case .success(let value):
                // 결과가 정수인지 확인하여 깔끔하게 표시
                let displayValue = value.truncatingRemainder(dividingBy: 1) == 0 ? 
                    String(format: "%.0f", value) : String(value)
                
                responseMessage = """
                {
                    "type": "result",
                    "expression": "\(trimmedExpression)",
                    "result": "\(displayValue)",
                    "success": true
                }
                """
                print("✅ 계산 완료: \(trimmedExpression) = \(displayValue)")
                
            case .failure(let error):
                responseMessage = """
                {
                    "type": "error",
                    "expression": "\(trimmedExpression)",
                    "error": "\(error.message)",
                    "success": false
                }
                """
                print("❌ 계산 오류: \(trimmedExpression) - \(error.message)")
            }
            
            // 결과 전송
            _ = webSocket.send(responseMessage)
        }
        
        // 연결 종료 처리
        webSocket.onClose.whenComplete { _ in
            print("🔌 클라이언트 연결 종료됨")
        }
    }
    

} 