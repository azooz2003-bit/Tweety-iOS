//
//  MangaScript.swift
//  GrokMode
//
//  Created by Claude on 12/7/25.
//

import Foundation
import UIKit

// MARK: - Core Data Models

/// Represents a manga page with its image
struct MangaPage {
    let image: UIImage
    let pageNumber: Int?

    init(image: UIImage, pageNumber: Int? = nil) {
        self.image = image
        self.pageNumber = pageNumber
    }
}

/// Represents a character in the manga
struct Character: Codable, Hashable {
    let name: String
    let personality: PersonalityTraits
    let voiceCharacteristics: VoiceCharacteristics?

    struct PersonalityTraits: Codable, Hashable {
        let energy: EnergyLevel        // Calm to Energetic
        let tone: EmotionalTone        // Serious to Playful
        let confidence: ConfidenceLevel // Timid to Confident
        let speech: SpeechStyle        // Formal to Casual

        enum EnergyLevel: String, Codable {
            case veryCalm, calm, moderate, energetic, veryEnergetic
        }

        enum EmotionalTone: String, Codable {
            case serious, neutral, playful, comedic
        }

        enum ConfidenceLevel: String, Codable {
            case timid, reserved, confident, veryConfident, domineering
        }

        enum SpeechStyle: String, Codable {
            case formal, polite, neutral, casual, slang
        }
    }

    struct VoiceCharacteristics: Codable, Hashable {
        let pitch: VoicePitch
        let speed: SpeechSpeed
        let emphasis: EmphasisStyle

        enum VoicePitch: String, Codable {
            case veryLow, low, medium, high, veryHigh
        }

        enum SpeechSpeed: String, Codable {
            case verySlow, slow, normal, fast, veryFast
        }

        enum EmphasisStyle: String, Codable {
            case monotone, subtle, moderate, dramatic, theatrical
        }
    }
}

/// Represents a single segment of the manga script
struct ScriptSegment: Codable, Identifiable {
    let id: UUID
    let type: SegmentType
    let content: String
    let character: Character?
    let emotion: Emotion?
    let timing: TimingInfo?

    enum SegmentType: String, Codable {
        case dialogue       // Character speaking
        case narration      // Narrative text
        case soundEffect    // Sound effects (e.g., "BOOM!", "whoosh")
        case action         // Action description (e.g., "punches wall")
        case thought        // Internal monologue
    }

    enum Emotion: String, Codable {
        case neutral, happy, sad, angry, surprised, scared
        case excited, confused, disgusted, determined, worried
    }

    struct TimingInfo: Codable {
        let pauseBefore: TimeInterval  // Pause before this segment (seconds)
        let duration: TimeInterval?    // Expected duration (optional)
    }

    init(
        id: UUID = UUID(),
        type: SegmentType,
        content: String,
        character: Character? = nil,
        emotion: Emotion? = nil,
        timing: TimingInfo? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.character = character
        self.emotion = emotion
        self.timing = timing
    }
}

/// Represents the complete parsed script from a manga page
struct MangaScript: Codable {
    let pageNumber: Int?
    let segments: [ScriptSegment]
    let characters: [Character]
    let metadata: ScriptMetadata

    struct ScriptMetadata: Codable {
        let parsedAt: Date
        let sceneDescription: String?
        let mood: SceneMood?
        let estimatedDuration: TimeInterval?

        enum SceneMood: String, Codable {
            case action, comedy, dramatic, romantic, suspenseful, calm
        }
    }

    init(
        pageNumber: Int? = nil,
        segments: [ScriptSegment],
        characters: [Character],
        metadata: ScriptMetadata
    ) {
        self.pageNumber = pageNumber
        self.segments = segments
        self.characters = characters
        self.metadata = metadata
    }
}

// MARK: - Audio Performance Models

/// Represents the audio performance of a manga script
struct AudioPerformance {
    let script: MangaScript
    let audioFileURL: URL  // Simplified: just point to the WAV file
    let duration: TimeInterval
    let segmentTimings: [SegmentTiming]

    struct SegmentTiming {
        let segmentId: UUID
        let startTime: TimeInterval
        let endTime: TimeInterval
    }
}

/// Represents the playback state
enum PlaybackState {
    case idle
    case loading
    case ready
    case playing(currentTime: TimeInterval)
    case paused(currentTime: TimeInterval)
    case completed
    case failed(Error)
}
