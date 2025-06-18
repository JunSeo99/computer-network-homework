import Vapor

func routes(_ app: Application) throws {
    let webSocketController = WebSocketController()
    
    // 기본 라우트
    app.get { req async in
        "DNS & 수학 연산 WebSocket 서버가 준비되었습니다!"
    }
    
    // DNS HTTP API 라우트들
    app.group("api", "dns") { dnsRoutes in
        // 도메인 조회
        dnsRoutes.get("query", ":domain") { req async throws -> DNSResponse in
            let domain = try req.parameters.require("domain")
            let dnsService = DNSService.create(for: req)
            return try await dnsService.queryDomain(domain)
        }
        
        // 도메인 등록
        dnsRoutes.post("register") { req async throws -> DNSResponse in
            let registration = try req.content.decode(DNSRegistration.self)
            let dnsService = DNSService.create(for: req)
            return try await dnsService.registerDomain(registration)
        }
        
        // 등록된 도메인 목록
        dnsRoutes.get("list") { req async throws -> [DNSRecord] in
            let dnsService = DNSService.create(for: req)
            return try await dnsService.listRegisteredDomains()
        }
    }
    
    // WebSocket 연결 엔드포인트
    app.webSocket("ws") { req, webSocket in
        webSocketController.handleWebSocket(req, webSocket: webSocket)
    }
    
    // DNS 테스트 페이지
    app.get("dns") { req async throws -> Response in
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>DNS 서버 테스트</title>
            <meta charset="UTF-8">
            <style>
                body { 
                    font-family: Arial, sans-serif; 
                    margin: 20px; 
                    background-color: #f0f0f0; 
                }
                .container { 
                    max-width: 800px; 
                    margin: 0 auto; 
                    background: white; 
                    padding: 20px; 
                    border-radius: 10px; 
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1); 
                }
                .section { 
                    margin-bottom: 20px; 
                    padding: 15px; 
                    border: 1px solid #ddd; 
                    border-radius: 5px; 
                    background: #f9f9f9; 
                }
                .dns-section { background: #e8f5e8; }
                .math-section { background: #e8f0ff; }
                input[type="text"] { 
                    width: 300px; 
                    padding: 10px; 
                    font-size: 16px; 
                    border: 1px solid #ccc; 
                    border-radius: 5px; 
                    margin: 5px; 
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
                .dns-btn { background: #28a745; }
                .dns-btn:hover { background: #1e7e34; }
                .status { 
                    padding: 10px; 
                    margin: 10px 0; 
                    border-radius: 5px; 
                }
                .connected { background: #d4edda; color: #155724; }
                .disconnected { background: #f8d7da; color: #721c24; }
                .result { 
                    background: #fff; 
                    border: 1px solid #ddd; 
                    padding: 15px; 
                    border-radius: 5px; 
                    margin-top: 10px; 
                    max-height: 300px; 
                    overflow-y: auto; 
                }
                .examples { 
                    background: #fff3cd; 
                    border: 1px solid #ffeaa7; 
                    padding: 15px; 
                    border-radius: 5px; 
                    margin-bottom: 20px; 
                }
                .example-json { 
                    background: #f8f9fa; 
                    border: 1px solid #dee2e6; 
                    padding: 10px; 
                    border-radius: 3px; 
                    font-family: monospace; 
                    margin: 5px 0; 
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>DNS WebSocket HW2</h1>
                <div id="connectionStatus" class="status disconnected">연결되지 않음</div>
                
                <div class="section dns-section">
                    <h3>DNS 서버 기능</h3>
                    <div>
                        <input type="text" id="domainQuery" placeholder="조회할 도메인 (예: google.com)">
                        <button class="dns-btn" onclick="queryDomain()" id="queryBtn" disabled>도메인 조회</button>
                    </div>
                    <div>
                        <input type="text" id="domainRegister" placeholder="등록할 도메인 (예: mysite.com)">
                        <input type="text" id="ipRegister" placeholder="IP 주소 (예: 192.168.1.100)">
                        <button class="dns-btn" onclick="registerDomain()" id="registerBtn" disabled>도메인 등록</button>
                    </div>
                    <div>
                        <button class="dns-btn" onclick="listDomains()" id="listBtn" disabled>등록된 도메인 목록</button>
                    </div>
                </div>
                
                <div class="section">
                    <button onclick="connect()" id="connectBtn">연결</button>
                    <button onclick="disconnect()" id="disconnectBtn" disabled>연결 해제</button>
                </div>
                
                <div class="result" id="result">연결 후 요청을 보내주세요.</div>
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
                
                function queryDomain() {
                    const domain = document.getElementById('domainQuery').value.trim();
                    if (!domain) {
                        alert('도메인을 입력하세요.');
                        return;
                    }
                    
                    const message = {
                        type: "query",
                        domain: domain
                    };
                    sendMessage(JSON.stringify(message));
                    document.getElementById('domainQuery').value = '';
                }
                
                function registerDomain() {
                    const domain = document.getElementById('domainRegister').value.trim();
                    const ip = document.getElementById('ipRegister').value.trim();
                    
                    if (!domain || !ip) {
                        alert('도메인과 IP 주소를 모두 입력하세요.');
                        return;
                    }
                    
                    const message = {
                        type: "register",
                        domain: domain,
                        ipAddress: ip,
                        recordType: "A"
                    };
                    sendMessage(JSON.stringify(message));
                    document.getElementById('domainRegister').value = '';
                    document.getElementById('ipRegister').value = '';
                }
                
                function listDomains() {
                    const message = {
                        type: "list"
                    };
                    sendMessage(JSON.stringify(message));
                }
                
                function sendMath() {
                    const expression = document.getElementById('mathInput').value.trim();
                    if (!expression) {
                        alert('수식을 입력하세요.');
                        return;
                    }
                    
                    sendMessage(expression);
                    document.getElementById('mathInput').value = '';
                }
                
                function sendMessage(message) {
                    if (!ws || ws.readyState !== WebSocket.OPEN) {
                        alert('서버에 연결되지 않았습니다.');
                        return;
                    }
                    
                    ws.send(message);
                    addResult('전송: ' + message);
                }
                
                function handleServerMessage(data) {
                    if (data.type === 'welcome') {
                        addResult('환영: ' + data.message);
                        if (data.examples) {
                            addResult('사용 예제: ' + JSON.stringify(data.examples, null, 2));
                        }
                    } else if (data.type === 'math_result') {
                        addResult(`수학 결과: ${data.expression} = ${data.result}`, 'success');
                    } else if (data.type === 'math_error') {
                        addResult(`수학 오류: ${data.expression} → ${data.error}`, 'error');
                    } else if (data.domain !== undefined) {
                        // DNS 응답
                        if (data.success) {
                            addResult(`DNS 성공: ${data.domain} → ${data.ipAddress} (출처: ${data.source})`, 'success');
                        } else {
                            addResult(`DNS 실패: ${data.domain} → ${data.message}`, 'error');
                        }
                    } else if (data.type === 'dns_list') {
                        addResult(`DNS 목록 (총 ${data.count}개):`);
                        data.records.forEach(record => {
                            addResult(`  ${record.domain} → ${record.ipAddress} (${record.recordType}, TTL: ${record.ttl})`);
                        });
                    } else if (data.type === 'error') {
                        addResult(`오류: ${data.message}`, 'error');
                    } else {
                        addResult('응답: ' + JSON.stringify(data, null, 2));
                    }
                }
                
                function updateConnectionStatus(connected) {
                    const statusDiv = document.getElementById('connectionStatus');
                    const buttons = ['connectBtn', 'disconnectBtn', 'queryBtn', 'registerBtn', 'listBtn', 'mathBtn'];
                    const inputs = ['domainQuery', 'domainRegister', 'ipRegister', 'mathInput'];
                    
                    if (connected) {
                        statusDiv.textContent = '연결됨';
                        statusDiv.className = 'status connected';
                        document.getElementById('connectBtn').disabled = true;
                        document.getElementById('disconnectBtn').disabled = false;
                        buttons.slice(2).forEach(id => document.getElementById(id).disabled = false);
                        inputs.forEach(id => document.getElementById(id).disabled = false);
                    } else {
                        statusDiv.textContent = '연결되지 않음';
                        statusDiv.className = 'status disconnected';
                        document.getElementById('connectBtn').disabled = false;
                        document.getElementById('disconnectBtn').disabled = true;
                        buttons.slice(2).forEach(id => document.getElementById(id).disabled = true);
                        inputs.forEach(id => document.getElementById(id).disabled = true);
                    }
                }
                
                function addResult(message, type = '') {
                    const resultDiv = document.getElementById('result');
                    const now = new Date().toLocaleTimeString();
                    const colorClass = type === 'success' ? 'color: #28a745;' : type === 'error' ? 'color: #dc3545;' : '';
                    resultDiv.innerHTML = `<div style="${colorClass}">[${now}] ${message}</div>` + resultDiv.innerHTML;
                }
            </script>
        </body>
        </html>
        """
        
        return Response(status: .ok, headers: HTTPHeaders([("Content-Type", "text/html")]), body: .init(string: html))
    }
    
    // 수학 연산 테스트 페이지 (기존)
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
