import Testing
@testable import GrokMode
import Foundation

enum LinearAPITestError: Error {
    case missingAPIKey
}

struct LinearAPITests {
    private static var apiToken: String {
        get throws {
            guard let token = Bundle.main.infoDictionary?["LINEAR_API_KEY"] as? String else {
                throw LinearAPITestError.missingAPIKey
            }
            return token
        }
    }

    private static func createService() throws -> LinearAPIService {
        try LinearAPIService(apiToken: apiToken)
    }

    @Test("Test fetching teams")
    func testGetTeams() async throws {
        // Skip test if no valid token is provided
        try #require(!Self.apiToken.contains("PLACEHOLDER"), "Please set a valid Linear API token for testing")

        let teams = try await Self.createService().getTeams()

        // Should have at least one team
        #expect(!teams.isEmpty, "Should retrieve at least one team")

        // Verify team structure
        for team in teams {
            #expect(!team.id.isEmpty, "Team ID should not be empty")
            #expect(!team.name.isEmpty, "Team name should not be empty")
            #expect(!team.key.isEmpty, "Team key should not be empty")
        }
    }

    @Test("Test creating an issue")
    func testCreateIssue() async throws {
        // Skip test if no valid token is provided
        try #require(!Self.apiToken.contains("PLACEHOLDER"), "Please set a valid Linear API token for testing")

        // First get teams to find a valid team ID
        let teams = try await Self.createService().getTeams()
        let testTeam = try #require(teams.first, "Need at least one team to create an issue")

        let testTitle = "Test Issue from Swift API - \(Date().timeIntervalSince1970)"
        let testDescription = "This is a test issue created via the LinearAPIService Swift module for testing purposes."

        let createdIssue = try await Self.createService().createIssue(
            title: testTitle,
            description: testDescription,
            teamId: testTeam.id
        )

        // Verify the created issue
        #expect(createdIssue.title == testTitle, "Issue title should match")
        #expect(!createdIssue.id.isEmpty, "Issue ID should not be empty")
        #expect(createdIssue.number > 0, "Issue number should be greater than 0")
        #expect(!createdIssue.url.isEmpty, "Issue URL should not be empty")
        #expect(!createdIssue.createdAt.isEmpty, "Created date should not be empty")
    }

    @Test("Test creating issue with minimal data")
    func testCreateIssueMinimal() async throws {
        // Skip test if no valid token is provided
        try #require(!Self.apiToken.contains("PLACEHOLDER"), "Please set a valid Linear API token for testing")

        // First get teams to find a valid team ID
        let teams = try await Self.createService().getTeams()
        let testTeam = try #require(teams.first, "Need at least one team to create an issue")

        let testTitle = "Minimal Test Issue - \(Date().timeIntervalSince1970)"

        let createdIssue = try await Self.createService().createIssue(
            title: testTitle,
            teamId: testTeam.id
        )

        // Verify the created issue
        #expect(createdIssue.title == testTitle, "Issue title should match")
        #expect(createdIssue.id.count == 36, "Issue ID should be a UUID (36 characters)")
    }

    @Test("Test error handling with invalid token")
    func testInvalidToken() async throws {
        let invalidService = LinearAPIService(apiToken: "invalid-token")

        do {
            _ = try await invalidService.getTeams()
            #expect(false, "Should fail with invalid token")
        } catch let error as LinearAPIError {
            // Should get some kind of error
            #expect(true, "Got expected error: \(error.localizedDescription)")
        } catch {
            #expect(false, "Should get LinearAPIError, got: \(error)")
        }
    }
//
//    @Test("Test error handling with invalid team ID")
//    func testInvalidTeamId() async throws {
//        // Skip test if no valid token is provided
//        try #require(!Self.apiToken.contains("PLACEHOLDER"), "Please set a valid Linear API token for testing")
//
//        let invalidTeamId = "invalid-uuid"
//
//        do {
//            _ = try await Self.createService().createIssue(
//                title: "Should Fail",
//                teamId: invalidTeamId
//            )
//            #expect(false, "Should fail with invalid team ID")
//        } catch let error as LinearAPIError {
//            // Should get a GraphQL validation error
//            #expect(error.localizedDescription.contains("UUID") ||
//                   error.localizedDescription.contains("teamId"),
//                   "Should get teamId validation error")
//        } catch {
//            #expect(false, "Should get LinearAPIError, got: \(error)")
//        }
//    }

    @Test("Test service initialization")
    func testServiceInitialization() {
        let testToken = "test-token-123"
        let service = LinearAPIService(apiToken: testToken)

        // Service should initialize without issues
        #expect(service != nil, "Service should initialize successfully")
    }
}
