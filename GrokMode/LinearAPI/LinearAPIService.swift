import Foundation

/// Service for interacting with Linear's GraphQL API
public class LinearAPIService {
    private let apiToken: String
    private let baseURL = URL(string: "https://api.linear.app/graphql")!

    /// Initialize with Linear API token
    /// - Parameter apiToken: Your Linear OAuth token
    public init(apiToken: String) {
        self.apiToken = apiToken
    }

    /// Create a new issue in Linear
    /// - Parameters:
    ///   - title: Issue title
    ///   - description: Issue description (optional)
    ///   - teamId: The UUID of the team to create the issue in
    /// - Returns: Created issue details
    /// - Throws: LinearAPIError if the request fails
    public func createIssue(title: String, description: String? = nil, teamId: String) async throws -> LinearIssue {
        print("TOOL CALL: createIssue called with Title: \(title)")
        let mutation = """
        mutation IssueCreate($input: IssueCreateInput!) {
            issueCreate(input: $input) {
                success
                issue {
                    id
                    title
                    number
                    url
                    createdAt
                }
            }
        }
        """

        let variables: [String: Any] = [
            "input": [
                "title": title,
                "description": description,
                "teamId": teamId
            ].compactMapValues { $0 }
        ]

        let response: GraphQLResponse<IssueCreateData> = try await performGraphQLRequest(query: mutation, variables: variables)

        guard response.data.issueCreate.success else {
            throw LinearAPIError.creationFailed("Issue creation failed")
        }

        guard let issue = response.data.issueCreate.issue else {
            throw LinearAPIError.creationFailed("No issue data returned")
        }

        return issue
    }

    /// Get all teams for the authenticated user
    /// - Returns: Array of teams
    /// - Throws: LinearAPIError if the request fails
    public func getTeams() async throws -> [LinearTeam] {
        let query = """
        query Teams {
            teams {
                nodes {
                    id
                    name
                    key
                }
            }
        }
        """

        let response: GraphQLResponse<TeamsData> = try await performGraphQLRequest(query: query, variables: nil)
        return response.data.teams.nodes
    }

    private func performGraphQLRequest<T: Decodable>(query: String, variables: [String: Any]?) async throws -> T {
        print("TOOL CALL: Performing GraphQL Request...")
        print("TOOL CALL: Variables: \(variables ?? [:])")
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ].compactMapValues { $0 }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LinearAPIError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            print("TOOL CALL: HTTP Error Status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("TOOL CALL: Response Body: \(responseString)")
            }
            throw LinearAPIError.networkError("HTTP \(httpResponse.statusCode)")
        }
        
        // Log successful response body for debugging
        if let responseString = String(data: data, encoding: .utf8) {
             print("TOOL CALL: Success Response Body (truncated): \(responseString.prefix(100))...")
        }

        do {
            let decodedResponse = try JSONDecoder().decode(T.self, from: data)
            return decodedResponse
        } catch {
            // Try to decode as error response
            if let errorResponse = try? JSONDecoder().decode(GraphQLErrorResponse.self, from: data) {
                throw LinearAPIError.graphQLError(errorResponse.errors.first?.message ?? "Unknown GraphQL error")
            }
            throw LinearAPIError.decodingError(error.localizedDescription)
        }
    }
}

// MARK: - Data Models

public struct LinearIssue: Codable, Equatable {
    public let id: String
    public let title: String
    public let number: Int
    public let url: String
    public let createdAt: String
}

public struct LinearTeam: Codable, Equatable {
    public let id: String
    public let name: String
    public let key: String
}

// MARK: - GraphQL Response Models

private struct GraphQLResponse<T: Codable>: Codable {
    let data: T
}

private struct IssueCreateData: Codable {
    let issueCreate: IssueCreateResult
}

private struct IssueCreateResult: Codable {
    let success: Bool
    let issue: LinearIssue?
}

private struct TeamsData: Codable {
    let teams: TeamsResult
}

private struct TeamsResult: Codable {
    let nodes: [LinearTeam]
}

private struct GraphQLErrorResponse: Codable {
    let errors: [GraphQLError]
}

private struct GraphQLError: Codable {
    let message: String
}

// MARK: - Errors

public enum LinearAPIError: Error, LocalizedError {
    case networkError(String)
    case decodingError(String)
    case graphQLError(String)
    case creationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .graphQLError(let message):
            return "GraphQL error: \(message)"
        case .creationFailed(let message):
            return "Creation failed: \(message)"
        }
    }
}
