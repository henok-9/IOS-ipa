import SwiftUI

struct ScanView: View {
    @EnvironmentObject var api: AntigravAPIClient

    @State private var username: String = ""
    @State private var selectedPose: String = "turned_around"
    @State private var limit: Double = 15
    @State private var confidence: Double = 0.65
    @State private var sampleInterval: Double = 0.3
    @State private var extractSegments: Bool = true
    @State private var compileVideo: Bool = false
    @State private var autoCleanup: Bool = false
    @State private var showAdvanced: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Active Job Live Card
                    if let job = api.currentJob, api.isScanning || job.status == "running" {
                        ActiveJobBanner(job: job) {
                            Task { await api.cancelJob(id: job.id) }
                        }
                    }

                    // Main Scanner Input Card
                    MaterialCard {
                        Text("Profile Target")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(MaterialTheme.textPrimary)

                        HStack(spacing: 8) {
                            Image(systemName: "at")
                                .foregroundColor(MaterialTheme.textTertiary)
                                .font(.system(size: 16, weight: .semibold))

                            TextField("username or tiktok.com/@profile", text: $username)
                                .font(.system(size: 15))
                                .foregroundColor(MaterialTheme.textPrimary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            if !username.isEmpty {
                                Button {
                                    username = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(MaterialTheme.textTertiary)
                                }
                            } else {
                                Button("Paste") {
                                    if let string = UIPasteboard.general.string {
                                        username = string
                                    }
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(MaterialTheme.surfaceContainerHigh)
                                .foregroundColor(MaterialTheme.textSecondary)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(MaterialTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    // Pose Selector Card
                    MaterialCard {
                        HStack {
                            Text("Target Pose")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(MaterialTheme.textPrimary)
                            Spacer()
                            StatusBadge(text: selectedPose, style: .neutral)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                let poses = api.availablePoses.isEmpty ? defaultPoses : api.availablePoses
                                ForEach(poses) { pose in
                                    MaterialChip(
                                        title: pose.name,
                                        isSelected: selectedPose == pose.name
                                    ) {
                                        selectedPose = pose.name
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        if let desc = currentPoseDescription {
                            Text(desc)
                                .font(.system(size: 13))
                                .foregroundColor(MaterialTheme.textSecondary)
                                .padding(.top, 4)
                        }
                    }

                    // Collapsible Tuning Drawer (Low visual clutter)
                    MaterialCard {
                        DisclosureGroup(isExpanded: $showAdvanced) {
                            VStack(spacing: 16) {
                                Divider().background(MaterialTheme.surfaceContainerHigh)

                                // Video Count
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Max Videos to Scan")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(MaterialTheme.textPrimary)
                                        Spacer()
                                        Text("\(Int(limit))")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(MaterialTheme.primary)
                                    }
                                    Slider(value: $limit, in: 5...50, step: 5)
                                        .tint(MaterialTheme.primary)
                                }

                                // Min Confidence
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Minimum Confidence")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(MaterialTheme.textPrimary)
                                        Spacer()
                                        Text("\(Int(confidence * 100))%")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(MaterialTheme.primary)
                                    }
                                    Slider(value: $confidence, in: 0.5...0.95, step: 0.05)
                                        .tint(MaterialTheme.primary)
                                }

                                // Toggle Options
                                Toggle(isOn: $extractSegments) {
                                    Text("Extract Trimmed Clips")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(MaterialTheme.textPrimary)
                                }
                                .tint(MaterialTheme.primary)

                                Toggle(isOn: $compileVideo) {
                                    Text("Compile Highlights Reel")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(MaterialTheme.textPrimary)
                                }
                                .tint(MaterialTheme.primary)

                                Toggle(isOn: $autoCleanup) {
                                    Text("Auto-Cleanup Unmatched")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(MaterialTheme.textPrimary)
                                }
                                .tint(MaterialTheme.primary)
                            }
                            .padding(.top, 8)
                        } label: {
                            HStack {
                                Label("Advanced Parameters", systemImage: "slider.horizontal.3")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(MaterialTheme.textPrimary)
                                Spacer()
                            }
                        }
                    }

                    // Trigger Scan Button
                    MaterialButton(
                        title: api.isScanning ? "Scanning Profile..." : "Start Profile Scan",
                        icon: "bolt.fill",
                        isPrimary: true,
                        isLoading: api.isScanning
                    ) {
                        triggerScan()
                    }
                    .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty || api.isScanning)
                    .opacity(username.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1.0)

                    if let err = api.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(MaterialTheme.onErrorContainer)
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(MaterialTheme.onErrorContainer)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MaterialTheme.errorContainer)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
            }
            .background(MaterialTheme.surface.ignoresSafeArea())
            .navigationTitle("Scan Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ServerHealthPill()
                }
            }
        }
    }

    private func triggerScan() {
        let req = ScrapeJobRequest(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            poses: selectedPose,
            limit: Int(limit),
            confidence: confidence,
            sampleInterval: sampleInterval,
            modelComplexity: 1,
            extractSegments: extractSegments,
            compileVideo: compileVideo,
            autoCleanupUnmatched: autoCleanup
        )
        Task {
            await api.startScrape(request: req)
        }
    }

    private var currentPoseDescription: String? {
        api.availablePoses.first(where: { $0.name == selectedPose })?.description
    }

    private var defaultPoses: [PoseInfo] {
        [
            PoseInfo(name: "turned_around", description: "Subject facing away from camera", rules: [], matchMode: "all", minConfidence: 0.65, minFrames: 3, priority: 1),
            PoseInfo(name: "standing", description: "Subject standing upright", rules: [], matchMode: "all", minConfidence: 0.65, minFrames: 3, priority: 2),
            PoseInfo(name: "squatting", description: "Deep knee bend position", rules: [], matchMode: "all", minConfidence: 0.65, minFrames: 3, priority: 3),
            PoseInfo(name: "sitting", description: "Subject seated", rules: [], matchMode: "all", minConfidence: 0.65, minFrames: 3, priority: 4),
            PoseInfo(name: "arms_raised", description: "Both arms extended upward", rules: [], matchMode: "all", minConfidence: 0.65, minFrames: 3, priority: 5)
        ]
    }
}

