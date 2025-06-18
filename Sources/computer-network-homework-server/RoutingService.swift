import Vapor
import Foundation

// MARK: - Link State Routing Service

final class RoutingService: @unchecked Sendable {
    private var topology: NetworkTopology
    
    init() {
        // 빈 토폴로지로 초기화 (클라이언트가 토폴로지를 전송할 때까지 대기)
        self.topology = NetworkTopology(
            nodes: [],
            links: [],
            description: "토폴로지가 아직 설정되지 않았습니다. 클라이언트에서 토폴로지를 전송하세요."
        )
    }
    
    // MARK: - Public Methods
    
    /// 현재 토폴로지 반환
    func getTopology() -> NetworkTopology {
        return topology
    }
    
    /// 토폴로지 업데이트
    func updateTopology(_ newTopology: NetworkTopology) {
        self.topology = newTopology
    }
    
    /// 토폴로지가 설정되었는지 확인
    func hasTopology() -> Bool {
        return !topology.nodes.isEmpty
    }
    
    /// Link State 알고리즘을 사용한 최단 경로 계산
    func calculateShortestPath(from sourceId: String, to destinationId: String) -> ShortestPathResponse {
        // 토폴로지 설정 여부 확인
        guard hasTopology() else {
            return ShortestPathResponse(
                success: false,
                sourceId: sourceId,
                destinationId: destinationId,
                totalCost: -1,
                path: [],
                algorithm: "link_state",
                message: "토폴로지가 설정되지 않았습니다. 먼저 클라이언트에서 토폴로지를 전송하세요."
            )
        }
        
        // 노드 존재 확인
        guard topology.nodes.contains(where: { $0.id == sourceId }) else {
            return ShortestPathResponse(
                success: false,
                sourceId: sourceId,
                destinationId: destinationId,
                totalCost: -1,
                path: [],
                algorithm: "link_state",
                message: "출발 노드 '\(sourceId)'를 찾을 수 없습니다."
            )
        }
        
        guard topology.nodes.contains(where: { $0.id == destinationId }) else {
            return ShortestPathResponse(
                success: false,
                sourceId: sourceId,
                destinationId: destinationId,
                totalCost: -1,
                path: [],
                algorithm: "link_state",
                message: "도착 노드 '\(destinationId)'를 찾을 수 없습니다."
            )
        }
        
        // 같은 노드인 경우
        if sourceId == destinationId {
            let node = topology.nodes.first { $0.id == sourceId }!
            return ShortestPathResponse(
                success: true,
                sourceId: sourceId,
                destinationId: destinationId,
                totalCost: 0,
                path: [PathInfo(nodeId: sourceId, nodeName: node.name, cumulativeCost: 0)],
                algorithm: "link_state",
                message: "출발지와 목적지가 동일합니다."
            )
        }
        
        // Dijkstra 알고리즘 실행
        let result = dijkstraAlgorithm(from: sourceId, to: destinationId)
        
        return result
    }
    
    // MARK: - Private Methods
    
