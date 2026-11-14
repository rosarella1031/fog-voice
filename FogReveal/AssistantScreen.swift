import SwiftUI

/// 原组件 PodcastAssistant 的完整流程，内容换成音乐：
/// idle → opening（雾展开 1.02s）→ listening（3.1s）→ searching（1.41s）→ reviewing（1.32s）→ results
/// 结果出现后，右下角麦克风可以继续细化；点卡片看详情；点雾以外的地方全部收起。
struct AssistantScreen: View {
    enum Phase { case idle, opening, listening, searching, reviewing, results }

    /// false：雾只托住底部一条（原组件的做法）；true：雾铺满整屏，页面整体退后
    var fullFog = false

    @State private var phase: Phase = .idle
    @State private var request = ""
    @State private var preferences = Preferences()
    @State private var hasResults = false
    @State private var anchorID: String?
    @State private var opened: Track?
    @State private var showTranscript = false
    @State private var runID = UUID()

    // 动画值
    @State private var fog = 0.0
    @State private var shelfTravel = 0.0
    @State private var showShelf = false
    @State private var shelfHeight: CGFloat = 0
    @State private var motion = AgentMotion()

    // 测量
    @State private var agentCenter = CGPoint(x: 46, y: 760)
    @State private var panelTop: CGFloat = 700
    @State private var screenBottom: CGFloat = 874

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var busy: Bool { [.opening, .listening, .searching, .reviewing].contains(phase) }
    private var resting: Bool { phase == .idle || phase == .opening }
    private var matches: [Track] { hasResults ? preferences.matches : [] }

