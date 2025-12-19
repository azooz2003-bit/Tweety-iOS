//
//  OpenAIRealtimeEvent.swift
//  GrokMode
//
//  Created by Claude Code on 12/18/25.
//

import JSONSchema

/// OpenAI Realtime API event model
nonisolated
struct OpenAIRealtimeEvent: Codable {
    let type: MessageEventType
    let event_id: String?

    // Error-related
    let error: ErrorInfo?

    // Session-related
    let session: SessionConfig?

    // Audio-related
    let audio: String? // Base64 encoded audio data
    let delta: String? // Audio delta for streaming responses

    // Item-related
    let item: Item?
    let item_id: String?
    let previous_item_id: String?

    // Response-related
    let response: Response?
    let response_id: String?
    let output_index: Int?
    let content_index: Int?

    // Function call related
    let call_id: String?
    let name: String?
    let arguments: String?

    // Transcript related
    let transcript: String?
    let text: String?

    /// OpenAI Realtime API event types
    enum MessageEventType: String, Codable {
        // Server events
        case conversationCreated = "conversation.created"
        case conversationItemCreated = "conversation.item.created"
        case error
        case sessionCreated = "session.created"
        case sessionUpdated = "session.updated"
        case conversationItemAdded = "conversation.item.added"
        case conversationItemDone = "conversation.item.done"
        case conversationItemRetrieved = "conversation.item.retrieved"
        case conversationItemInputAudioTranscriptionCompleted = "conversation.item.input_audio_transcription.completed"
        case conversationItemInputAudioTranscriptionDelta = "conversation.item.input_audio_transcription.delta"
        case conversationItemInputAudioTranscriptionSegment = "conversation.item.input_audio_transcription.segment"
        case conversationItemInputAudioTranscriptionFailed = "conversation.item.input_audio_transcription.failed"
        case conversationItemTruncated = "conversation.item.truncated"
        case conversationItemDeleted = "conversation.item.deleted"
        case inputAudioBufferCommitted = "input_audio_buffer.committed"
        //input_audio_buffer.dtmf_event_received
        case inputAudioBufferCleared = "input_audio_buffer.cleared"
        case inputAudioBufferSpeechStarted = "input_audio_buffer.speech_started"
        case inputAudioBufferSpeechStopped = "input_audio_buffer.speech_stopped"
        case inputAudioBufferTimeoutTriggered = "input_audio_buffer.timeout_triggered"
        case responseCreated = "response.created"
        case responseDone = "response.done"
        case responseOutputItemAdded = "response.output_item.added"
        case responseOutputItemDone = "response.output_item.done"
        case responseContentPartAdded = "response.content_part.added"
        case responseContentPartDone = "response.content_part.done"
        case responseTextDelta = "response.output_text.delta"
        case responseTextDone = "response.output_text.done"
        case responseOutputAudioTranscriptDelta = "response.output_audio_transcript.delta"
        case responseOutputAudioTranscriptDone = "response.output_audio_transcript.done"
        case responseOutputAudioDelta = "response.output_audio.delta"
        case responseOutputAudioDone = "response.output_audio.done"

        //Tools
        case responseFunctionCallArgumentsDelta = "response.function_call_arguments.delta"
        case responseFunctionCallArgumentsDone = "response.function_call_arguments.done"

        case rateLimitsUpdated = "rate_limits.updated"

        // Client events
        case sessionUpdate = "session.update"
        case inputAudioBufferAppend = "input_audio_buffer.append"
        case inputAudioBufferCommit = "input_audio_buffer.commit"
        case inputAudioBufferClear = "input_audio_buffer.clear"
        case conversationItemCreate = "conversation.item.create"
        case conversationItemRetrieve = "conversation.item.retrieve"
        case conversationItemTruncate = "conversation.item.truncate"
        case conversationItemDelete = "conversation.item.delete"
        case responseCreate = "response.create"
        case responseCancel = "response.cancel"
    }

    // MARK: - Session Configuration

    struct SessionConfig: Codable {
        let id: String?
        let object: String?
        let type: String? // "realtime"
        let model: String? // "gpt-realtime"
        let instructions: String?
        let voice: String? // Not used - voice is in audio.output
        let audio: AudioConfig?
        let turn_detection: TurnDetection? // Not used - turn detection is in audio.input
        let tools: [ToolDefinition]?
        let tool_choice: String? // "auto", "none", "required"
        let output_modalities: [String]? // ["audio"]
        let max_output_tokens: MaxOutputTokens? // Can be "inf" or a number
        let tracing: String?
        let truncation: String? // "auto"
        let prompt: PromptConfig?
        let expires_at: Int?
        let include: [String]?

