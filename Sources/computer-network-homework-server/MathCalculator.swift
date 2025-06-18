import Foundation

// MARK: - Math Calculator
final class MathCalculator: @unchecked Sendable {
    
    enum CalculationError: Error {
        case invalidExpression
        case divisionByZero
        case unsupportedOperation
        
        var message: String {
            switch self {
            case .invalidExpression:
                return "수식 형식이 잘못되었습니다."
            case .divisionByZero:
                return "0으로 나눌 수 없습니다."
            case .unsupportedOperation:
                return "지원하지 않는 연산입니다."
            }
        }
    }
    
    // 수식 계산 메인 함수
    func calculate(_ expression: String) -> Result<Double, CalculationError> {
        do {
            let cleanExpression = expression.replacingOccurrences(of: " ", with: "")
            let result = try evaluateExpression(cleanExpression)
            return .success(result)
        } catch let error as CalculationError {
            return .failure(error)
        } catch {
            return .failure(.invalidExpression)
        }
    }
    
    // 수식 평가 (괄호 처리)
    private func evaluateExpression(_ expression: String) throws -> Double {
        var expr = expression
        
        // 괄호 처리
        while let openIndex = expr.lastIndex(of: "(") {
            guard let closeIndex = expr[openIndex...].firstIndex(of: ")") else {
                throw CalculationError.invalidExpression
            }
            
            let subExpr = String(expr[expr.index(after: openIndex)..<closeIndex])
            let result = try evaluateSimpleExpression(subExpr)
            
            expr.replaceSubrange(openIndex...closeIndex, with: "\(result)")
        }
        
        return try evaluateSimpleExpression(expr)
    }
    
    // 단순 수식 평가 (괄호 없는 수식)
    private func evaluateSimpleExpression(_ expression: String) throws -> Double {
        let tokens = try tokenize(expression)
        return try calculateFromTokens(tokens)
    }
    
    // 토큰화
    private func tokenize(_ expression: String) throws -> [String] {
        var tokens: [String] = []
        var currentNumber = ""
        
        for char in expression {
            if char.isNumber || char == "." {
                currentNumber.append(char)
            } else if "+-*/".contains(char) {
                if !currentNumber.isEmpty {
                    tokens.append(currentNumber)
                    currentNumber = ""
                }
                tokens.append(String(char))
            } else {
                throw CalculationError.invalidExpression
            }
        }
        
        if !currentNumber.isEmpty {
            tokens.append(currentNumber)
        }
        
        return tokens
    }
    
    // 토큰에서 계산 (연산자 우선순위 고려)
    private func calculateFromTokens(_ tokens: [String]) throws -> Double {
        var numbers: [Double] = []
        var operators: [String] = []
        
        var i = 0
        while i < tokens.count {
            let token = tokens[i]
            
            if let number = Double(token) {
                numbers.append(number)
            } else if "+-*/".contains(token) {
                // 연산자 우선순위 처리
                while !operators.isEmpty && shouldCalculateFirst(operators.last!, token) {
                    try performOperation(&numbers, &operators)
                }
                operators.append(token)
            } else {
                throw CalculationError.invalidExpression
            }
            
            i += 1
        }
        
        // 남은 연산 수행
        while !operators.isEmpty {
            try performOperation(&numbers, &operators)
        }
        
        guard numbers.count == 1 else {
            throw CalculationError.invalidExpression
        }
        
        return numbers[0]
    }
    
    // 연산자 우선순위 확인
    private func shouldCalculateFirst(_ op1: String, _ op2: String) -> Bool {
        let precedence: [String: Int] = ["+": 1, "-": 1, "*": 2, "/": 2]
        return (precedence[op1] ?? 0) >= (precedence[op2] ?? 0)
    }
    
    // 실제 연산 수행
    private func performOperation(_ numbers: inout [Double], _ operators: inout [String]) throws {
        guard numbers.count >= 2, !operators.isEmpty else {
            throw CalculationError.invalidExpression
        }
        
        let b = numbers.removeLast()
        let a = numbers.removeLast()
        let op = operators.removeLast()
        
        let result: Double
        switch op {
        case "+":
            result = a + b
        case "-":
            result = a - b
        case "*":
            result = a * b
        case "/":
            if b == 0 {
                throw CalculationError.divisionByZero
            }
            result = a / b
        default:
            throw CalculationError.unsupportedOperation
        }
        
        numbers.append(result)
    }
} 