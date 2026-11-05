import SwiftUI
import AVKit

struct ContentView: View {
    @EnvironmentObject var api: AntigravAPIClient

    @State private var username: String = ""
    @State private var selectedPose: String = "turned_around"
    @State private var limit: Int = 20
    @State private var extractSegments: Bool = true
    @State private var compileVideo: Bool = false
    @State private var autoCleanupUnmatched: Bool = false
    @State private var selectedTab: Int = 0
    @State private var showingSettings: Bool = false

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                ScanProfileView(
                    username: $username,
                    selectedPose: $selectedPose,
                    limit: $limit,
                    extractSegments: $extractSegments,
                    compileVideo: $compileVideo,
                    autoCleanupUnmatched: $autoCleanupUnmatched
                )
                .tabItem {
                    Label("Scan Profile", systemImage: "person.crop.rectangle.badge.plus")
                }
                .tag(0)

                MatchedVideosView(selectedPose: selectedPose)
                    .tabItem {
                        Label("Matched", systemImage: "checkmark.seal.fill")
                    }
                    .badge(api.currentJob?.summary?.matchedCount ?? 0)
                    .tag(1)

                ReviewQueueView()
                    .tabItem {
                        Label("Review Close", systemImage: "eye.trianglebadge.exclamationmark")
                    }
                    .badge(api.currentJob?.summary?.reviewQueueCount ?? 0)
                    .tag(2)
            }
            .navigationTitle("Antigrav iOS")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                ServerSettingsSheet()
            }
            .task {
                await api.fetchPoses()
            }
        }
    }
}

// MARK: - Tab 1: Scan Profile Workflow

struct ScanProfileView: View {
    @EnvironmentObject var api: AntigravAPIClient

    @Binding var username: String
    @Binding var selectedPose: String
    @Binding var limit: Int
    @Binding var extractSegments: Bool
    @Binding var compileVideo: Bool
    @Binding var autoCleanupUnmatched: Bool

