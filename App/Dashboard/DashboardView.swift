import SwiftUI

enum DashboardPage: String, CaseIterable, Identifiable {
    case overview
    case control
    case history
    case logs
    case settings

    var id: Self { self }
    var title: String {
        switch self {
        case .overview: String(localized: "Overview")
        case .control: String(localized: "Control")
        case .history: String(localized: "History")
        case .logs: String(localized: "Logs")
        case .settings: String(localized: "Settings")
        }
    }
    var symbol: String {
        switch self {
        case .overview: "battery.75percent"
        case .control: "slider.horizontal.3"
        case .history: "chart.xyaxis.line"
        case .logs: "list.bullet.rectangle"
        case .settings: "gearshape"
        }
    }
    var shortcut: Character { Character("\((Self.allCases.firstIndex(of: self) ?? 0) + 1)") }
}

struct DashboardView: View {
    let model: AppModel
    @SceneStorage("page") private var page = DashboardPage.overview
    @SceneStorage("historyRange") private var historyRange = HistoryRange.sixHours

    init(model: AppModel, initialPage: DashboardPage = .overview) {
        self.model = model
        _page = SceneStorage(wrappedValue: initialPage, "page")
    }

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(model: model, page: $page)
            VStack(alignment: .leading, spacing: 0) {
                toolbar
                NoticeStack(model: model, includeService: page == .overview)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(page)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background {
            ZStack {
                Theme.window
                RadialGradient(
                    colors: [Color.white.opacity(0.03), .clear], center: UnitPoint(x: 0.7, y: -0.1), startRadius: 0,
                    endRadius: 700)
                Grain()
            }
            .ignoresSafeArea()
        }
        .frame(minWidth: 980, minHeight: 680)
        .tint(Theme.accent)
        .ignoresSafeArea(edges: .top)
        .onAppear { Dashboard.show() }
        .onDisappear { Dashboard.didClose() }
        .onOpenURL { url in
            // chargectl://dashboard/<page>
            if let target = DashboardPage(rawValue: url.lastPathComponent) { page = target }
        }
    }

    private var toolbar: some View {
        ZStack {
            HStack {
                Text(page.title).font(.system(size: 15, weight: .semibold))
                Spacer()
                trailing
            }
            StatusIsland(model: model, details: islandDetails)
        }
        .padding(.horizontal, 24)
        .frame(height: 56)
        .padding(.top, 4)
        .zIndex(2)
    }

    @ViewBuilder private var trailing: some View {
        switch page {
        case .history:
            SlidingSegments(options: HistoryRange.allCases.map { ($0, $0.rawValue) }, selection: $historyRange)
                .opacity(model.service == .running ? 1 : 0)
        case .logs:
            LivePill(isLive: model.service == .running)
        case .control, .settings:
            Text("Saved as you change them").font(.system(size: 12)).foregroundStyle(.tertiary)
        case .overview:
            if model.service == .running {
                HStack(spacing: 6) {
                    Circle().fill(Theme.accent).frame(width: 6, height: 6).shadow(color: Theme.glow, radius: 3)
                    Text(String(localized: "Live")).font(.system(size: 12)).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var islandDetails: [(String, String)] {
        guard let settings = model.settings else {
            return [
                (
                    String(localized: "Helper"),
                    model.service == .running ? String(localized: "running") : String(localized: "not running")
                )
            ]
        }
        var items: [(String, String)] = [
            (String(localized: "Limit"), "\(settings.limit)%"),
            (
                String(localized: "Sails"),
                settings.sailing == 0 ? String(localized: "off") : "\(settings.lowerBound)–\(settings.limit)%"
            ),
            (String(localized: "Helper"), String(localized: "running")),
        ]
        if let estimate = model.estimate, let minutes = estimate.minutes {
            items.append((String(localized: "Est."), TimeText.minutes(minutes)))
        } else {
            items.append(("macOS", model.macOSLimit.map { "\($0)%" } ?? String(localized: "off")))
        }
        return items
    }

    @ViewBuilder private var content: some View {
        switch page {
        case .overview: OverviewPage(model: model)
        case .control: ControlPage(model: model)
        case .history: HistoryPage(model: model, range: historyRange)
        case .logs: LogsPage(model: model)
        case .settings: SettingsPage(model: model)
        }
    }
}

// MARK: Sidebar

private struct Sidebar: View {
    let model: AppModel
    @Binding var page: DashboardPage
    @State private var hovered: DashboardPage?
    @Namespace private var namespace

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 9) {
                ChargeRing(fraction: Double(model.battery?.percent ?? 0) / 100, lineWidth: 2.6)
                    .frame(width: 20, height: 20)
                Text("Chargectl").font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 16)
            ForEach(DashboardPage.allCases) { item in
                row(item)
            }
            Spacer()
            HelperFooter(model: model)
        }
        .padding(.top, 54)
        .padding(.bottom, 14)
        .padding(.horizontal, 12)
        .frame(width: 222)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial.opacity(0.35))
        .background(Color.primary.opacity(0.02))
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.line).frame(width: 1) }
    }

    private func row(_ item: DashboardPage) -> some View {
        let selected = item == page
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { page = item }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(selected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
                    .shadow(color: selected ? Theme.glow : .clear, radius: 4)
                    .frame(width: 18)
                Text(item.title).font(.system(size: 13))
                Spacer()
                Text("⌘\(String(item.shortcut))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .opacity(hovered == item ? 1 : 0)
            }
            .foregroundStyle(selected ? .primary : .secondary)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.line))
                        .matchedGeometryEffect(id: "selection", in: namespace)
                } else if hovered == item {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.hover)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? item : (hovered == item ? nil : hovered) }
        .keyboardShortcut(KeyEquivalent(item.shortcut))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Sidebar footer: whether the helper runs and whether it controls charging.