// MARK: - Active Job Live Banner

struct ActiveJobBanner: View {
    let job: JobDetailResponse
    let onCancel: () -> Void

    var body: some View {
        MaterialCard {
            HStack {
                StatusBadge(text: job.status.capitalized, icon: "hourglass", style: .warning)
                Spacer()
                Button("Cancel", action: onCancel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(MaterialTheme.textSecondary)
            }

            Text(job.progressMessage.isEmpty ? "Processing videos..." : job.progressMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(MaterialTheme.textPrimary)

            if job.progressTotal > 0 {
                let progress = min(1.0, Double(job.progressCurrent) / Double(job.progressTotal))
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                        .tint(MaterialTheme.primary)
                    HStack {
                        Text("\(job.progressCurrent) of \(job.progressTotal) videos")
                            .font(.system(size: 12))
                            .foregroundColor(MaterialTheme.textTertiary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(MaterialTheme.primary)
                    }
                }
            }
        }
    }
}

// MARK: - Server Health Pill in Toolbar

struct ServerHealthPill: View {
    @EnvironmentObject var api: AntigravAPIClient

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(api.isServerOnline ? Color(hex: "#2E7D32") : Color(hex: "#C62828"))
                .frame(width: 8, height: 8)

            if let ms = api.serverLatencyMs {
                Text("\(ms)ms")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(MaterialTheme.textSecondary)
            } else {
                Text(api.isServerOnline ? "Online" : "Offline")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(MaterialTheme.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(MaterialTheme.surfaceContainer)
        .clipShape(Capsule())
    }
}
