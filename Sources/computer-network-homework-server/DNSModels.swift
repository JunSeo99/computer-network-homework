import Foundation
import Vapor

// MARK: - DNS Models

struct DNSRecord: Codable, Content {
    let domain: String
    let ipAddress: String
    let recordType: String // A, AAAA, CNAME 등
    let ttl: Int // Time to Live
    
    init(domain: String, ipAddress: String, recordType: String = "A", ttl: Int = 3600) {
        self.domain = domain.lowercased()
        self.ipAddress = ipAddress
        self.recordType = recordType
        self.ttl = ttl
    }
}

struct DNSQuery: Codable {
    let domain: String
    let recordType: String
    
    init(domain: String, recordType: String = "A") {
        self.domain = domain.lowercased()
        self.recordType = recordType
    }
}

struct DNSResponse: Codable, Content {
    let domain: String
    let ipAddress: String?
    let success: Bool
    let message: String
    let source: DNSSource // Local 또는 Upper DNS
    let timestamp: String
    
    enum DNSSource: String, Codable {
        case local = "local_dns"
        case upper = "upper_dns"
        case notFound = "not_found"
    }
}

struct DNSRegistration: Codable, Content {
    let domain: String
    let ipAddress: String
    let recordType: String
    
    init(domain: String, ipAddress: String, recordType: String = "A") {
        self.domain = domain.lowercased()
        self.ipAddress = ipAddress
        self.recordType = recordType
    }
}

// MARK: - DNS Message Types for WebSocket

enum DNSMessage: Codable {
    case query(String) // 도메인 조회
    case register(DNSRegistration) // 도메인 등록
    case list // 등록된 도메인 목록 조회
    
    enum CodingKeys: String, CodingKey {
        case type, domain, ipAddress, recordType
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "query":
            let domain = try container.decode(String.self, forKey: .domain)
            self = .query(domain)
        case "register":
            let domain = try container.decode(String.self, forKey: .domain)
            let ipAddress = try container.decode(String.self, forKey: .ipAddress)
            let recordType = try container.decodeIfPresent(String.self, forKey: .recordType) ?? "A"
            self = .register(DNSRegistration(domain: domain, ipAddress: ipAddress, recordType: recordType))
        case "list":
            self = .list
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown DNS message type")
            )
        }
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .query(let domain):
            try container.encode("query", forKey: .type)
            try container.encode(domain, forKey: .domain)
        case .register(let registration):
            try container.encode("register", forKey: .type)
            try container.encode(registration.domain, forKey: .domain)
            try container.encode(registration.ipAddress, forKey: .ipAddress)
            try container.encode(registration.recordType, forKey: .recordType)
        case .list:
            try container.encode("list", forKey: .type)
        }
    }
} 