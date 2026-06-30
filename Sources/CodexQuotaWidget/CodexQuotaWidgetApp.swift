import AppKit
import CodexQuotaCore
import SwiftUI

@main
@MainActor
enum CodexQuotaWidgetMain {
    private static let runtime = AppRuntime()

    static func main() {
        if CommandLine.arguments.contains("--print-quota") {
            Task {
                do {
                    let snapshot = try await CodexAppServerClient().fetchQuota()
                    print(QuotaFormatting.compactText(for: snapshot))
                    exit(0)
                } catch {
                    fputs("\(error)\n", stderr)
                    exit(1)
                }
            }
            dispatchMain()
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        ProcessInfo.processInfo.disableAutomaticTermination("Codex quota widget stays visible")

        DispatchQueue.main.async {
            runtime.start()
        }

        app.run()
    }
}

@MainActor
final class AppRuntime {
    private var panelController: FloatingPanelController?
    private var quotaStore: QuotaStore?

    func start() {
        let store = QuotaStore(fetcher: CodexAppServerClient())
        let controller = FloatingPanelController(store: store)

        quotaStore = store
        panelController = controller

        controller.show()
        store.start()
    }
}

@MainActor
final class QuotaStore: ObservableObject {
    @Published private(set) var snapshot: QuotaSnapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastRefresh: Date?

    private let fetcher: QuotaFetching
    private var timer: Timer?

    init(fetcher: QuotaFetching) {
        self.fetcher = fetcher
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            defer {
                self.isRefreshing = false
            }

            do {
                let snapshot = try await self.fetcher.fetchQuota()
                self.snapshot = snapshot
                self.errorMessage = nil
                self.lastRefresh = Date()
            } catch {
                self.errorMessage = String(describing: error)
                self.lastRefresh = Date()
            }
        }
    }
}

@MainActor
final class FloatingPanelController {
    private let compactSize = CGSize(width: 206, height: 34)
    private let expandedSize = CGSize(width: 360, height: 172)
    private let panel: NSPanel
    private var hostingController: NSHostingController<QuotaView>?

    init(store: QuotaStore) {
        panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: compactSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isOpaque = false
        panel.level = .statusBar
        panel.titleVisibility = .hidden

        let rootView = QuotaView(store: store) { [weak self] isExpanded in
            self?.setExpanded(isExpanded)
        }
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.view.frame = CGRect(origin: .zero, size: compactSize)
        hostingController.view.autoresizingMask = [.width, .height]
        self.hostingController = hostingController
        panel.contentView = hostingController.view

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show() {
        panel.setFrame(frame(for: compactSize), display: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func setExpanded(_ isExpanded: Bool) {
        let size = isExpanded ? expandedSize : compactSize
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame(for: size), display: true)
        }
    }

    @objc private func screenParametersDidChange() {
        panel.setFrame(frame(for: panel.frame.size), display: true)
    }

    private func frame(for size: CGSize) -> CGRect {
        let screen = NSScreen.screens.first { $0.frame.origin == .zero }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? .zero
        let origin = CGPoint(
            x: visibleFrame.midX - (size.width / 2),
            y: visibleFrame.maxY - size.height - 5
        )
        return CGRect(origin: origin, size: size)
    }
}

struct QuotaView: View {
    @ObservedObject var store: QuotaStore

    let onExpansionChange: @MainActor @Sendable (Bool) -> Void

    @State private var isExpanded = false
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .top) {
            if isExpanded {
                expandedCard
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            } else {
                compactPill
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .frame(width: isExpanded ? 360 : 206, height: isExpanded ? 172 : 34, alignment: .top)
        .onHover(perform: handleHover)
    }

    private var compactPill: some View {
        HStack(spacing: 8) {
            Text(QuotaFormatting.compactText(for: store.snapshot))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)

            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.55)
                    .frame(width: 12, height: 12)
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 13)
        .frame(width: 206, height: 34)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 8)
    }

    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Text("Codex")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                if let plan = store.snapshot?.planType {
                    Text(plan.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.10), in: Capsule())
                }

                Spacer()

                Button(action: store.refresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(store.isRefreshing)
                .help("刷新额度")

                Button(action: { NSApp.terminate(nil) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help("退出")
            }

            if let snapshot = store.snapshot {
                quotaRow(snapshot.primary, accent: .green)
                quotaRow(snapshot.secondary, accent: .mint)

                HStack {
                    Text(metaText(for: snapshot))
                    Spacer()
                    if store.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.55)
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            } else {
                unavailableView
            }

            if let error = store.errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 360, height: 172, alignment: .top)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
    }

    private var unavailableView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Codex --")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text(store.isRefreshing ? "正在读取额度..." : "暂时无法读取额度")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func quotaRow(_ window: QuotaWindow?, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(QuotaFormatting.windowLabel(durationMinutes: window?.durationMinutes))
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(window.map { "\($0.usedPercent)%" } ?? "--")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(QuotaFormatting.resetText(for: window?.resetsAt))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .trailing)
            }

            progressBar(percent: window?.usedPercent ?? 0, accent: accent)
        }
    }

    private func progressBar(percent: Int, accent: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.14))
                Capsule()
                    .fill(accent)
                    .frame(width: proxy.size.width * CGFloat(max(0, min(percent, 100))) / 100)
            }
        }
        .frame(height: 6)
    }

    private func handleHover(_ hovering: Bool) {
        isHovering = hovering

        if hovering {
            setExpanded(true)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if !isHovering {
                setExpanded(false)
            }
        }
    }

    private func setExpanded(_ value: Bool) {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
            isExpanded = value
        }
        onExpansionChange(value)
    }

    private func metaText(for snapshot: QuotaSnapshot) -> String {
        var parts: [String] = []

        if let credits = snapshot.resetCreditsAvailable {
            parts.append("重置 \(credits)")
        }

        let refreshDate = store.lastRefresh ?? snapshot.fetchedAt
        parts.append("更新 \(Self.timeFormatter.string(from: refreshDate))")
        return parts.joined(separator: " · ")
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}
