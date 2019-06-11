import XCTest
import class Foundation.Bundle
import JobsRedisDriver
import RedisKit
import NIO
@testable import Jobs

final class JobsRedisDriverTests: XCTestCase {
    
    var eventLoop: EventLoop!
    var jobsDriver: JobsRedisDriver!
    var jobsConfig: JobsConfig!
    var redisConn: RedisClient!
    
    override func setUp() {
        do {
            eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
            guard let url = URL(string: "redis://127.0.0.1:6379") else { return }
            guard let configuration = RedisConfiguration(url: url) else { return }
            
            let client = RedisConnectionFactory(config: configuration, eventLoop: eventLoop)
            let conn = try client.makeConnection().wait()
            
            redisConn = conn
            jobsDriver = JobsRedisDriver(client: conn, eventLoop: eventLoop)
            
            jobsConfig = JobsConfig()
            jobsConfig.add(EmailJob())
        } catch {
            XCTFail()
        }
    }
    
    override func tearDown() {
        _ = try! redisConn.delete(["key"]).wait()
        _ = try! redisConn.delete(["key-processing"]).wait()
    }

    func testSettingValue() throws {
        let job = Email(to: "email@email.com")
        let jobData = try JSONEncoder().encode(job)
        let jobStorage = JobStorage(key: "key",
                                    data: jobData,
                                    maxRetryCount: 1,
                                    id: UUID().uuidString,
                                    jobName: EmailJob.jobName)
        
        try jobsDriver.set(key: "key", jobStorage: jobStorage).wait()
        
        XCTAssertNotNil(try redisConn.get(jobStorage.id).wait())
        
        guard let jobId = try redisConn.rpop(from: "key").wait().string else {
            XCTFail()
            return
        }
        
        guard let retrievedJobData = try redisConn.get(jobId).wait()?.data(using: .utf8) else {
            XCTFail()
            return
        }
        
        let decoder = try JSONDecoder().decode(DecoderUnwrapper.self, from: retrievedJobData)
        let retrievedJobStorage = try JobStorage(from: decoder.decoder)
        let retrievedJob = try JSONDecoder().decode(Email.self, from: retrievedJobStorage.data)
        
        XCTAssertEqual(retrievedJobStorage.maxRetryCount, 1)
        XCTAssertEqual(retrievedJobStorage.key, "key")
        XCTAssertEqual(retrievedJob.to, "email@email.com")
        
        //Assert that it was not added to the processing list
        XCTAssertEqual(try redisConn.lrange(within: (0, 0), from: "key-processing").wait().count, 0)
    }
    
    func testGettingValue() throws {
        let firstJob = Email(to: "email@email.com")
        let secondJob = Email(to: "email2@email.com")
        
        let firstJobData = try JSONEncoder().encode(firstJob)
        let secondJobData = try JSONEncoder().encode(secondJob)
        
        let firstJobStorage = JobStorage(key: "key", data: firstJobData, maxRetryCount: 1, id: UUID().uuidString, jobName: EmailJob.jobName)
        let secondJobStorage = JobStorage(key: "key", data: secondJobData, maxRetryCount: 1, id: UUID().uuidString, jobName: EmailJob.jobName)
        
        try jobsDriver.set(key: "key", jobStorage: firstJobStorage).wait()
        try jobsDriver.set(key: "key", jobStorage: secondJobStorage).wait()

        guard let fetchedJobData = try jobsDriver.get(key: "key").wait() else {
            XCTFail()
            return
        }

        let fetchedJob = try JSONDecoder().decode(Email.self, from: fetchedJobData.data)
        XCTAssertEqual(fetchedJob.to, "email@email.com")
        
        //Assert that the base list still has data in it and the processing list has 1
        XCTAssertNotEqual(try redisConn.lrange(within: (0, 0), from: "key").wait().count, 0)
        XCTAssertEqual(try redisConn.lrange(within: (0, 0), from: "key-processing").wait().count, 1)
        
        try jobsDriver.completed(key: "key", jobStorage: fetchedJobData).wait()
        XCTAssertEqual(try redisConn.lrange(within: (0, 0), from: "key-processing").wait().count, 0)
    }
    
    static var allTests = [
        ("testSettingValue", testSettingValue),
        ("testGettingValue", testGettingValue)
    ]
}

struct Email: Codable, JobData {
    let to: String
}

struct EmailJob: Job {
    func dequeue(_ context: JobContext, _ data: Email) -> EventLoopFuture<Void> {
        return context.eventLoop.makeSucceededFuture(())
    }
}

struct DecoderUnwrapper: Decodable {
    let decoder: Decoder
    init(from decoder: Decoder) { self.decoder = decoder }
}
