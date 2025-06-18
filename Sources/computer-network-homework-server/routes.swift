import Vapor

func routes(_ app: Application) throws {
    let webSocketController = WebSocketController()
    
    // 기본 라우트
    app.get { req async in
        "수학 연산 WebSocket 서버가 준비되었습니다!"
    }
    
    // WebSocket 연결 엔드포인트
    app.webSocket("ws") { req, webSocket in
        webSocketController.handleWebSocket(req, webSocket: webSocket)
    }
    
    // 테스트 페이지
    app.get("hw1") { req async throws -> Response in
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>수학 연산 WebSocket 테스트</title>
            <meta charset="UTF-8">
            <style>
                body { 
                    font-family: Arial, sans-serif; 
                    margin: 20px; 
                    background-color: #f0f0f0; 
                }
                .container { 
                    max-width: 600px; 
                    margin: 0 auto; 
                    background: white; 
                    padding: 20px; 
                    border-radius: 10px; 
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1); 
                }
                .input-section { 
                    margin-bottom: 20px; 
                    padding: 15px; 
                    border: 1px solid #ddd; 
                    border-radius: 5px; 
                    background: #f9f9f9; 
                }
                .result-section { 
                    margin-bottom: 20px; 
                    padding: 15px; 
                    border: 1px solid #ddd; 
                    border-radius: 5px; 
                    background: #e9f4ff; 
                }
                input[type="text"] { 
                    width: 300px; 
                    padding: 10px; 
                    font-size: 16px; 
                    border: 1px solid #ccc; 
                    border-radius: 5px; 
                }
                button { 
                    padding: 10px 20px; 
                    margin: 5px; 
                    font-size: 16px; 
                    cursor: pointer; 
                    border: none; 
                    border-radius: 5px; 
                    background: #007bff; 
                    color: white; 
                }
                button:hover { background: #0056b3; }
                button:disabled { background: #ccc; cursor: not-allowed; }
                #result { 
                    font-size: 18px; 
                    font-weight: bold; 
                    margin-top: 10px; 
                }
                .success { color: #28a745; }
                .error { color: #dc3545; }
                .status { 
                    padding: 10px; 
                    margin: 10px 0; 
                    border-radius: 5px; 
                }
                .connected { background: #d4edda; color: #155724; }
                .disconnected { background: #f8d7da; color: #721c24; }
                .examples { 
                    background: #fff3cd; 
                    border: 1px solid #ffeaa7; 
                    padding: 15px; 
                    border-radius: 5px; 
                    margin-bottom: 20px; 
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>수학 연산 WebSocket HW1</h1>
                <div id="connectionStatus" class="status disconnected">연결되지 않음</div>
                
                <div class="input-section">
                    <h3>수식 입력</h3>
                    <input type="text" 
                           id="expressionInput" 
                           placeholder="수식을 입력하세요 (예: (3+5)/3-74)" 
                           onkeypress="if(event.key==='Enter') sendExpression()"
                           disabled>
                    <br><br>
                    <button onclick="connect()" id="connectBtn">연결</button>
                    <button onclick="disconnect()" id="disconnectBtn" disabled>연결 해제</button>
                    <button onclick="sendExpression()" id="sendBtn" disabled>계산</button>
                </div>
                
                <div class="result-section">
                    <h3>결과</h3>
                    <div id="result">연결 후 수식을 입력해주세요.</div>
                </div>
            </div>
            
            <script>
                let ws = null;
                
                function connect() {
                    if (ws && ws.readyState === WebSocket.OPEN) {
                        addResult('이미 연결되어 있습니다.');
                        return;
                    }
                    
                    ws = new WebSocket('ws://localhost:8080/ws');
                    
                    ws.onopen = function() {
                        updateConnectionStatus(true);
                        addResult('서버에 연결되었습니다.');
                    };
                    
                    ws.onmessage = function(event) {
                        const data = JSON.parse(event.data);
                        handleServerMessage(data);
                    };
                    
                    ws.onclose = function() {
                        updateConnectionStatus(false);
                        addResult('서버 연결이 종료되었습니다.');
                    };
                    
                    ws.onerror = function(error) {
                        updateConnectionStatus(false);
                        addResult('연결 오류가 발생했습니다.');
                    };
                }
                
                function disconnect() {
                    if (ws) {
                        ws.close();
                    }
                }
                
                function sendExpression() {
                    const input = document.getElementById('expressionInput');
                    const expression = input.value.trim();
                    
                    if (!expression) {
                        alert('수식을 입력하세요.');
                        return;
                    }
                    
                    if (!ws || ws.readyState !== WebSocket.OPEN) {
                        alert('서버에 연결되지 않았습니다.');
                        return;
                    }
                    
                    ws.send(expression);
                    addResult('전송: ' + expression);
                    input.value = '';
                }
                
                function handleServerMessage(data) {
                    if (data.type === 'welcome') {
                        addResult(data.message);
                    } else if (data.type === 'result') {
                        addResult(`${data.expression} = ${data.result}`, 'success');
                    } else if (data.type === 'error') {
                        addResult(`${data.expression} → ${data.error}`, 'error');
                    }
                }
                
                function updateConnectionStatus(connected) {
                    const statusDiv = document.getElementById('connectionStatus');
                    const connectBtn = document.getElementById('connectBtn');
                    const disconnectBtn = document.getElementById('disconnectBtn');
                    const sendBtn = document.getElementById('sendBtn');
                    const input = document.getElementById('expressionInput');
                    
                    if (connected) {
                        statusDiv.textContent = '연결됨';
                        statusDiv.className = 'status connected';
                        connectBtn.disabled = true;
                        disconnectBtn.disabled = false;
                        sendBtn.disabled = false;
                        input.disabled = false;
                        input.focus();
                    } else {
                        statusDiv.textContent = '연결되지 않음';
                        statusDiv.className = 'status disconnected';
                        connectBtn.disabled = false;
                        disconnectBtn.disabled = true;
                        sendBtn.disabled = true;
                        input.disabled = true;
                    }
                }
                
                function addResult(message, type = '') {
                    const resultDiv = document.getElementById('result');
                    const now = new Date().toLocaleTimeString();
                    const className = type ? ` class="${type}"` : '';
                    resultDiv.innerHTML = `<div${className}>[${now}] ${message}</div>` + resultDiv.innerHTML;
                }
            </script>
        </body>
        </html>
        """
        
        return Response(status: .ok, headers: HTTPHeaders([("Content-Type", "text/html")]), body: .init(string: html))
    }
}