    /// 雾带高度 = 面板实际占的高度 + 50pt 余量 + 140pt 软边（不小于原组件的 210）。
    /// 余量保证白字下面一定是浓雾，背后的列表不会透出来。整屏版本不限高度。
    private var band: Double? {
        fullFog ? nil : max(210, Double(screenBottom - panelTop) + 190)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MusicBackdrop()
                .modifier(FogReveal(progress: fog, origin: agentCenter, band: band))
                .onTapGesture { if phase != .idle { reset() } }

            panel
        }
        .background {
            Color.clear.ignoresSafeArea()
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { screenBottom = $0 }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: phase) { _, new in new == .listening || new == .results }
    }

    // MARK: - 面板

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let opened {
                TrackDetail(track: opened) { setOpened(nil) }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                replyRow
                if showShelf {
                    shelf
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 28)
        .overlay(alignment: .bottomTrailing) {
            if opened == nil && !resting {
                micButton.padding(.trailing, 24).padding(.bottom, 28)
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {} // 面板里的空白处不算“点外面”
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { panelTop = $0 }
    }

    private var replyRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            agentButton
            ZStack(alignment: .bottomLeading) {
                let (text, style) = status
                if !text.isEmpty {
                    StatusLine(text: text, style: style)
                        .id(text)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 2)).animation(.fog(duration: 0.3).delay(0.06)),
                            removal: .opacity.combined(with: .offset(y: -1.5)).animation(.fog(duration: 0.14))
                        ))
                }
            }
            .frame(minHeight: 44, alignment: .bottomLeading)
            .padding(.bottom, 10)
        }
        .padding(.trailing, 48)
        .frame(minHeight: 44)
    }

    private var agentButton: some View {
        ZStack {
            Circle()
                .fill(Color(red: 204 / 255, green: 204 / 255, blue: 208 / 255).opacity(0.76))
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.44), lineWidth: 0.5))
                .frame(width: 36, height: 36)
                .opacity(resting ? 1 : 0)
                .scaleEffect(phase == .opening ? 0.92 : resting ? 1 : 1.08)
                .animation(.fog(duration: 0.46), value: phase)
            AgentView(motion: motion)
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .onTapGesture { if resting { startVoice() } }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("唤起语音点歌")
        .onGeometryChange(for: CGPoint.self) { proxy in
            let f = proxy.frame(in: .global)
            return CGPoint(x: f.midX, y: f.midY)
        } action: { agentCenter = $0 }
    }

    private var shelf: some View {
        Group {
            if !matches.isEmpty {
                TrackCarousel(matches: matches, anchorID: $anchorID) { setOpened($0) }
                    .padding(.horizontal, -24)
                    .padding(.top, 10)
            }
        }
        .padding(.bottom, 52) // 给右下角麦克风留位置
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { shelfHeight = $0 }
        .modifier(ShelfReveal(travel: shelfTravel, natural: shelfHeight))
        .allowsHitTesting(!busy)
    }

    private var micButton: some View {
        Button { busy ? cancel() : startVoice() } label: {
            ZStack {
                Image(systemName: "mic").font(.system(size: 19)).opacity(busy ? 0 : 1)
                Image(systemName: "stop.fill").font(.system(size: 13)).opacity(busy ? 1 : 0)
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .foregroundStyle(.white.opacity(0.9))
            .animation(.fog(duration: 0.26), value: busy)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(busy ? "停止" : "用语音继续细化")
    }

    // MARK: - 文案

    private var status: (String, StatusStyle) {
        switch phase {
        case .idle, .opening: return hasResults ? (reply, .reply) : ("", .plain)
        case .listening: return showTranscript ? ("“\(request)”", .transcript) : ("Listening…", .plain)
        case .searching: return ("Looking through your library…", .plain)
        case .reviewing: return (reviewMessage, .plain)
        case .results: return (reply, .reply)
        }
    }

    private var reply: String {
        let m = matches
        let subject = m.count == 1 ? "a track" : m.count == 2 ? "two tracks" : "a few tracks"
        if m.isEmpty { return "Nothing fits yet. Try something a little longer." }
        if let style = preferences.style {
            let feel = switch style {
            case .piano: "with piano"
            case .jazz: "with a jazz feel"
            case .electronic: "that lean electronic"
            case .ambient: "that drift ambient"
            }
            return "I found \(subject) \(feel)."
        }
        if let max = preferences.maxMinutes { return "I found \(subject) under \(max) minutes." }
        return "Here are a few tracks for a quiet morning."
    }

    private var reviewMessage: String {
        let next = preferences.refined(by: request)
        if next.maxMinutes != preferences.maxMinutes { return "Checking track lengths…" }
        if next.style != preferences.style { return "Listening for the right sound…" }
        return "Picking songs for a quiet morning…"
    }

    // MARK: - 流程

    private func setPhase(_ new: Phase) {
        phase = new
        let agent: AgentState = switch new {
        case .idle, .opening: .resting
        case .listening: .listening
        case .searching: .searching
        case .reviewing: .reviewing
        case .results: .ready
        }
        motion.set(agent)
    }

    private func startVoice() {
        guard !busy else { return }
        // 和原组件一样，“用户说的话”是写死的几句，按当前状态挑一句
        request = !hasResults ? "Play something for a quiet morning."
            : preferences.maxMinutes == nil ? "Keep it under 4 minutes."
            : preferences.style != nil ? "Any style." : "Something with piano."

        let id = UUID()
        runID = id
        let wasIdle = phase == .idle
        let pace = reduceMotion ? 0.4 : 1.0

        Task { @MainActor in
            func alive() -> Bool { runID == id }
            func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s * pace)) }

            if wasIdle {
                setPhase(.opening)
                withAnimation(reduceMotion ? nil : .fog(duration: 1.02)) { fog = 1 }
                await wait(1.02); guard alive() else { return }
            }

            showTranscript = false
            setPhase(.listening)
            await wait(0.7); guard alive() else { return }
            showTranscript = true               // “Listening…” 换成用户的话，逐词浮现
            await wait(2.4); guard alive() else { return }

            setPhase(.searching)
            await wait(1.41); guard alive() else { return }
            setPhase(.reviewing)
            await wait(1.32); guard alive() else { return }

            // 细化后尽量停在“还符合条件、离当前最近”的那一首，列表不跳
            let previous = matches
            let next = preferences.refined(by: request)
            let nextMatches = next.matches
            let current = previous.firstIndex { $0.id == anchorID } ?? 0
            let retained = previous.enumerated()
                .filter { item in nextMatches.contains(item.element) }
                .min { abs($0.offset - current) < abs($1.offset - current) }?.element

            withAnimation(.fog(duration: 0.5)) {
                preferences = next
                anchorID = retained?.id ?? nextMatches.first?.id
                hasResults = true
            }
            setPhase(.results)

            if !showShelf {
                showShelf = true
                withAnimation(reduceMotion ? nil : .fog(duration: 0.88)) { shelfTravel = 1 }
            }
        }
    }

    private func cancel() {
        runID = UUID()
        if hasResults { setPhase(.results) } else { reset() }
    }

    private func setOpened(_ track: Track?) {
        withAnimation(.fog(duration: 0.3)) { opened = track }
    }

    private func reset() {
        runID = UUID()
        withAnimation(.fog(duration: 0.3)) { opened = nil }
        setPhase(.idle)
        withAnimation(reduceMotion ? nil : .fog(duration: 0.52)) { fog = 0 }
        withAnimation(reduceMotion ? nil : .fog(duration: 0.46)) {
            shelfTravel = 0
        } completion: {
            guard phase == .idle else { return }
            showShelf = false
            hasResults = false
            preferences = Preferences()
            anchorID = nil
        }
    }
}

#Preview("底部雾") { AssistantScreen().environment(Player()) }
#Preview("整屏雾") { AssistantScreen(fullFog: true).environment(Player()) }
