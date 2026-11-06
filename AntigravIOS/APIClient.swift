import Foundation
import Combine
import Photos

@MainActor
final class AntigravAPIClient: ObservableObject {
    @Published var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "antigrav_server_url")
        }
    }

    // Server State & Health
    @Published var serverStatus: ServerStatus?
    @Published var isServerOnline: Bool = false
    @Published var serverLatencyMs: Int?
    @Published var isCheckingServer: Bool = false

    // App Data
    @Published var availablePoses: [PoseInfo] = []
    @Published var currentJob: JobDetailResponse?
    @Published var isScanning: Bool = false
    @Published var recentJobs: [JobListItem] = []
    @Published var reviewQueue: [VideoAnalysisItem] = []
    @Published var libraryResults: [VideoAnalysisItem] = []
    @Published var libraryTotal: Int = 0

    // Loading & Error States
    @Published var isLoadingJobs: Bool = false
    @Published var isLoadingReview: Bool = false
    @Published var isLoadingLibrary: Bool = false
    @Published var errorMessage: String?

    private var pollingTask: Task<Void, Never>?

    init() {
        self.baseURL = UserDefaults.standard.string(forKey: "antigrav_server_url") ?? "http://192.168.1.100:8000"
    }

    private func endpoint(_ path: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        guard var components = URLComponents(string: "\(trimmed)\(path)") else {
            throw URLError(.badURL)
        }
        if let queryItems = queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    // MARK: - Server Health & Diagnostics

    func checkServerStatus() async {
        isCheckingServer = true
        let start = DispatchTime.now()
        do {
            let url = try endpoint("/api/status")
            var req = URLRequest(url: url)
            req.timeoutInterval = 4.0

            let (data, response) = try await URLSession.shared.data(for: req)
            let elapsed = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
            self.serverLatencyMs = Int(elapsed / 1_000_000)

            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                self.serverStatus = try JSONDecoder().decode(ServerStatus.self, from: data)
                self.isServerOnline = true
                self.errorMessage = nil
            } else {
                self.isServerOnline = false
            }
        } catch {
            self.isServerOnline = false
            self.serverLatencyMs = nil
        }
        isCheckingServer = false
    }

    // MARK: - Poses

    func fetchPoses() async {
        do {
            let url = try endpoint("/api/poses")
            let (data, _) = try await URLSession.shared.data(from: url)
            self.availablePoses = try JSONDecoder().decode([PoseInfo].self, from: data)
        } catch {
            // Non-fatal, use defaults if offline
        }
    }

    // MARK: - Scrape & Job Tracking

    func startScrape(request: ScrapeJobRequest) async {
        isScanning = true
        errorMessage = nil
        pollingTask?.cancel()

        do {
            let url = try endpoint("/api/scrape")
            var urlReq = URLRequest(url: url)
            urlReq.httpMethod = "POST"
            urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlReq.httpBody = try JSONEncoder().encode(request)

            let (data, response) = try await URLSession.shared.data(for: urlReq)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let errText = String(data: data, encoding: .utf8) ?? "Server returned error"
                throw NSError(domain: "Antigrav", code: 1, userInfo: [NSLocalizedDescriptionKey: errText])
            }

            let initialJob = try JSONDecoder().decode(JobDetailResponse.self, from: data)
            self.currentJob = initialJob
            startPollingJob(jobId: initialJob.id)
        } catch {
            self.errorMessage = "Failed to start scan: \(error.localizedDescription)"
            self.isScanning = false
        }
    }

    func startPollingJob(jobId: String) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // Poll every 2s
                guard let self = self else { break }

                do {
                    let job = try await self.fetchJobDetail(id: jobId)
                    self.currentJob = job

                    if ["completed", "failed", "cancelled"].contains(job.status.lowercased()) {
                        self.isScanning = false
                        await self.fetchReviewQueue()
                        await self.fetchJobs()
                        break
                    }
                } catch {
                    // Ignore single poll error and continue
                }
            }
        }
    }

    func cancelJob(id: String) async {
        do {
            let url = try endpoint("/api/jobs/\(id)")
            var req = URLRequest(url: url)
            req.httpMethod = "DELETE"
            _ = try await URLSession.shared.data(for: req)
            pollingTask?.cancel()
            isScanning = false
            await fetchJobs()
        } catch {
            self.errorMessage = "Failed to cancel job: \(error.localizedDescription)"
        }
    }

    // MARK: - Jobs History

    func fetchJobs(limit: Int = 50, status: String? = nil) async {
        isLoadingJobs = true
        var queries = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let s = status { queries.append(URLQueryItem(name: "status", value: s)) }

        do {
            let url = try endpoint("/api/jobs", queryItems: queries)
            let (data, _) = try await URLSession.shared.data(from: url)
            self.recentJobs = try JSONDecoder().decode([JobListItem].self, from: data)
        } catch {
            // Keep existing
        }
        isLoadingJobs = false
    }

    func fetchJobDetail(id: String) async throws -> JobDetailResponse {
        let url = try endpoint("/api/jobs/\(id)")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(JobDetailResponse.self, from: data)
    }

    // MARK: - Global Review Queue

    func fetchReviewQueue() async {
        isLoadingReview = true
        do {
            let url = try endpoint("/api/review-queue")
            let (data, _) = try await URLSession.shared.data(from: url)
            let res = try JSONDecoder().decode(ReviewQueueResponse.self, from: data)

            // Deduplicate by video identity (videoId, tiktokUrl, or filename)
            var seen = Set<String>()
            var unique: [VideoAnalysisItem] = []
            for item in res.reviewQueue {
                let key: String
                if let vid = item.videoId, !vid.isEmpty {
                    key = vid
                } else if let tt = item.tiktokUrl, !tt.isEmpty {
                    key = tt
                } else {
                    key = item.filename
                }
                if !seen.contains(key) {
                    seen.insert(key)
                    unique.append(item)
                }
            }
            self.reviewQueue = unique
        } catch {
            // Keep existing
        }
        isLoadingReview = false
    }

    func reviewResult(resultId: String, action: String, poseName: String? = nil, deleteFile: Bool = false) async {
        do {
            let url = try endpoint("/api/results/\(resultId)/review")
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let payload = ReviewActionRequest(action: action, poseName: poseName, deleteFile: deleteFile)
            req.httpBody = try JSONEncoder().encode(payload)

            _ = try await URLSession.shared.data(for: req)

            // Remove locally for instantaneous UI response
            self.reviewQueue.removeAll { $0.id == resultId }

            if var job = currentJob {
                job = JobDetailResponse(
                    id: job.id,
                    jobType: job.jobType,
                    status: job.status,
                    createdAt: job.createdAt,
                    startedAt: job.startedAt,
                    completedAt: job.completedAt,
                    progressCurrent: job.progressCurrent,
                    progressTotal: job.progressTotal,
                    progressMessage: job.progressMessage,
                    error: job.error,
                    inputPath: job.inputPath,
                    compilationUrl: job.compilationUrl,
                    summary: job.summary,
                    matched: job.matched,
                    reviewQueue: job.reviewQueue?.filter { $0.id != resultId },
                    unclassified: job.unclassified,
                    matchedTiktokUrls: job.matchedTiktokUrls,
                    matchedVideoUrls: job.matchedVideoUrls
                )
                self.currentJob = job
            }
        } catch {
            self.errorMessage = "Review action failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Library & Results

    func fetchLibraryResults(pose: String? = nil, matchStatus: String? = nil, limit: Int = 100) async {
        isLoadingLibrary = true
        var queries = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let p = pose, !p.isEmpty, p.lowercased() != "all" {
            queries.append(URLQueryItem(name: "pose", value: p))
        }
        if let m = matchStatus, !m.isEmpty {
            queries.append(URLQueryItem(name: "match_status", value: m))
        }

        do {
            let url = try endpoint("/api/results", queryItems: queries)
            let (data, _) = try await URLSession.shared.data(from: url)
            let res = try JSONDecoder().decode(ResultsListResponse.self, from: data)
            self.libraryResults = res.results
            self.libraryTotal = res.total
        } catch {
            // Keep existing
        }
        isLoadingLibrary = false
    }

    // MARK: - Video URL Resolvers & Downloads

    func compileJob(jobId: String, poses: String) async -> CompilationResponse? {
        do {
            let url = try endpoint("/api/jobs/\(jobId)/compile", queryItems: [URLQueryItem(name: "poses", value: poses)])
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            let (data, _) = try await URLSession.shared.data(for: req)
            return try JSONDecoder().decode(CompilationResponse.self, from: data)
        } catch {
            self.errorMessage = "Compilation failed: \(error.localizedDescription)"
            return nil
        }
    }

    func resolveVideoURL(_ rawURL: String?) -> URL? {
        guard let raw = rawURL, !raw.isEmpty else { return nil }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return URL(string: raw)
        }
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        let cleanPath = raw.hasPrefix("/") ? raw : "/\(raw)"
        return URL(string: "\(trimmed)\(cleanPath)")
    }

    func downloadVideoToTemp(from url: URL, filename: String) async throws -> URL {
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        return destinationURL
    }

    func saveVideoToCameraRoll(fileURL: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw NSError(
                domain: "PhotoError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Photo library access denied. Please allow 'Add Photos Only' in iOS Settings."]
            )
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
        }
    }
}
