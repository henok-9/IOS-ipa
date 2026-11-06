import SwiftUI
import AVKit

struct ReviewView: View {
    @EnvironmentObject var api: AntigravAPIClient

    var body: some View {
        NavigationStack {
            Group {
                if api.isLoadingReview && api.reviewQueue.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView().tint(MaterialTheme.primary)
                        Text("Loading review items...")
                            .font(.system(size: 14))
                            .foregroundColor(MaterialTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if api.reviewQueue.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 44))
                            .foregroundColor(MaterialTheme.textTertiary)
                        Text("Queue Clear")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(MaterialTheme.textPrimary)
                        Text("No borderline videos currently waiting for review.")
                            .font(.system(size: 14))
                            .foregroundColor(MaterialTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(api.reviewQueue) { item in
                                ReviewItemCard(item: item)
                            }
                        }
                        .padding(16)
                    }
                    .refreshable {
                        await api.fetchReviewQueue()
                    }
                }
            }
            .background(MaterialTheme.surface.ignoresSafeArea())
            .navigationTitle("Review Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(api.reviewQueue.count) pending")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(MaterialTheme.textSecondary)
                }
            }
            .task {
                await api.fetchReviewQueue()
            }
        }
    }
}

// MARK: - Review Item Card

struct ReviewItemCard: View {
    @EnvironmentObject var api: AntigravAPIClient
    let item: VideoAnalysisItem

    @State private var selectedPose: String
    @State private var player: AVPlayer?
    @State private var isProcessing: Bool = false

    init(item: VideoAnalysisItem) {
        self.item = item
        _selectedPose = State(initialValue: item.closestPose ?? item.detectedPose)
    }

    var body: some View {
        MaterialCard {
            // Header Info
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.filename)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(MaterialTheme.textPrimary)
                        .lineLimit(1)

                    if let reason = item.reviewReason, !reason.isEmpty {
                        Text(reason)
                            .font(.system(size: 12))
                            .foregroundColor(MaterialTheme.onWarningContainer)
                    }
                }
                Spacer()
                StatusBadge(text: "Borderline", style: .warning)
            }

            // Inline Video Player Preview
            if let videoURL = api.resolveVideoURL(item.videoDownloadUrl) {
                VStack(spacing: 8) {
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

                    if let timestamp = item.bestTimestampSec, timestamp > 0 {
                        Button {
                            let target = CMTime(seconds: timestamp, preferredTimescale: 600)
                            player?.seek(to: target)
                            player?.play()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "forward.frame.fill")
                                Text(String(format: "Jump to Pose Moment (%.1fs)", timestamp))
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(MaterialTheme.onPrimaryContainer)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(MaterialTheme.primaryContainer)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // Pose Reclassification Picker
            HStack {
                Text("Assign Pose:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MaterialTheme.textSecondary)

                Spacer()

                Menu {
                    let poses = api.availablePoses.isEmpty ? defaultPoses : api.availablePoses.map { $0.name }
                    ForEach(poses, id: \.self) { pose in
                        Button(pose) { selectedPose = pose }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedPose)
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(MaterialTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MaterialTheme.surfaceContainerHigh)
                    .clipShape(Capsule())
                }
            }
            .padding(.top, 4)

            Divider().background(MaterialTheme.surfaceContainerHigh)

            // Decision Buttons
            HStack(spacing: 12) {
                Button {
                    Task {
                        isProcessing = true
                        await api.reviewResult(resultId: item.id, action: "approve", poseName: selectedPose)
                        isProcessing = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text("Approve")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(MaterialTheme.successContainer)
                    .foregroundColor(MaterialTheme.onSuccessContainer)
                    .clipShape(Capsule())
                }
                .disabled(isProcessing)

                Button {
                    Task {
                        isProcessing = true
                        await api.reviewResult(resultId: item.id, action: "reject", deleteFile: true)
                        isProcessing = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                        Text("Reject & Delete")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(MaterialTheme.surfaceContainerHigh)
                    .foregroundColor(MaterialTheme.textSecondary)
                    .clipShape(Capsule())
                }
                .disabled(isProcessing)
            }
        }
    }

    private var defaultPoses: [String] {
        ["turned_around", "standing", "squatting", "sitting", "arms_raised", "bending_forward", "t_pose"]
    }
}