    var body: some View {
        Form {
            Section("TikTok Profile & Pose") {
                TextField("Username or TikTok URL (e.g. @user)", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Picker("Target Pose", selection: $selectedPose) {
                    if api.availablePoses.isEmpty {
                        Text("turned_around").tag("turned_around")
                        Text("standing").tag("standing")
                        Text("squatting").tag("squatting")
                        Text("sitting").tag("sitting")
                        Text("arms_raised").tag("arms_raised")
                        Text("bending_forward").tag("bending_forward")
                        Text("t_pose").tag("t_pose")
                    } else {
                        ForEach(api.availablePoses) { pose in
                            Text(pose.name).tag(pose.name)
                        }
                    }
                }

                Stepper("Max Videos: \(limit == 0 ? "All" : "\(limit)")", value: $limit, in: 0...200, step: 5)
            }

            Section("Processing Options") {
                Toggle("Extract Pose Segments (FFmpeg)", isOn: $extractSegments)
                Toggle("Build Highlight Compilation", isOn: $compileVideo)
                Toggle("Auto-Delete Clearly Unmatched Videos", isOn: $autoCleanupUnmatched)
            }

            Section {
                Button {
                    let req = ScrapeJobRequest(
                        username: username,
                        poses: selectedPose,
                        limit: limit,
                        confidence: 0.52,
                        sampleInterval: 0.1,
                        modelComplexity: 1,
                        extractSegments: extractSegments,
                        compileVideo: compileVideo,
                        autoCleanupUnmatched: autoCleanupUnmatched
                    )
                    Task {
                        await api.startScrape(request: req)
                    }
                } label: {
                    HStack {
                        Spacer()
                        if api.isLoading {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Running Pipeline...")
                        } else {
                            Label("Fetch & Analyze Profile", systemImage: "play.fill")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty || api.isLoading)
            }

            if let job = api.currentJob {
                Section("Job Status (\(job.status.capitalized))") {
                    Text(job.progressMessage.isEmpty ? "Processing..." : job.progressMessage)
                        .font(.subheadline)
                    if job.progressTotal > 0 {
                        ProgressView(
                            value: Double(job.progressCurrent),
                            total: Double(job.progressTotal)
                        )
                    }
                    if let summary = job.summary {
                        HStack {
                            StatPill(title: "Matched", count: summary.matchedCount, color: .green)
                            StatPill(title: "Review", count: summary.reviewQueueCount, color: .orange)
                            StatPill(title: "Other", count: summary.unclassifiedCount, color: .secondary)
                        }
                    }
                }
            }

            if let err = api.errorMessage {
                Section("Error") {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
    }
}

struct StatPill: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack {
            Text("\(count)")
                .font(.headline)
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Tab 2: Matched Videos

struct MatchedVideosView: View {
    @EnvironmentObject var api: AntigravAPIClient
    let selectedPose: String
    @State private var copiedToast: Bool = false

    var matchedItems: [VideoAnalysisItem] {
        api.currentJob?.matched ?? []
    }

    var body: some View {
        List {
            if let urls = api.currentJob?.matchedTiktokUrls, !urls.isEmpty {
                Section("Quick Actions") {
                    Button {
                        UIPasteboard.general.string = urls.joined(separator: "\n")
                        copiedToast = true
                    } label: {
                        Label(
                            copiedToast ? "Copied \(urls.count) TikTok URLs!" : "Copy All Matched TikTok URLs (\(urls.count))",
                            systemImage: "doc.on.doc"
                        )
                    }

                    if let compUrlStr = api.currentJob?.compilationUrl,
                       let compURL = api.resolveVideoURL(compUrlStr) {
                        Link(destination: compURL) {
                            Label("Download Highlight Compilation MP4", systemImage: "film.stack")
                        }
                    } else if let jobId = api.currentJob?.id {
                        Button {
                            Task {
                                _ = await api.compileJob(jobId: jobId, poses: selectedPose)
                            }
                        } label: {
                            Label("Build Highlight Compilation MP4", systemImage: "wand.and.stars")
                        }
                    }
                }
            }

            Section("Matched Videos (\(matchedItems.count))") {
                if matchedItems.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView(
                            "No Matched Videos Yet",
                            systemImage: "video.slash",
                            description: Text("Run a profile scan or approve close matches from the Review tab.")
                        )
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "video.slash")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("No Matched Videos Yet")
                                .font(.headline)
                            Text("Run a profile scan or approve close matches from the Review tab.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                    }
                } else {
                    ForEach(matchedItems) { item in
                        VideoResultCard(item: item, isReviewMode: false)
                    }
                }
            }
        }
    }
}

// MARK: - Tab 3: Review Queue (Close Matches)

struct ReviewQueueView: View {
    @EnvironmentObject var api: AntigravAPIClient

    var reviewItems: [VideoAnalysisItem] {
        api.currentJob?.reviewQueue ?? []
    }

    var body: some View {
        List {
            Section {
                if reviewItems.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView(
                            "Review Queue Empty",
                            systemImage: "checkmark.circle",
                            description: Text("No borderline close-match videos waiting for review.")
                        )
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("Review Queue Empty")
                                .font(.headline)
                            Text("No borderline close-match videos waiting for review.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                    }
                } else {
                    ForEach(reviewItems) { item in
                        VideoResultCard(item: item, isReviewMode: true)
                    }
                }
            } header: {
                Text("Borderline Matches (\(reviewItems.count))")
            } footer: {
                Text("Videos in this list came close to the pose threshold. Preview at the highlighted timestamp and tap Approve to keep or Reject to discard.")
            }
        }
    }
}

// MARK: - Video Result Card (Shared between Matched & Review Queue)

struct VideoResultCard: View {
    @EnvironmentObject var api: AntigravAPIClient
    let item: VideoAnalysisItem
    let isReviewMode: Bool

    @State private var player: AVPlayer?
    @State private var downloadedFileURL: URL?
    @State private var isDownloading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.videoId.isEmpty ? item.filename : "Video #\(item.videoId)")
                    .font(.headline)
                Spacer()
                if isReviewMode {
                    Text("\(Int(item.closenessScore * 100))% Close")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                } else {
                    Text(item.detectedPose)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }

            if isReviewMode && !item.reviewReason.isEmpty {
                Label(
                    "\(item.reviewReason) (peak @ \(String(format: "%.1fs", item.bestTimestampSec)))",
                    systemImage: "sparkle.magnifyingglass"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            if let videoURL = api.resolveVideoURL(item.videoDownloadUrl) {
                VideoPlayer(player: player)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onAppear {
                        if player == nil {
                            let avPlayer = AVPlayer(url: videoURL)
                            if item.bestTimestampSec > 0 {
                                let target = CMTime(seconds: item.bestTimestampSec, preferredTimescale: 600)
                                avPlayer.seek(to: target)
                            }
                            player = avPlayer
                        }
                    }
            }

            HStack(spacing: 12) {
                if !item.tiktokUrl.isEmpty, let ttURL = URL(string: item.tiktokUrl) {
                    Link(destination: ttURL) {
                        Label("TikTok", systemImage: "arrow.up.right.square")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                }

                if let localURL = downloadedFileURL {
                    ShareLink(item: localURL) {
                        Label("Save Video", systemImage: "square.and.arrow.up")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                } else if let remoteURL = api.resolveVideoURL(item.videoDownloadUrl) {
                    Button {
                        Task {
                            isDownloading = true
                            downloadedFileURL = try? await api.downloadVideoToTemp(
                                from: remoteURL,
                                filename: item.filename
                            )
                            isDownloading = false
                        }
                    } label: {
                        Label(
                            isDownloading ? "Downloading..." : "Download MP4",
                            systemImage: "arrow.down.circle"
                        )
                        .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .disabled(isDownloading)
                }
            }

            if isReviewMode {
                Divider()
                HStack(spacing: 16) {
                    Button {
                        Task {
                            await api.reviewResult(
                                resultId: item.id,
                                action: "approve",
                                poseName: item.closestPose
                            )
                        }
                    } label: {
                        Label("Approve Match", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button(role: .destructive) {
                        Task {
                            await api.reviewResult(
                                resultId: item.id,
                                action: "reject",
                                deleteFile: true
                            )
                        }
                    } label: {
                        Label("Reject", systemImage: "xmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Server Settings Sheet

struct ServerSettingsSheet: View {
    @EnvironmentObject var api: AntigravAPIClient
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Headless Backend URL") {
                    TextField("http://192.168.1.100:8000", text: $api.baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Button("Reload Poses from Server") {
                        Task {
                            await api.fetchPoses()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Server Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