    /// Dijkstra 알고리즘 구현 (Link State의 핵심 알고리즘)
    private func dijkstraAlgorithm(from sourceId: String, to destinationId: String) -> ShortestPathResponse {
        var distances: [String: Int] = [:]
        var previousNodes: [String: String] = [:]
        var unvisited: Set<String> = Set()
        var computationSteps: [String] = []
        
        // 초기화
        for node in topology.nodes {
            distances[node.id] = Int.max
            unvisited.insert(node.id)
        }
        distances[sourceId] = 0
        
        computationSteps.append("1. 초기화: 출발 노드 \(sourceId)의 거리를 0으로 설정, 나머지는 무한대")
        
        // 인접 리스트 생성
        let adjacencyList = buildAdjacencyList()
        
        while !unvisited.isEmpty {
            // 방문하지 않은 노드 중 최소 거리 노드 선택
            guard let currentNode = unvisited.min(by: { distances[$0]! < distances[$1]! }),
                  distances[currentNode]! != Int.max else {
                break
            }
            
            unvisited.remove(currentNode)
            computationSteps.append("2. 노드 \(currentNode) 선택 (현재 거리: \(distances[currentNode]!))")
            
            // 목적지에 도달한 경우
            if currentNode == destinationId {
                break
            }
            
            // 인접 노드들의 거리 업데이트
            if let neighbors = adjacencyList[currentNode] {
                for (neighbor, cost) in neighbors {
                    if unvisited.contains(neighbor) {
                        let newDistance = distances[currentNode]! + cost
                        if newDistance < distances[neighbor]! {
                            distances[neighbor] = newDistance
                            previousNodes[neighbor] = currentNode
                            computationSteps.append("   - \(neighbor)의 거리 업데이트: \(distances[neighbor]!) -> \(newDistance)")
                        }
                    }
                }
            }
        }
        
        // 경로 재구성
        if distances[destinationId] == Int.max {
            return ShortestPathResponse(
                success: false,
                sourceId: sourceId,
                destinationId: destinationId,
                totalCost: -1,
                path: [],
                algorithm: "link_state",
                message: "'\(sourceId)'에서 '\(destinationId)'로의 경로가 존재하지 않습니다.",
                computationSteps: computationSteps
            )
        }
        
        // 최단 경로 구성
        var path: [PathInfo] = []
        var currentNodeId = destinationId
        var pathNodes: [String] = []
        
        while let previousNode = previousNodes[currentNodeId] {
            pathNodes.insert(currentNodeId, at: 0)
            currentNodeId = previousNode
        }
        pathNodes.insert(sourceId, at: 0)
        
        // PathInfo 배열 생성
        var cumulativeCost = 0
        for nodeId in pathNodes {
            let node = topology.nodes.first { $0.id == nodeId }!
            path.append(PathInfo(
                nodeId: nodeId,
                nodeName: node.name,
                cumulativeCost: cumulativeCost
            ))
            
            if nodeId != destinationId {
                // 다음 노드까지의 비용 추가
                let nextNodeId = pathNodes[pathNodes.firstIndex(of: nodeId)! + 1]
                if let cost = getLinkCost(from: nodeId, to: nextNodeId) {
                    cumulativeCost += cost
                }
            }
        }
        
        // 마지막 노드의 누적 비용 업데이트
        if !path.isEmpty {
            path[path.count - 1] = PathInfo(
                nodeId: path.last!.nodeId,
                nodeName: path.last!.nodeName,
                cumulativeCost: distances[destinationId]!
            )
        }
        
        computationSteps.append("3. 최단 경로 완성: \(pathNodes.joined(separator: " -> ")) (총 비용: \(distances[destinationId]!))")
        
        return ShortestPathResponse(
            success: true,
            sourceId: sourceId,
            destinationId: destinationId,
            totalCost: distances[destinationId]!,
            path: path,
            algorithm: "link_state",
            message: "최단 경로를 성공적으로 계산했습니다.",
            computationSteps: computationSteps
        )
    }
    
    /// 인접 리스트 구성
    private func buildAdjacencyList() -> [String: [(String, Int)]] {
        var adjacencyList: [String: [(String, Int)]] = [:]
        
        for node in topology.nodes {
            adjacencyList[node.id] = []
        }
        
        for link in topology.links {
            adjacencyList[link.from]?.append((link.to, link.cost))
            
            if link.bidirectional {
                adjacencyList[link.to]?.append((link.from, link.cost))
            }
        }
        
        return adjacencyList
    }
    
    /// 두 노드 간 링크 비용 조회
    private func getLinkCost(from: String, to: String) -> Int? {
        // 직접 링크 확인
        if let link = topology.links.first(where: { $0.from == from && $0.to == to }) {
            return link.cost
        }
        
        // 양방향 링크 확인
        if let link = topology.links.first(where: { $0.to == from && $0.from == to && $0.bidirectional }) {
            return link.cost
        }
        
        return nil
    }
    
    /// 기본 네트워크 토폴로지 생성
    static func createDefaultTopology() -> NetworkTopology {
        let nodes = [
            NetworkNode(id: "A", name: "Router A", x: 100, y: 200),
            NetworkNode(id: "B", name: "Router B", x: 300, y: 100),
            NetworkNode(id: "C", name: "Router C", x: 500, y: 200),
            NetworkNode(id: "D", name: "Router D", x: 200, y: 350),
            NetworkNode(id: "E", name: "Router E", x: 400, y: 350),
            NetworkNode(id: "F", name: "Router F", x: 600, y: 100)
        ]
        
        let links = [
            NetworkLink(from: "A", to: "B", cost: 4),
            NetworkLink(from: "A", to: "D", cost: 2),
            NetworkLink(from: "B", to: "C", cost: 3),
            NetworkLink(from: "B", to: "E", cost: 1),
            NetworkLink(from: "C", to: "E", cost: 2),
            NetworkLink(from: "C", to: "F", cost: 6),
            NetworkLink(from: "D", to: "E", cost: 5),
            NetworkLink(from: "E", to: "F", cost: 1)
        ]
        
        return NetworkTopology(
            nodes: nodes,
            links: links,
            description: "기본 네트워크 토폴로지 - 6개 라우터로 구성된 샘플 네트워크"
        )
    }
} 