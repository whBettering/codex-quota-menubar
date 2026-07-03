import AppKit
import CodexQuotaCore
import SwiftUI

@main
@MainActor
enum CodexQuotaMenuBarMain {
    private static let runtime = AppRuntime()

    static func main() {
        if CommandLine.arguments.contains("--print-quota") {
            Self.printQuotaAndExit()
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        ProcessInfo.processInfo.disableAutomaticTermination("Codex quota menu bar stays visible")

        DispatchQueue.main.async {
            runtime.start()
        }

        app.run()
    }

    private static func printQuotaAndExit() -> Never {
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
}

@MainActor
final class AppRuntime {
    private var quotaStore: QuotaStore?
    private var statusItemController: StatusItemController?

    func start() {
        let store = QuotaStore(fetcher: CodexAppServerClient())
        let controller = StatusItemController(store: store)

        quotaStore = store
        statusItemController = controller

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
    private var hasStarted = false
    var onDisplayChange: (@MainActor () -> Void)?

    init(fetcher: QuotaFetching) {
        self.fetcher = fetcher
    }

    func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true
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
        hasStarted = false
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
                self.onDisplayChange?()
            } catch {
                self.errorMessage = String(describing: error)
                self.lastRefresh = Date()
                self.onDisplayChange?()
            }
        }
    }
}

@MainActor
final class StatusItemController: NSObject {
    private let store: QuotaStore
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let contextMenu: NSMenu

    init(store: QuotaStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        contextMenu = NSMenu()

        super.init()

        configureStatusItem()
        configurePopover()
        configureContextMenu()

        store.onDisplayChange = { [weak self] in
            self?.updateTitle()
        }
        updateTitle()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Codex 剩余额度"
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 180)
        popover.contentViewController = NSHostingController(rootView: QuotaPopoverView(store: store))
    }

    private func configureContextMenu() {
        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        contextMenu.addItem(quitItem)
    }

    private func updateTitle() {
        statusItem.button?.title = QuotaFormatting.menuBarTitle(for: store.snapshot)
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true)

        switch MenuBarClickRoute.route(isRightClick: isRightClick) {
        case .togglePopover:
            togglePopover(sender)
        case .showContextMenu:
            showContextMenu(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        popover.performClose(sender)
        statusItem.menu = contextMenu
        sender.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

struct QuotaPopoverView: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            header

            if let snapshot = store.snapshot {
                quotaRow(snapshot.primary, accent: .green)
                quotaRow(snapshot.secondary, accent: .mint)
                footer(for: snapshot)
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
        .frame(width: 360, alignment: .topLeading)
    }

    private var header: some View {
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
    }

    private var unavailableView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Codex --")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text(store.isRefreshing ? "正在读取额度..." : "暂时无法读取额度")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
    }

    private func footer(for snapshot: QuotaSnapshot) -> some View {
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
    }

    private func quotaRow(_ window: QuotaWindow?, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(QuotaFormatting.windowLabel(durationMinutes: window?.durationMinutes))
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(window.map { "剩余 \(QuotaFormatting.remainingPercent(for: $0))%" } ?? "剩余 --")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(QuotaFormatting.resetText(for: window?.resetsAt))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .trailing)
            }

            progressBar(percent: window.map { QuotaFormatting.remainingPercent(for: $0) } ?? 0, accent: accent)
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
