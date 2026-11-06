import SwiftUI
import AVKit

struct LibraryView: View {
    @EnvironmentObject var api: AntigravAPIClient
    @State private var selectedPoseFilter: String = "All"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Chips Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        MaterialChip(
                            title: "All Poses",
                            isSelected: selectedPoseFilter == "All"
                        ) {
                            selectedPoseFilter = "All"
                            loadLibrary()
                        }

                        let poses = api.availablePoses.isEmpty ? defaultPoses : api.availablePoses.map { $0.name }
                        ForEach(poses, id: \.self) { pose in
                            MaterialChip(
                                title: pose,
                                isSelected: selectedPoseFilter == pose
                            ) {
                                selectedPoseFilter = pose
                                loadLibrary()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(MaterialTheme.surface)

                Divider().background(MaterialTheme.surfaceContainerHigh)

                // Results Content
                Group {
                    if api.isLoadingLibrary && api.libraryResults.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView().tint(MaterialTheme.primary)
                            Text("Loading library...")
                                .font(.system(size: 14))
                                .foregroundColor(MaterialTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if api.libraryResults.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "video.slash")
                                .font(.system(size: 40))
                                .foregroundColor(MaterialTheme.textTertiary)
                            Text("No Videos Found")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(MaterialTheme.textPrimary)
                            Text("Run a scan or approve items in the Review tab to populate the library.")
                                .font(.system(size: 13))
                                .foregroundColor(MaterialTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(api.libraryResults) { item in
                                    LibraryItemCard(item: item)
                                }
                            }
                            .padding(16)
                        }
                        .refreshable {
                            loadLibrary()
                        }
                    }
                }
            }
            .background(MaterialTheme.surface.ignoresSafeArea())
            .navigationTitle("Pose Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(api.libraryTotal) total")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(MaterialTheme.textSecondary)
                }
            }
            .task {
                loadLibrary()
            }
        }
    }

    private func loadLibrary() {
        Task {
            await api.fetchLibraryResults(
                pose: selectedPoseFilter == "All" ? nil : selectedPoseFilter,
                matchStatus: "matched"
            )
        }
    }

    private var defaultPoses: [String] {
        ["turned_around", "standing", "squatting", "sitting", "arms_raised", "bending_forward", "t_pose"]
    }
}

// MARK: - Library Item Card

struct LibraryItemCard: View {
    @EnvironmentObject var api: AntigravAPIClient
    let item: VideoAnalysisItem

    @State private var player: AVPlayer?
    @State private var downloadedURL: URL?
    @State private var isDownloading: Bool = false
    @State private var showSegments: Bool = false

    var body: some View {
        MaterialCard {
            // Header Info
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.filename)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(MaterialTheme.textPrimary)
                        .lineLimit(1)

                    if let desc = item.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundColor(MaterialTheme.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                StatusBadge(text: item.detectedPose, icon: "checkmark", style: .success)
            }

            // Inline Player
            if let videoURL = api.resolveVideoURL(item.videoDownloadUrl) {
                VideoPlayer(player: player)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onAppear {
                        if player == nil {
                            player = AVPlayer(url: videoURL)
                        }
                    }
                    .onDisappear {
                        player?.pause()
                        player = nil
                    }
            }

            // Segments Accordion if available
            if let segments = item.segments, !segments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSegments.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "scissors")
                                .font(.system(size: 12))
                            Text("Extracted Clips (\(segments.count))")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Image(systemName: showSegments ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(MaterialTheme.textSecondary)
                        .padding(.vertical, 4)
                    }

                    if showSegments {
                        VStack(spacing: 6) {
                            ForEach(Array(segments.enumerated()), id: \.offset) { index, seg in
                                HStack {
                                    Text(String(format: "%.1fs – %.1fs", seg.start, seg.end))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(MaterialTheme.textPrimary)
                                    Spacer()
                                    if let segURL = api.resolveVideoURL(seg.segmentDownloadUrl) {
                                        ShareLink(item: segURL) {
                                            Label("Share Clip", systemImage: "square.and.arrow.up")
                                                .font(.system(size: 11, weight: .semibold))
                                        }
                                        .foregroundColor(MaterialTheme.onPrimaryContainer)
                                    }
                                }
                                .padding(8)
                                .background(MaterialTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }

            Divider().background(MaterialTheme.surfaceContainerHigh)

            // Actions Row
            HStack(spacing: 12) {
                if let rawURL = item.tiktokUrl, let ttURL = URL(string: rawURL) {
                    Link(destination: ttURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right")
                            Text("TikTok")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(MaterialTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(MaterialTheme.surfaceContainerHigh)
                        .clipShape(Capsule())
                    }
                }

                Spacer()

                if let local = downloadedURL {
                    ShareLink(item: local) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Save / Share")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(MaterialTheme.onPrimaryContainer)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(MaterialTheme.primaryContainer)
                        .clipShape(Capsule())
                    }
                } else if let remoteURL = api.resolveVideoURL(item.videoDownloadUrl) {
                    Button {
                        Task {
                            isDownloading = true
                            downloadedURL = try? await api.downloadVideoToTemp(from: remoteURL, filename: item.filename)
                            isDownloading = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isDownloading {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.down.circle")
                            }
                            Text(isDownloading ? "Downloading..." : "Download MP4")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(MaterialTheme.onPrimaryContainer)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(MaterialTheme.primaryContainer)
                        .clipShape(Capsule())
                    }
                    .disabled(isDownloading)
                }
            }
        }
    }
}
