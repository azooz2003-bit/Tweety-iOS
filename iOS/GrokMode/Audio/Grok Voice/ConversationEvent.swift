//
//  VoiceMessageEvent.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/11/25.
//


nonisolated
struct ConversationEvent: Codable {
    let type: MessageEventType
    let audio: String? // Base64 encoded audio data
    let text: String? // Text content
    let delta: String? // Audio delta for streaming responses
    let session: SessionConfig? // Session configuration
    let item: ConversationItem? // Conversation items
    var tools: [ToolDefinition]? = nil // Tool definitions for session update
    var tool_call_id: String? = nil // For function call outputs
    
    // For response.function_call_arguments.done
    var call_id: String? = nil
    var name: String? = nil
    var arguments: String? = nil

    // Additional fields from XAI messages
    let event_id: String?
    let previous_item_id: String?
    let response_id: String?
    let output_index: Int?
    let item_id: String?
    let content_index: Int?
    let audio_start_ms: Int?
    let audio_end_ms: Int?
    let start_time: Double?
    let timestamp: Int?
    let part: ContentPart?
    let response: Response?
    let conversation: Conversation?

    /// Documented event types. NOTE: The client may still receive event types not listed here.
    enum MessageEventType: String, Codable {
        // Server events
        case sessionUpdated = "session.updated", conversationCreated = "conversation.created", inputAudioBufferSpeechStarted = "input_audio_buffer.speech_started", inputAudioBufferSpeechStopped = "input_audio_buffer.speech_stopped", inputAudioBufferCommitted = "input_audio_buffer.committed", conversationItemInputAudioTranscriptionCompleted = "conversation.item.input_audio_transcription.completed", conversationItemAdded = "conversation.item.added", responseCreated = "response.created", responseOutputItemAdded = "response.output_item.added", responseDone = "reponse.done", responseOutputAudioTranscriptDone = "response.output_audio_transcript.done", responseOutputAudioDelta = "response.output_audio.delta", responseOutputAudioDone = "response.output_audio.done", responseFunctionCallArgumentsDone = "response.function_call_arguments.done", conversationItemTruncated = "conversation.item.truncated", responseOutputAudioTranscriptDelta = "'response.output_audio_transcript.delta"


        // Client events
        case sessionUpdate = "session.update", inputAudioBufferAppend = "input_audio_buffer.append", conversationItemCommit = "conversation.item.commit", conversationItemCreate = "conversation.item.create", responseCreate = "response.create", inputAudioBufferCommit = "input_audio_buffer.commit", conversationItemTruncate = "conversation.item.truncate"


        case error, ping
    }

    // Session configuration
    struct SessionConfig: Codable {
        enum Voice: String, Codable {
            case Ara, Rex, Sal, Eve, Una, Leo
        }

        let instructions: String?
        let voice: Voice?
        let audio: AudioConfig?
        let turnDetection: TurnDetection?
        var tools: [ToolDefinition]? = nil
        var tool_choice: String? = nil // "auto", "none", or "required" (or specific tool)

        enum CodingKeys: String, CodingKey {
            case instructions, voice, audio, tools, tool_choice
            case turnDetection = "turn_detection"
        }
    }

    struct ToolDefinition: Codable {
        let type: String // "function"
        let name: String? // Optional - XAI API sometimes sends incomplete tool definitions
        let description: String? // Optional to handle API variations
        let parameters: JSONValue? // JSON object of schema - optional to handle incomplete responses

        static let xSearch = ToolDefinition(type: "x_search", name: nil, description: nil, parameters: nil)
        static let webSearch = ToolDefinition(type: "web_search", name: nil, description: nil, parameters: nil)
    }

    enum JSONValue: Codable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case null
        case array([JSONValue])
        case object([String: JSONValue])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let x = try? container.decode(String.self) {
                self = .string(x)
                return
            }
            if let x = try? container.decode(Double.self) {
                self = .number(x)
                return
            }
            if let x = try? container.decode(Bool.self) {
                self = .bool(x)
                return
            }
            if container.decodeNil() {
                self = .null
                return
            }
            if let x = try? container.decode([JSONValue].self) {
                self = .array(x)
                return
            }
            if let x = try? container.decode([String: JSONValue].self) {
                self = .object(x)
                return
            }
            throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for JSONValue"))
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let x): try container.encode(x)
            case .number(let x): try container.encode(x)
            case .bool(let x): try container.encode(x)
            case .null: try container.encodeNil()
            case .array(let x): try container.encode(x)
            case .object(let x): try container.encode(x)
            }
        }
    }

    struct AudioConfig: Codable {
        let input: AudioFormat?
        let output: AudioFormat?
    }

    struct AudioFormat: Codable {
        let format: AudioFormatType?

        enum CodingKeys: String, CodingKey {
            case format
        }
    }

    struct AudioFormatType: Codable {
        enum FormatType: String, Codable {
            case audioPcm = "audio/pcm", audioPcmu = "audio/pcmu", audioPcma = "audio/pcma"
        }

        enum SampleRate: Int, Codable {
            case eightKHz = 8000, sixteenKHz = 16000, twentyOneKHz = 21050, twentyFourKHz = 24000, thirtyTwoKHz = 32000, fourtyFourKHz = 44100, fourtyEightKHz = 48000
        }

        let type: FormatType // "audio/pcm"
        let rate: SampleRate // Sample rate
    }

    struct TurnDetection: Codable {
        enum DetectionType: String, Codable {
            case serverVad = "server_vad"
        }
        let type: DetectionType? // "server_vad"
    }

    struct ConversationItem: Codable {
        let id: String?
        let object: String?
        let type: String // "message" or "function_call" or "function_call_output"
        let status: String?
        let role: String? // "user" or "assistant" or "system"
        let content: [ContentItem]?
        var tool_calls: [ToolCall]? = nil
        
        // For function_call_output
        var call_id: String? = nil
        var output: String? = nil
        
        // For function_call (if single item)
        var name: String? = nil
        var arguments: String? = nil
    }

    struct ContentItem: Codable {
        let type: String // "input_text" or "input_audio" or "text" or "audio"
        let text: String?
        let transcript: String?
        var tool_call_id: String? = nil
    }

    struct ToolCall: Codable {
        let id: String
        let type: String // "function"
        let function: FunctionCall
    }

    struct FunctionCall: Codable {
        let name: String
        let arguments: String
    }

    struct ContentPart: Codable {
        let type: String // "audio"
        let transcript: String?
    }

    struct Response: Codable {
        let id: String?
        let object: String?
        let output: [ConversationItem]?
        let status: String?
        let status_details: String?
        let usage: Usage?
    }

    struct Usage: Codable {
        let input_tokens: Int?
        let input_token_details: TokenDetails?
        let output_tokens: Int?
        let output_token_details: TokenDetails?
        let total_tokens: Int?
    }

    struct TokenDetails: Codable {
        let text_tokens: Int?
        let audio_tokens: Int?
        let grok_tokens: Int?
    }

    struct Conversation: Codable {
        let id: String?
        let object: String?
    }
}
