import Vapor
@preconcurrency import Redis
import Foundation

// MARK: - DNS Service

final class DNSService {
    private let redis: any RedisClient
    private let localDNSPrefix = "local_dns:"
    private let upperDNSPrefix = "upper_dns:"
    
    init(redis: any RedisClient) {
        self.redis = redis
    }
    
    // MARK: - Factory Methods
    
    static func create(for request: Request) -> DNSService {
        let redis = request.redis
        return DNSService(redis: redis)
    }
    
    // MARK: - Public Methods
    
    /// 도메인 조회 (Local DNS → Upper DNS 순서)
    func queryDomain(_ domain: String) async throws -> DNSResponse {
        let normalizedDomain = domain.lowercased()
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        // 1. Local DNS에서 조회
        if let localRecord = try await getFromLocalDNS(normalizedDomain) {
            return DNSResponse(
                domain: normalizedDomain,
                ipAddress: localRecord.ipAddress,
                success: true,
                message: "로컬 DNS에서 발견됨",
                source: .local,
                timestamp: timestamp
            )
        }
        
        // 2. Upper DNS에서 조회
        if let upperRecord = try await getFromUpperDNS(normalizedDomain) {
            // Upper DNS에서 찾은 결과를 Local DNS에 캐시
            try await storeToLocalDNS(upperRecord)
            
            return DNSResponse(
                domain: normalizedDomain,
                ipAddress: upperRecord.ipAddress,
                success: true,
                message: "상위 DNS에서 발견됨 (로컬에 캐시됨)",
                source: .upper,
                timestamp: timestamp
            )
        }
        
        // 3. 두 DNS 모두에서 찾지 못함
        return DNSResponse(
            domain: normalizedDomain,
            ipAddress: nil,
            success: false,
            message: "도메인을 찾을 수 없습니다",
            source: .notFound,
            timestamp: timestamp
        )
    }
    
    /// 도메인 등록 (Local DNS에 저장)
    func registerDomain(_ registration: DNSRegistration) async throws -> DNSResponse {
        let record = DNSRecord(
            domain: registration.domain,
            ipAddress: registration.ipAddress,
            recordType: registration.recordType
        )
        
        try await storeToLocalDNS(record)
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        return DNSResponse(
            domain: record.domain,
            ipAddress: record.ipAddress,
            success: true,
            message: "도메인이 성공적으로 등록되었습니다",
            source: .local,
            timestamp: timestamp
        )
    }
    
    /// 등록된 도메인 목록 조회
    func listRegisteredDomains() async throws -> [DNSRecord] {
        let localDomains = try await getAllFromLocalDNS()
        let upperDomains = try await getAllFromUpperDNS()
        
        return localDomains + upperDomains
    }
    
    func initializeUpperDNS() async throws {
        let upperDNSRecords = [
            DNSRecord(domain: "google.com", ipAddress: "8.8.8.8"),
            DNSRecord(domain: "naver.com", ipAddress: "223.130.200.107"),
            DNSRecord(domain: "github.com", ipAddress: "140.82.112.4"),
            DNSRecord(domain: "stackoverflow.com", ipAddress: "151.101.193.69"),
            DNSRecord(domain: "youtube.com", ipAddress: "142.250.207.110"),
            DNSRecord(domain: "facebook.com", ipAddress: "157.240.241.35"),
            DNSRecord(domain: "amazon.com", ipAddress: "176.32.103.205"),
            DNSRecord(domain: "apple.com", ipAddress: "17.253.144.10"),
            DNSRecord(domain: "microsoft.com", ipAddress: "20.112.52.29"),
            DNSRecord(domain: "netflix.com", ipAddress: "54.155.178.5")
        ]
        
        for record in upperDNSRecords {
            try await storeToUpperDNS(record)
        }
    }
    
    // MARK: - Private Methods
    
    private func getFromLocalDNS(_ domain: String) async throws -> DNSRecord? {
        let key = localDNSPrefix + domain
        let data = try await redis.get(RedisKey(key), as: Data.self).get()
        guard let data = data else {
            return nil
        }
        return try JSONDecoder().decode(DNSRecord.self, from: data)
    }
    
    private func getFromUpperDNS(_ domain: String) async throws -> DNSRecord? {
        let key = upperDNSPrefix + domain
        let data = try await redis.get(RedisKey(key), as: Data.self).get()
        guard let data = data else {
            return nil
        }
        return try JSONDecoder().decode(DNSRecord.self, from: data)
    }
    
    private func storeToLocalDNS(_ record: DNSRecord) async throws {
        let key = localDNSPrefix + record.domain
        let data = try JSONEncoder().encode(record)
        _ = try await redis.set(RedisKey(key), to: data).get()
        // TTL은 별도로 설정
        _ = try await redis.expire(RedisKey(key), after: .seconds(Int64(record.ttl))).get()
    }
    
    private func storeToUpperDNS(_ record: DNSRecord) async throws {
        let key = upperDNSPrefix + record.domain
        let data = try JSONEncoder().encode(record)
        _ = try await redis.set(RedisKey(key), to: data).get()
    }
    
    private func getAllFromLocalDNS() async throws -> [DNSRecord] {
        let scanResult = try await redis.scan(startingFrom: 0, matching: localDNSPrefix + "*").get()
        var records: [DNSRecord] = []
        
        for key in scanResult.1 { // scanResult는 (cursor, keys) 튜플
            let data = try await redis.get(RedisKey(key), as: Data.self).get()
            if let data = data {
                let record = try JSONDecoder().decode(DNSRecord.self, from: data)
                records.append(record)
            }
        }
        
        return records
    }
    
    private func getAllFromUpperDNS() async throws -> [DNSRecord] {
        let scanResult = try await redis.scan(startingFrom: 0, matching: upperDNSPrefix + "*").get()
        var records: [DNSRecord] = []
        
        for key in scanResult.1 { // scanResult는 (cursor, keys) 튜플
            let data = try await redis.get(RedisKey(key), as: Data.self).get()
            if let data = data {
                let record = try JSONDecoder().decode(DNSRecord.self, from: data)
                records.append(record)
            }
        }
        
        return records
    }
}

 