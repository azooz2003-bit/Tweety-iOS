import Testing
@testable import GrokMode
import Foundation

struct XToolTests {
    
    @Test("Test creating a tweet")
    func testCreateTweet() async throws {
        // Ensure we have a valid configuration
        // Assuming Config.xApiKey pulls from Info.plist correctly in test environment
        // If not, we might need to manually set it or ensure credentials are present.
        
        // Note: This test performs a REAL network request to X API.
        // It consumes API quota and creates a real tweet.
        
        let orchestrator = XToolOrchestrator()
        let tweetText = "Automated Test Tweet via XCTest - \(Date().timeIntervalSince1970)"
        
        print("XToolTests: Attempting to create tweet: '\(tweetText)'")
        
        let result = await orchestrator.executeTool(
            .createTweet,
            parameters: ["text": tweetText]
        )
        
        // Assertions
        #expect(result.success, "Tool execution should succeed")
        #expect(result.statusCode == 201 || result.statusCode == 200, "Status code should be 200 or 201")
        
        if let response = result.response {
            print("XToolTests: Response: \(response)")
            #expect(response.contains("id"), "Response should contain tweet ID")
        } else {
            #expect(false, "Response should not be nil")
        }
        
        if let error = result.error {
            print("XToolTests: Failed with error: \(error.message)")
        }
    }
}
