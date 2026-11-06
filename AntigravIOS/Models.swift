import Foundation

// MARK: - Server Health & Diagnostics

struct ServerStatus: Codable {
    let status: String
    let mode: String?
    let version: String
    let python: String?
    let platform: String?
    let cpuCount: Int?
    let diskFreeGb: Double?
    let diskTotalGb: Double?

    enum CodingKeys: String, CodingKey {
        case status
        case mode
        case version
        case python
        case platform
        case cpuCount = "cpu_count"
        case diskFreeGb = "disk_free_gb"
        case diskTotalGb = "disk_total_gb"
    }
}

// MARK: - Pose Definition

struct PoseInfo: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let description: String
    let rules: [String]
    let matchMode: String
    let minConfidence: Double
    let minFrames: Int?
    let priority: Int

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case rules
        case matchMode = "match_mode"
        case minConfidence = "min_confidence"
        case minFrames = "min_frames"
        case priority
    }
}

// MARK: - Requests

struct ScrapeJobRequest: Codable {
    let username: String
    let poses: String
    let limit: Int
    let confidence: Double
    let sampleInterval: Double
    let modelComplexity: Int
    let extractSegments: Bool
    let compileVideo: Bool
    let autoCleanupUnmatched: Bool

    enum CodingKeys: String, CodingKey {
        case username
        case poses
        case limit
        case confidence
        case sampleInterval = "sample_interval"
        case modelComplexity = "model_complexity"
        case extractSegments = "extract_segments"
        case compileVideo = "compile_video"
        case autoCleanupUnmatched = "auto_cleanup_unmatched"
    }
}

struct ReviewActionRequest: Codable {
    let action: String // "approve" or "reject"
    let poseName: String?
    let deleteFile: Bool

    enum CodingKeys: String, CodingKey {
        case action
        case poseName = "pose_name"
        case deleteFile = "delete_file"
    }
}

// MARK: - Segments & Video Results

struct TimeSegmentItem: Codable, Hashable, Identifiable {
    var id: String { "\(poseName)_\(start)_\(end)" }
    let start: Double
    let end: Double
    let poseName: String
    let extractedPath: String?
    let segmentDownloadUrl: String?

    enum CodingKeys: String, CodingKey {
        case start
        case end
        case poseName = "pose_name"
        case extractedPath = "extracted_path"
        case segmentDownloadUrl = "segment_download_url"
    }
}

struct VideoAnalysisItem: Codable, Identifiable, Hashable {
    let id: String
    let jobId: String
    let videoId: String?
    let tiktokUrl: String?
    let description: String?
    let likeCount: Int?
    let playCount: Int?
    let videoPath: String?
    let filename: String
    let durationSec: Double?
    let fps: Double?
    let width: Int?
    let height: Int?
    let detectedPose: String
    let matchStatus: String // "matched", "close_match", "approved", "rejected", "unclassified"
    let closestPose: String?
    let closenessScore: Double?
    let reviewReason: String?
    let bestTimestampSec: Double?
    let confidence: Double?
    let segments: [TimeSegmentItem]?
    let totalFrames: Int?
    let error: String?
    let videoDownloadUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case jobId = "job_id"
        case videoId = "video_id"
        case tiktokUrl = "tiktok_url"
        case description
        case likeCount = "like_count"
        case playCount = "play_count"
        case videoPath = "video_path"
        case filename
        case durationSec = "duration_sec"
        case fps
        case width
        case height
        case detectedPose = "detected_pose"
        case matchStatus = "match_status"
        case closestPose = "closest_pose"
        case closenessScore = "closeness_score"
        case reviewReason = "review_reason"
        case bestTimestampSec = "best_timestamp_sec"
        case confidence
        case segments
        case totalFrames = "total_frames"
        case error
        case videoDownloadUrl = "video_download_url"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: VideoAnalysisItem, rhs: VideoAnalysisItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Jobs

struct JobSummary: Codable {
    let totalAnalyzed: Int
    let matchedCount: Int
    let reviewQueueCount: Int
    let unclassifiedCount: Int

    enum CodingKeys: String, CodingKey {
        case totalAnalyzed = "total_analyzed"
        case matchedCount = "matched_count"
        case reviewQueueCount = "review_queue_count"
        case unclassifiedCount = "unclassified_count"
    }
}

struct JobListItem: Codable, Identifiable {
    let id: String
    let jobType: String
    let status: String
    let createdAt: String
    let startedAt: String?
    let completedAt: String?
    let progressCurrent: Int?
    let progressTotal: Int?
    let progressMessage: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case id
        case jobType = "job_type"
        case status
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case progressCurrent = "progress_current"
        case progressTotal = "progress_total"
        case progressMessage = "progress_message"
        case error
    }
}

struct JobDetailResponse: Codable, Identifiable {
    let id: String
    let jobType: String
    let status: String
    let createdAt: String
    let startedAt: String?
    let completedAt: String?
    let progressCurrent: Int
    let progressTotal: Int
    let progressMessage: String
    let error: String?
    let inputPath: String?
    let compilationUrl: String?
    let summary: JobSummary?
    let matched: [VideoAnalysisItem]?
    let reviewQueue: [VideoAnalysisItem]?
    let unclassified: [VideoAnalysisItem]?
    let matchedTiktokUrls: [String]?
    let matchedVideoUrls: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case jobType = "job_type"
        case status
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case progressCurrent = "progress_current"
        case progressTotal = "progress_total"
        case progressMessage = "progress_message"
        case error
        case inputPath = "input_path"
        case compilationUrl = "compilation_url"
        case summary
        case matched
        case reviewQueue = "review_queue"
        case unclassified
        case matchedTiktokUrls = "matched_tiktok_urls"
        case matchedVideoUrls = "matched_video_urls"
    }
}

// MARK: - Queue & Results Responses

struct ReviewQueueResponse: Codable {
    let reviewQueue: [VideoAnalysisItem]
    let total: Int

    enum CodingKeys: String, CodingKey {
        case reviewQueue = "review_queue"
        case total
    }
}

struct ResultsListResponse: Codable {
    let results: [VideoAnalysisItem]
    let total: Int
    let limit: Int
    let offset: Int
}

struct CompilationResponse: Codable {
    let status: String
    let compilationPath: String
    let compilationUrl: String

    enum CodingKeys: String, CodingKey {
        case status
        case compilationPath = "compilation_path"
        case compilationUrl = "compilation_url"
    }
}
