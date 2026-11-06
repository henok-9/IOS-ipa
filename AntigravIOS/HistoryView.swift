import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var api: AntigravAPIClient
    @State private var inputURL: String = ""
    @State private var showSavedAlert: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Server Diagnostics Card
                    MaterialCard {
                        HStack {
                            Text("Backend Connection")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(MaterialTheme.textPrimary)
                            Spacer()
                            ServerHealthPill()
                        }

                        // Host URL Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Server URL")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(MaterialTheme.textSecondary)

                            HStack(spacing: 8) {
                                TextField("http://192.168.1.100:8000", text: $inputURL)
                                    .font(.system(size: 14))
                                    .foregroundColor(MaterialTheme.textPrimary)
                                    .keyboardType(.URL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()

                                Button("Save") {
                                    api.baseURL = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
                                    Task {
                                        await api.checkServerStatus()
                                        await api.fetchPoses()
                                    }
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(MaterialTheme.primaryContainer)
                                .foregroundColor(MaterialTheme.onPrimaryContainer)
                                .clipShape(Capsule())
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(MaterialTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Server Specs (if online)
                        if let status = api.serverStatus {
                            Divider().background(MaterialTheme.surfaceContainerHigh)
                            HStack(spacing: 16) {
                                StatSnippet(title: "Version", value: "v\(status.version)")
                                if let disk = status.diskFreeGb {
                                    StatSnippet(title: "Disk Free", value: "\(disk) GB")
                                }
                                if let cpu = status.cpuCount {
                                    StatSnippet(title: "CPU Threads", value: "\(cpu)")
                                }
                            }
                        }
                    }

                    // Jobs History Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Past Activity")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(MaterialTheme.textPrimary)
                            Spacer()
                            Text("\(api.recentJobs.count) jobs")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(MaterialTheme.textSecondary)
                        }

                        if api.isLoadingJobs && api.recentJobs.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if api.recentJobs.isEmpty {
                            MaterialCard {
                                Text("No past jobs recorded yet.")
                                    .font(.system(size: 14))
                                    .foregroundColor(MaterialTheme.textSecondary)
                            }
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(api.recentJobs) { job in
                                    JobHistoryCard(job: job)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(MaterialTheme.surface.ignoresSafeArea())
            .navigationTitle("History & Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                inputURL = api.baseURL
            }
            .refreshable {
                await api.checkServerStatus()
                await api.fetchJobs()
            }
            .task {
                await api.checkServerStatus()
                await api.fetchJobs()
            }
        }
    }
}

// MARK: - Job History Card

struct JobHistoryCard: View {
    @EnvironmentObject var api: AntigravAPIClient
    let job: JobListItem

    var body: some View {
        MaterialCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(job.jobType.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(MaterialTheme.textTertiary)
                        Text(formattedDate(job.createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(MaterialTheme.textSecondary)
                    }

                    if let msg = job.progressMessage, !msg.isEmpty {
                        Text(msg)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(MaterialTheme.textPrimary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                StatusBadge(text: job.status.capitalized, style: statusStyle)
            }

            if let cur = job.progressCurrent, let tot = job.progressTotal, tot > 0 {
                HStack {
                    Text("Processed \(cur) of \(tot) videos")
                        .font(.system(size: 12))
                        .foregroundColor(MaterialTheme.textTertiary)
                    Spacer()
                }
            }

            if job.status == "running" {
                Button("Cancel Job") {
                    Task { await api.cancelJob(id: job.id) }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(MaterialTheme.onErrorContainer)
            }
        }
    }

    private var statusStyle: StatusBadge.BadgeStyle {
        switch job.status.lowercased() {
        case "completed": return .success
        case "running", "pending": return .warning
        case "failed", "cancelled": return .error
        default: return .neutral
        }
    }

    private func formattedDate(_ raw: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) else {
            return raw
        }
        let display = DateFormatter()
        display.dateStyle = .short
        display.timeStyle = .short
        return display.string(from: date)
    }
}

// MARK: - Stat Snippet

struct StatSnippet: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(MaterialTheme.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(MaterialTheme.textPrimary)
        }
    }
}
