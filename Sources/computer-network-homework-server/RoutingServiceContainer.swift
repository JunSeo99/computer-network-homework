import Foundation

// MARK: - Routing Service Container

/// 라우팅 서비스의 단일 인스턴스를 관리하는 컨테이너
struct RoutingServiceContainer {
    static let shared = RoutingService()
} 