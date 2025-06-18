import Vapor
import Redis

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Redis 설정
    let redisHost = Environment.get("REDIS_HOST") ?? "localhost"
    let redisPort = Int(Environment.get("REDIS_PORT") ?? "6379") ?? 6379
    app.redis.configuration = try RedisConfiguration(hostname: redisHost, port: redisPort)
    
    // register routes
    try routes(app)
    
    // DNS Upper DNS 초기화 (애플리케이션 시작 후에 실행)
    app.lifecycle.use(DNSInitializer())
}

// MARK: - DNS 초기화

struct DNSInitializer: LifecycleHandler {
    func didBoot(_ application: Application) throws {
        // 애플리케이션이 완전히 부팅된 후 DNS 초기화
        application.eventLoopGroup.any().makeFutureWithTask {
            do {
                let redis = application.redis
                let dnsService = DNSService(redis: redis)
                print("상위 DNS 서버 초기화 중...")
                try await dnsService.initializeUpperDNS()
                print("상위 DNS 서버 초기화 완료")
            } catch {
                application.logger.error("DNS 초기화 실패: \(error)")
            }
        }.whenComplete { _ in }
    }
}
