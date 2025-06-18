import Foundation
import Vapor

// MARK: - Network Topology Models

/// 네트워크 노드 (라우터)
struct NetworkNode: Codable, Content {
    let id: String
    let name: String
    let x: Double?  // 시각화를 위한 좌표
    let y: Double?
    
    init(id: String, name: String, x: Double? = nil, y: Double? = nil) {
        self.id = id
        self.name = name
        self.x = x
        self.y = y
    }
}

/// 네트워크 링크 (라우터 간 연결)
struct NetworkLink: Codable, Content {
    let from: String    // 시작 노드 ID
    let to: String      // 끝 노드 ID
    let cost: Int       // 링크 비용
    let bidirectional: Bool // 양방향 링크 여부
    
    init(from: String, to: String, cost: Int, bidirectional: Bool = true) {
        self.from = from
        self.to = to
        self.cost = cost
        self.bidirectional = bidirectional
    }
}

/// 전체 네트워크 토폴로지
struct NetworkTopology: Codable, Content {
    let nodes: [NetworkNode]
    let links: [NetworkLink]
    let description: String?
    
    init(nodes: [NetworkNode], links: [NetworkLink], description: String? = nil) {
        self.nodes = nodes
        self.links = links
        self.description = description
    }
}

// MARK: - Routing Request/Response Models

/// 최단 경로 요청
struct ShortestPathRequest: Codable, Content {
    let sourceId: String
    let destinationId: String
    let algorithm: String   // "link_state", "dijkstra"
    
    init(sourceId: String, destinationId: String, algorithm: String = "link_state") {
        self.sourceId = sourceId
        self.destinationId = destinationId
        self.algorithm = algorithm
    }
}

/// 경로 정보
struct PathInfo: Codable, Content {
    let nodeId: String
    let nodeName: String
    let cumulativeCost: Int
}

/// 최단 경로 응답
struct ShortestPathResponse: Codable, Content {
    let success: Bool
    let sourceId: String
    let destinationId: String
    let totalCost: Int
    let path: [PathInfo]
    let algorithm: String
    let message: String
    let computationSteps: [String]?  // 계산 과정 (선택적)
    let timestamp: String
    
    init(success: Bool, sourceId: String, destinationId: String, 
         totalCost: Int, path: [PathInfo], algorithm: String, 
         message: String, computationSteps: [String]? = nil) {
        self.success = success
        self.sourceId = sourceId
        self.destinationId = destinationId
        self.totalCost = totalCost
        self.path = path
        self.algorithm = algorithm
        self.message = message
        self.computationSteps = computationSteps
        self.timestamp = ISO8601DateFormatter().string(from: Date())
    }
}

// MARK: - WebSocket Message Types

enum RoutingMessage: Codable {
    case setTopology(NetworkTopology)   // 클라이언트가 토폴로지 전송
    case shortestPath(ShortestPathRequest)
    case getTopologyStatus              // 토폴로지 설정 상태 확인
    
    private enum CodingKeys: String, CodingKey {
        case type
        case sourceId, destinationId, algorithm
        case nodes, links, description
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "set_topology":
            let nodes = try container.decode([NetworkNode].self, forKey: .nodes)
            let links = try container.decode([NetworkLink].self, forKey: .links)
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            let topology = NetworkTopology(nodes: nodes, links: links, description: description)
            self = .setTopology(topology)
            
        case "shortest_path":
            let sourceId = try container.decode(String.self, forKey: .sourceId)
            let destinationId = try container.decode(String.self, forKey: .destinationId)
            let algorithm = try container.decodeIfPresent(String.self, forKey: .algorithm) ?? "link_state"
            let request = ShortestPathRequest(sourceId: sourceId, destinationId: destinationId, algorithm: algorithm)
            self = .shortestPath(request)
            
        case "get_topology_status":
            self = .getTopologyStatus
            
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown routing message type: \(type)")
            )
        }
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .setTopology(let topology):
            try container.encode("set_topology", forKey: .type)
            try container.encode(topology.nodes, forKey: .nodes)
            try container.encode(topology.links, forKey: .links)
            try container.encodeIfPresent(topology.description, forKey: .description)
            
        case .shortestPath(let request):
            try container.encode("shortest_path", forKey: .type)
            try container.encode(request.sourceId, forKey: .sourceId)
            try container.encode(request.destinationId, forKey: .destinationId)
            try container.encode(request.algorithm, forKey: .algorithm)
            
        case .getTopologyStatus:
            try container.encode("get_topology_status", forKey: .type)
        }
    }
} 