        enum MaxOutputTokens: Codable {
            case inf
            case number(Int)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let str = try? container.decode(String.self), str == "inf" {
                    self = .inf
                } else if let num = try? container.decode(Int.self) {
                    self = .number(num)
                } else {
                    self = .inf
                }
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .inf:
                    try container.encode("inf")
                case .number(let num):
                    try container.encode(num)
                }
            }
        }

        struct PromptConfig: Codable {
            let id: String?
            let version: String?
            let variables: [String: String]?
        }
    }

    struct AudioConfig: Codable {
        struct Input: Codable {
            struct Format: Codable {
                let type: String? // "audio/pcm"
                let rate: Int? // 24000
            }

            let format: Format?
            let transcription: TranscriptionConfig?
            let noise_reduction: NoiseReductionConfig?
            let turn_detection: TurnDetection?
        }

        struct Output: Codable {
            struct Format: Codable {
                let type: String? // "audio/pcm"
                let rate: Int? // 24000
            }

            let format: Format?
            let voice: String? // "alloy", "ash", etc.
            let speed: Double?
        }

        struct TranscriptionConfig: Codable {
            let language: String?
            let model: String?
            let prompt: String?
        }

        struct NoiseReductionConfig: Codable {
            let type: String? // near_field, far_field
        }

        let input: Input?
        let output: Output?
    }

    enum TurnDetection: Codable {
        case serverVad(ServerVAD)
        case semanticVad(SemanticVAD)

        struct ServerVAD: Codable {
            let create_response: Bool?
            let idle_timeout_ms: Int?
            let interrupt_response: Bool?
            let prefix_padding_ms: Int?
            let silence_duration_ms: Int?
            let threshold: Double?
        }

        struct SemanticVAD: Codable {
            let create_response: Bool?
            let eagerness: String? // "low", "medium", "high", "auto"
            let interrupt_response: Bool?
        }

        enum CodingKeys: String, CodingKey {
            case type
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "server_vad":
                let vad = try ServerVAD(from: decoder)
                self = .serverVad(vad)
            case "semantic_vad":
                let vad = try SemanticVAD(from: decoder)
                self = .semanticVad(vad)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Invalid turn detection type: \(type)"
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .serverVad(let vad):
                try container.encode("server_vad", forKey: .type)
                try vad.encode(to: encoder)
            case .semanticVad(let vad):
                try container.encode("semantic_vad", forKey: .type)
                try vad.encode(to: encoder)
            }
        }
    }

    struct ToolDefinition: Codable {
        let type: String // "function"
        let name: String
        let description: String
        let parameters: JSONSchema
    }

    // MARK: - Items

    struct Item: Codable {
        let id: String?
        let object: String? // "realtime.item"
        let type: String? // "message", "function_call", "function_call_output"
        let status: String? // "completed", "incomplete"
        let role: String? // "user", "assistant", "system"
        let content: [ContentItem]?

        // For function_call_output
        let call_id: String?
        let output: String?

        // For function_call
        let name: String?
        let arguments: String?
    }

    struct ContentItem: Codable {
        let type: String // "input_text", "input_audio", "text", "audio"
        let text: String?
        let transcript: String?
        let audio: String? // Base64 encoded
    }

    // MARK: - Response

    struct Response: Codable {
        let id: String?
        let object: String? // "realtime.response"
        let status: String? // "in_progress", "completed", "cancelled", "failed", "incomplete"
        let status_details: StatusDetails?
        let output: [Item]?
        let usage: Usage?
    }

    struct StatusDetails: Codable {
        let type: String?
        let reason: String?
        let error: ErrorDetail?
    }

    struct ErrorDetail: Codable {
        let type: String?
        let code: String?
        let message: String?
        let param: String?
        let event_id: String?
    }

    struct Usage: Codable {
        let total_tokens: Int?
        let input_tokens: Int?
        let output_tokens: Int?
        let input_token_details: TokenDetails?
        let output_token_details: TokenDetails?
    }

    struct TokenDetails: Codable {
        let cached_tokens: Int?
        let text_tokens: Int?
        let audio_tokens: Int?
    }

    struct ErrorInfo: Codable {
        let type: String?
        let code: String?
        let message: String?
        let param: String?
        let event_id: String?
    }
}
