import Foundation
import Combine

@MainActor
final class AntigravAPIClient: ObservableObject {
    @Published var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "antigrav_server_url")
        }
    }

    @Published var availablePoses: [PoseInfo] = []
    @Published var currentJob: JobDetailResponse?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var pollingTask: Task<Void, Never>?

    init() {
        self.baseURL = UserDefaults.standard.string(forKey: "antigrav_server_url") ?? "http://192.168.1.100:8000"
    }

    private func endpoint(_ path: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        guard let url = URL(string: "\(trimmed)\(path)") else {
            throw URLError(.badURL)
        }
        return url
    }

    func fetchPoses() async {
        do {
            let url = try endpoint("/api/poses")
            let (data, _) = try await URLSession.shared.data(from: url)
            self.availablePoses = try JSONDecoder().decode([PoseInfo].self, from: data)
        } catch {
            self.errorMessage = "Could not load poses: \(error.localizedDescription)"
        }
    }

    func startScrape(request: ScrapeJobRequest) async {
        isLoading = true
        errorMessage = nil
        pollingTask?.cancel()

        do {
            let url = try endpoint("/api/scrape")
            var urlReq = URLRequest(url: url)
            urlReq.httpMethod = "POST"
            urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlReq.httpBody = try JSONEncoder().encode(request)

            let (data, response) = try await URLSession.shared.data(for: urlReq)
            guard let httpResp = response as? HTTPURLResponse, (200..<300).contains(httpResp.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let initialJob = try JSONDecoder().decode(JobDetailResponse.self, from: data)
            self.currentJob = initialJob
            startPolling(jobId: initialJob.id)
        } catch {
            self.isLoading = false
            self.errorMessage = "Failed to start scrape: \(error.localizedDescription)"
        }
    }

    func startPolling(jobId: String) {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await refreshJob(jobId: jobId)
                if let status = currentJob?.status,
                   ["completed", "failed", "cancelled"].contains(status) {
                    isLoading = false
                    break
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
            }
        }
    }

    func refreshJob(jobId: String) async {
        do {
            let url = try endpoint("/api/jobs/\(jobId)")
            let (data, _) = try await URLSession.shared.data(from: url)
            let updated = try JSONDecoder().decode(JobDetailResponse.self, from: data)
            self.currentJob = updated
        } catch {
            self.errorMessage = "Failed to refresh job: \(error.localizedDescription)"
        }
    }

    func reviewResult(resultId: String, action: String, poseName: String? = nil, deleteFile: Bool = false) async {
        do {
            let url = try endpoint("/api/results/\(resultId)/review")
            var urlReq = URLRequest(url: url)
            urlReq.httpMethod = "POST"
            urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = ReviewActionRequest(action: action, poseName: poseName, deleteFile: deleteFile)
            urlReq.httpBody = try JSONEncoder().encode(body)

            let (_, response) = try await URLSession.shared.data(for: urlReq)
            guard let httpResp = response as? HTTPURLResponse, (200..<300).contains(httpResp.statusCode) else {
                throw URLError(.badServerResponse)
            }

            if let jobId = currentJob?.id {
                await refreshJob(jobId: jobId)
            }
        } catch {
            self.errorMessage = "Review action failed: \(error.localizedDescription)"
        }
    }

    func compileJob(jobId: String, poses: String) async -> URL? {
        do {
            let encodedPoses = poses.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? poses
            let url = try endpoint("/api/jobs/\(jobId)/compile?poses=\(encodedPoses)")
            var urlReq = URLRequest(url: url)
            urlReq.httpMethod = "POST"

            let (data, _) = try await URLSession.shared.data(for: urlReq)
            let comp = try JSONDecoder().decode(CompilationResponse.self, from: data)
            await refreshJob(jobId: jobId)
            return URL(string: comp.compilationUrl)
        } catch {
            self.errorMessage = "Compilation failed: \(error.localizedDescription)"
            return nil
        }
    }

    func resolveVideoURL(_ urlOrPath: String) -> URL? {
        if urlOrPath.hasPrefix("http://") || urlOrPath.hasPrefix("https://") {
            return URL(string: urlOrPath)
        }
        return try? endpoint(urlOrPath)
    }

    func downloadVideoToTemp(from remoteURL: URL, filename: String) async throws -> URL {
        let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }
}