private struct HelperFooter: View {
    let model: AppModel

    var body: some View {
        let (title, detail, ok): (String, String, Bool) =
            switch model.service {
            case .running:
                (
                    String(localized: "Helper running"),
                    model.settings.map {
                        $0.isEnabled ? String(localized: "Charge control on") : String(localized: "Charge control off")
                    }
                        ?? String(localized: "Reading settings"),
                    model.settings?.isEnabled != false
                )
            case .checking: (String(localized: "Checking…"), String(localized: "Asking the helper"), true)
            case .notInstalled:
                (String(localized: "Helper not installed"), String(localized: "Charge limit unavailable"), false)
            case .needsApproval:
                (String(localized: "Helper needs approval"), String(localized: "Turn it on in Login Items"), false)
            case .notResponding:
                (String(localized: "Helper not responding"), String(localized: "Charge limit unavailable"), false)
            }
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                PulseDot(color: ok ? Theme.accent : Theme.warn)
                Text(title).font(.system(size: 12))
            }
            Text(detail).font(.system(size: 12)).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            LinearGradient(colors: [Theme.cardTop, Theme.cardBottom], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
        .accessibilityElement(children: .combine)
    }
}

/// A status dot with a slow ring that pings outwards.
struct PulseDot: View {
    var color: Color = Theme.accent
    @State private var ping = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.7), radius: 4)
            .background {
                Circle()
                    .stroke(color, lineWidth: 1.5)
                    .frame(width: 13, height: 13)
                    .scaleEffect(ping ? 1.6 : 0.6)
                    .opacity(ping ? 0 : 0.5)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false)) { ping = true }
            }
            .accessibilityHidden(true)
    }
}

/// String(localized: "Live") in a hairline capsule: the page refreshes itself.
struct LivePill: View {
    let isLive: Bool

    var body: some View {
        HStack(spacing: 7) {
            if isLive { PulseDot() } else { Circle().fill(.tertiary).frame(width: 6, height: 6) }
            Text(isLive ? String(localized: "Live") : String(localized: "Not running")).font(.system(size: 11.5))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .overlay(Capsule().strokeBorder(Theme.lineStrong))
        .help(
            isLive
                ? String(localized: "The list reloads every 5 seconds") : String(localized: "The helper is not running")
        )
    }
}

// MARK: Notices

private struct NoticeStack: View {
    let model: AppModel
    let includeService: Bool

    var body: some View {
        let notices = model.notices.filter { includeService || !$0.isService }
        if !notices.isEmpty {
            VStack(spacing: 8) {
                ForEach(notices) { notice in
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(Theme.warn)
                        Text(notice.text)
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        if let action = notice.action, let title = notice.actionTitle {
                            Button(title) { model.handle(action) }
                                .buttonStyle(SoftButtonStyle(small: true))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.warnSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.warn.opacity(0.25)))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
        }
    }
}
