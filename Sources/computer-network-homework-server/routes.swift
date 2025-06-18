import Vapor

func routes(_ app: Application) throws {
    let webSocketController = WebSocketController()
    
    // 기본 라우트
    app.get { req async in
        "DNS, 라우팅 & 수학 연산 WebSocket 서버가 준비되었습니다!"
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
    
    // 라우팅 HTTP API 라우트들
    app.group("api", "routing") { routingRoutes in
        // 네트워크 토폴로지 조회
        routingRoutes.get("topology") { req async throws -> NetworkTopology in
            return RoutingServiceContainer.shared.getTopology()
        }
        
        // 최단 경로 계산
        routingRoutes.post("shortest-path") { req async throws -> ShortestPathResponse in
            let pathRequest = try req.content.decode(ShortestPathRequest.self)
            return RoutingServiceContainer.shared.calculateShortestPath(
                from: pathRequest.sourceId, 
                to: pathRequest.destinationId
            )
        }
        
        // 토폴로지 업데이트
        routingRoutes.put("topology") { req async throws -> NetworkTopology in
            let newTopology = try req.content.decode(NetworkTopology.self)
            RoutingServiceContainer.shared.updateTopology(newTopology)
            return RoutingServiceContainer.shared.getTopology()
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
    
    // 라우팅 테스트 페이지
    app.get("hw3") { req async throws -> Response in
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>네트워크 라우팅 HW3</title>
            <meta charset="UTF-8">
            <style>
                body { 
                    font-family: Arial, sans-serif; 
                    margin: 20px; 
                    background-color: #f0f0f0; 
                }
                .container { 
                    max-width: 1200px; 
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
                .routing-section { background: #e8f5e8; }
                .topology-section { background: #fff3cd; }
                .result-section { background: #e9f4ff; }
                input[type="text"], select { 
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
                .routing-btn { background: #28a745; }
                .routing-btn:hover { background: #1e7e34; }
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
                    max-height: 400px; 
                    overflow-y: auto; 
                    font-family: monospace;
                    white-space: pre-wrap;
                }
                .topology-display {
                    background: #fff;
                    border: 1px solid #ddd;
                    padding: 15px;
                    border-radius: 5px;
                    margin-top: 10px;
                    max-height: 500px;
                    overflow-y: auto;
                }
                
                .network-visualization {
                    width: 100%;
                    height: 400px;
                    border: 1px solid #ccc;
                    background: white;
                    margin: 10px 0;
                }
                
                .node {
                    fill: #4CAF50;
                    stroke: #2E7D32;
                    stroke-width: 2;
                    cursor: pointer;
                }
                
                .node.source {
                    fill: #2196F3;
                    stroke: #1976D2;
                    stroke-width: 3;
                }
                
                .node.destination {
                    fill: #F44336;
                    stroke: #D32F2F;
                    stroke-width: 3;
                }
                
                .node.path {
                    fill: #FF9800;
                    stroke: #F57C00;
                    stroke-width: 3;
                }
                
                .link {
                    stroke: #666;
                    stroke-width: 2;
                    fill: none;
                }
                
                .link.shortest-path {
                    stroke: #FF5722;
                    stroke-width: 4;
                    animation: pathAnimation 2s ease-in-out;
                }
                
                @keyframes pathAnimation {
                    0% { stroke-dasharray: 10,10; stroke-dashoffset: 20; }
                    100% { stroke-dasharray: none; stroke-dashoffset: 0; }
                }
                
                .node-label {
                    font-family: Arial, sans-serif;
                    font-size: 14px;
                    font-weight: bold;
                    text-anchor: middle;
                    dominant-baseline: central;
                    fill: white;
                    pointer-events: none;
                }
                
                .link-label {
                    font-family: Arial, sans-serif;
                    font-size: 16px;
                    font-weight: bold;
                    text-anchor: middle;
                    dominant-baseline: central;
                    fill: #333;
                    background: white;
                    pointer-events: none;
                }
                .examples { 
                    background: #fff3cd; 
                    border: 1px solid #ffeaa7; 
                    padding: 15px; 
                    border-radius: 5px; 
                    margin-bottom: 20px; 
                }
                .path-step {
                    background: #e7f3ff;
                    border-left: 4px solid #007bff;
                    padding: 10px;
                    margin: 5px 0;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>Link State 라우팅 알고리즘 HW3</h1>
                <div id="connectionStatus" class="status disconnected">연결되지 않음</div>
                
                <div class="examples">
                    <h3>사용 예제</h3>
                    <p><strong>토폴로지 전송:</strong></p>
                    <div style="font-family: monospace; background: #f8f9fa; padding: 10px; border-radius: 3px;">{"type": "set_topology", "nodes": [...], "links": [...]}</div>
                    <p><strong>최단 경로 계산:</strong></p>
                    <div style="font-family: monospace; background: #f8f9fa; padding: 10px; border-radius: 3px;">{"type": "shortest_path", "sourceId": "A", "destinationId": "F"}</div>
                </div>
                
                <div class="section topology-section">
                    <h3>네트워크 토폴로지</h3>
                    <button class="routing-btn" onclick="sendTopology()" id="sendTopologyBtn" disabled>토폴로지 전송</button>
                    <div id="topologyDisplay" class="topology-display">먼저 서버에 토폴로지를 전송하세요.</div>
                </div>
                
                <div class="section routing-section">
                    <h3>최단 경로 계산</h3>
                    <div>
                        <label>출발 노드:</label>
                        <select id="sourceSelect" disabled>
                            <option value="">선택하세요</option>
                        </select>
                        
                        <label>도착 노드:</label>
                        <select id="destinationSelect" disabled>
                            <option value="">선택하세요</option>
                        </select>
                        
                        <button class="routing-btn" onclick="calculatePath()" id="calculateBtn" disabled>최단 경로 계산</button>
                    </div>
                </div>
                
                <div class="section">
                    <button onclick="connect()" id="connectBtn">연결</button>
                    <button onclick="disconnect()" id="disconnectBtn" disabled>연결 해제</button>
                </div>
                
                <div class="section result-section">
                    <h3>결과</h3>
                    <div class="result" id="result">연결 후 토폴로지를 전송하세요.</div>
                </div>
            </div>
            
            <script>
                let ws = null;
                let currentTopology = null;
                
                function connect() {
                    if (ws && ws.readyState === WebSocket.OPEN) {
                        addResult('이미 연결되어 있습니다.');
                        return;
                    }
                    
                    ws = new WebSocket('ws://localhost:8080/ws');
                    
                    ws.onopen = function() {
                        updateConnectionStatus(true);
                        addResult('라우팅 서버에 연결되었습니다.');
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
                
                function sendTopology() {
                    if (!checkConnection()) return;
                    
                    // 기본 토폴로지 데이터 생성 (클라이언트에서 서버로 전송)
                    const topology = {
                        "nodes": [
                            {"id": "A", "name": "Router A", "x": 100, "y": 200},
                            {"id": "B", "name": "Router B", "x": 300, "y": 100},
                            {"id": "C", "name": "Router C", "x": 500, "y": 200},
                            {"id": "D", "name": "Router D", "x": 200, "y": 350},
                            {"id": "E", "name": "Router E", "x": 400, "y": 350},
                            {"id": "F", "name": "Router F", "x": 600, "y": 100}
                        ],
                        "links": [
                            {"from": "A", "to": "B", "cost": 4, "bidirectional": true},
                            {"from": "A", "to": "D", "cost": 2, "bidirectional": true},
                            {"from": "B", "to": "C", "cost": 3, "bidirectional": true},
                            {"from": "B", "to": "E", "cost": 1, "bidirectional": true},
                            {"from": "C", "to": "E", "cost": 2, "bidirectional": true},
                            {"from": "C", "to": "F", "cost": 6, "bidirectional": true},
                            {"from": "D", "to": "E", "cost": 5, "bidirectional": true},
                            {"from": "E", "to": "F", "cost": 1, "bidirectional": true}
                        ],
                        "description": "클라이언트에서 전송한 네트워크 토폴로지 - 6개 라우터로 구성된 샘플 네트워크"
                    };
                    
                    const message = JSON.stringify({
                        "type": "set_topology",
                        "nodes": topology.nodes,
                        "links": topology.links,
                        "description": topology.description
                    });
                    
                    ws.send(message);
                    addResult('토폴로지 전송 중...');
                    
                    // 토폴로지 전송 후 로컬에 저장하고 표시
                    currentTopology = topology;
                    displayTopology(currentTopology);
                    updateNodeSelects(currentTopology.nodes);
                }
                
                function calculatePath() {
                    if (!checkConnection()) return;
                    
                    const sourceId = document.getElementById('sourceSelect').value;
                    const destinationId = document.getElementById('destinationSelect').value;
                    
                    if (!sourceId || !destinationId) {
                        alert('출발 노드와 도착 노드를 모두 선택하세요.');
                        return;
                    }
                    
                    // 이전 시각화 초기화
                    resetVisualization();
                    
                    const message = JSON.stringify({
                        "type": "shortest_path",
                        "sourceId": sourceId,
                        "destinationId": destinationId
                    });
                    
                    ws.send(message);
                    addResult(`최단 경로 계산 요청: ${sourceId} -> ${destinationId}`);
                }
                
                function checkConnection() {
                    if (!ws || ws.readyState !== WebSocket.OPEN) {
                        alert('서버에 연결되지 않았습니다.');
                        return false;
                    }
                    return true;
                }
                
                function handleServerMessage(data) {
                    console.log('Received:', data);
                    
                    if (data.type === 'welcome') {
                        addResult(data.message);
                    } else if (data.type === 'success') {
                        addResult('✅ ' + data.message);
                    } else if (data.type === 'topology_status') {
                        handleTopologyStatusResponse(data);
                    } else if (data.sourceId && data.destinationId) {
                        // 최단 경로 응답
                        handlePathResponse(data);
                    } else if (data.type === 'error') {
                        addResult('오류: ' + data.message);
                    } else {
                        addResult('응답: ' + JSON.stringify(data, null, 2));
                    }
                }
                
                function handleTopologyStatusResponse(data) {
                    if (data.hasTopology && data.topology) {
                        currentTopology = data.topology;
                        displayTopology(currentTopology);
                        updateNodeSelects(currentTopology.nodes);
                        addResult('✅ ' + data.message);
                    } else {
                        addResult('⚠️ ' + data.message);
                    }
                }
                
                function handlePathResponse(pathData) {
                    if (pathData.success) {
                        let result = `=== 최단 경로 계산 결과 ===\\n`;
                        result += `출발: ${pathData.sourceId} -> 도착: ${pathData.destinationId}\\n`;
                        result += `총 비용: ${pathData.totalCost}\\n`;
                        result += `알고리즘: ${pathData.algorithm}\\n\\n`;
                        
                        result += `경로:\\n`;
                        pathData.path.forEach((step, index) => {
                            result += `${index + 1}. ${step.nodeName} (${step.nodeId}) - 누적비용: ${step.cumulativeCost}\\n`;
                        });
                        
                        if (pathData.computationSteps) {
                            result += `\\n계산 과정:\\n`;
                            pathData.computationSteps.forEach((step, index) => {
                                result += `${step}\\n`;
                            });
                        }
                        
                        addResult(result);
                        
                        // 시각적으로 최단 경로 표시
                        visualizeShortestPath(pathData);
                    } else {
                        addResult(`경로 계산 실패: ${pathData.message}`);
                    }
                }
                
                function displayTopology(topology) {
                    const display = document.getElementById('topologyDisplay');
                    
                    let html = `<h4>${topology.description || '네트워크 토폴로지'}</h4>`;
                    
                    // SVG 시각화 추가
                    html += '<svg class="network-visualization" id="networkSvg">';
                    
                    // 링크 먼저 그리기 (노드 뒤에 위치하도록)
                    topology.links.forEach((link, index) => {
                        const fromNode = topology.nodes.find(n => n.id === link.from);
                        const toNode = topology.nodes.find(n => n.id === link.to);
                        
                        if (fromNode && toNode) {
                            html += `<line x1="${fromNode.x}" y1="${fromNode.y}" x2="${toNode.x}" y2="${toNode.y}" 
                                     class="link" id="link-${link.from}-${link.to}"></line>`;
                            
                            // 링크 비용 표시
                            const midX = (fromNode.x + toNode.x) / 2;
                            const midY = (fromNode.y + toNode.y) / 2;
                            // 배경 원형 추가
                            html += `<circle cx="${midX}" cy="${midY}" r="12" fill="white" stroke="#333" stroke-width="1"></circle>`;
                            html += `<text x="${midX}" y="${midY}" class="link-label" 
                                     style="font-size: 16px; font-weight: bold; fill: #333; text-anchor: middle; dominant-baseline: central;">
                                     ${link.cost}</text>`;
                        }
                    });
                    
                    // 노드 그리기
                    topology.nodes.forEach(node => {
                        html += `<circle cx="${node.x}" cy="${node.y}" r="25" class="node" id="node-${node.id}"></circle>`;
                        html += `<text x="${node.x}" y="${node.y}" class="node-label">${node.id}</text>`;
                    });
                    
                    html += '</svg>';
                    
                    // 텍스트 정보도 유지
                    html += '<div style="margin-top: 20px;">';
                    html += '<h5>노드 (라우터):</h5><ul>';
                    topology.nodes.forEach(node => {
                        html += `<li><strong>${node.id}</strong>: ${node.name}</li>`;
                    });
                    html += '</ul>';
                    
                    html += '<h5>링크 (연결):</h5><ul>';
                    topology.links.forEach(link => {
                        const direction = link.bidirectional ? '↔' : '→';
                        html += `<li>${link.from} ${direction} ${link.to} (비용: ${link.cost})</li>`;
                    });
                    html += '</ul></div>';
                    
                    display.innerHTML = html;
                }
                
                function updateNodeSelects(nodes) {
                    const sourceSelect = document.getElementById('sourceSelect');
                    const destinationSelect = document.getElementById('destinationSelect');
                    
                    // 기존 옵션 제거 (첫 번째 제외)
                    sourceSelect.innerHTML = '<option value="">선택하세요</option>';
                    destinationSelect.innerHTML = '<option value="">선택하세요</option>';
                    
                    // 새 옵션 추가
                    nodes.forEach(node => {
                        const option1 = new Option(`${node.name} (${node.id})`, node.id);
                        const option2 = new Option(`${node.name} (${node.id})`, node.id);
                        sourceSelect.add(option1);
                        destinationSelect.add(option2);
                    });
                }
                
                function updateConnectionStatus(connected) {
                    const statusDiv = document.getElementById('connectionStatus');
                    const connectBtn = document.getElementById('connectBtn');
                    const disconnectBtn = document.getElementById('disconnectBtn');
                    const sendTopologyBtn = document.getElementById('sendTopologyBtn');
                    const calculateBtn = document.getElementById('calculateBtn');
                    const sourceSelect = document.getElementById('sourceSelect');
                    const destinationSelect = document.getElementById('destinationSelect');
                    
                    if (connected) {
                        statusDiv.textContent = '연결됨';
                        statusDiv.className = 'status connected';
                        connectBtn.disabled = true;
                        disconnectBtn.disabled = false;
                        sendTopologyBtn.disabled = false;
                        calculateBtn.disabled = false;
                        sourceSelect.disabled = false;
                        destinationSelect.disabled = false;
                    } else {
                        statusDiv.textContent = '연결되지 않음';
                        statusDiv.className = 'status disconnected';
                        connectBtn.disabled = false;
                        disconnectBtn.disabled = true;
                        sendTopologyBtn.disabled = true;
                        calculateBtn.disabled = true;
                        sourceSelect.disabled = true;
                        destinationSelect.disabled = true;
                    }
                }
                
                function visualizeShortestPath(pathData) {
                    // 먼저 모든 노드와 링크의 스타일을 초기화
                    resetVisualization();
                    
                    // 출발 노드와 도착 노드 표시
                    const sourceNode = document.getElementById(`node-${pathData.sourceId}`);
                    const destinationNode = document.getElementById(`node-${pathData.destinationId}`);
                    
                    if (sourceNode) {
                        sourceNode.classList.add('source');
                    }
                    if (destinationNode) {
                        destinationNode.classList.add('destination');
                    }
                    
                    // 경로상의 중간 노드들 표시
                    pathData.path.forEach((step, index) => {
                        if (step.nodeId !== pathData.sourceId && step.nodeId !== pathData.destinationId) {
                            const node = document.getElementById(`node-${step.nodeId}`);
                            if (node) {
                                node.classList.add('path');
                            }
                        }
                    });
                    
                    // 최단 경로의 링크들을 하이라이트
                    for (let i = 0; i < pathData.path.length - 1; i++) {
                        const from = pathData.path[i].nodeId;
                        const to = pathData.path[i + 1].nodeId;
                        
                        // 양방향 링크를 고려하여 두 가지 경우 모두 확인
                        let link = document.getElementById(`link-${from}-${to}`);
                        if (!link) {
                            link = document.getElementById(`link-${to}-${from}`);
                        }
                        
                        if (link) {
                            link.classList.add('shortest-path');
                        }
                    }
                }
                
                function resetVisualization() {
                    // 모든 노드의 클래스 초기화
                    document.querySelectorAll('.node').forEach(node => {
                        node.classList.remove('source', 'destination', 'path');
                    });
                    
                    // 모든 링크의 클래스 초기화
                    document.querySelectorAll('.link').forEach(link => {
                        link.classList.remove('shortest-path');
                    });
                }
                
                function addResult(message) {
                    const resultDiv = document.getElementById('result');
                    const now = new Date().toLocaleTimeString();
                    const newContent = `[${now}] ${message}\\n\\n`;
                    resultDiv.textContent = newContent + resultDiv.textContent;
                }
            </script>
        </body>
        </html>
        """
        
        return Response(status: .ok, headers: HTTPHeaders([("Content-Type", "text/html")]), body: .init(string: html))
    }
}
