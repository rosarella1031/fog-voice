import SwiftUI

/// AI 生成歌单：同一个助手的两个层级。
///
/// 1. 底部雾：唤起、听你说话、想一下——和点歌一样，页面还在上面。
/// 2. 开始组歌单时，雾带一路长满全屏：AI 在做页面上本来没有的东西，注意力整个交给它。
///    歌一首一首落进来，2×2 封面跟着拼起来，时长往上数。
/// 3. 说“换掉第三首”可以改；说“存下来”或点 Save，雾退回底部，歌单缩成一张卡片。
/// 4. 点雾外面，雾散开，新歌单已经躺在 Recently Played 第一行。
struct PlaylistScreen: View {
    enum Phase { case idle, opening, listening, thinking, composing, ready, saved }

    @State private var phase: Phase = .idle
    @State private var request = ""
    @State private var showTranscript = false
    @State private var thinkingText = ""
    @State private var narration = ""
    @State private var tracks: [Track] = []
    @State private var titled = false
    @State private var swapped = false
    @State private var full = false
    @State private var showPlaylist = false
    @State private var runID = UUID()
    @State private var savedSong: Song?

    // 动画值
    @State private var fog = 0.0
    @State private var cardTravel = 0.0
    @State private var showCard = false
    @State private var cardHeight: CGFloat = 0
    @State private var motion = AgentMotion()

    // 测量
    @State private var agentCenter = CGPoint(x: 46, y: 760)
    @State private var panelTop: CGFloat = 700
    @State private var screenBottom: CGFloat = 874

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let title = "Rainy Desk"
    private var busy: Bool { [.opening, .listening, .thinking, .composing].contains(phase) }
    private var resting: Bool { phase == .idle || phase == .opening }
    private var minutes: Int { (tracks.reduce(0) { $0 + $1.seconds } + 30) / 60 }

    /// 底部：面板高度 + 余量 + 软边；全屏：比屏幕还高，软边也推到屏幕外面去
    private var band: Double {
        full ? Double(screenBottom) + 240 : max(210, Double(screenBottom - panelTop) + 190)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MusicBackdrop(extra: savedSong)
                .modifier(FogReveal(progress: fog, origin: agentCenter, band: band))
                .onTapGesture {
                    if phase == .saved { close() }
                    else if !full && phase != .idle { reset() }
                }

            VStack(spacing: 0) {
                if showPlaylist {
                    playlistView
                        .frame(maxHeight: .infinity, alignment: .top)
                        .transition(.opacity)
                } else {
                    Spacer(minLength: 0)
                }
                panel
            }
        }
        .background {
            Color.clear.ignoresSafeArea()
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { screenBottom = $0 }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tracks.count) { old, new in new > old }
        .sensoryFeedback(.success, trigger: phase) { _, new in new == .saved }
    }

    // MARK: - 全屏：正在组的歌单

    private var playlistView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .bottom, spacing: 16) {
                MosaicCover(tracks: Array(tracks.prefix(4)))
                    .frame(width: 112, height: 112)
                VStack(alignment: .leading, spacing: 6) {
                    Text(titled ? title : "New playlist")
                        .font(.system(size: 28, weight: .semibold)).tracking(-0.5)
                        .contentTransition(.opacity)
                    Text("\(tracks.count) tracks · \(minutes) min")
                        .font(.system(size: 15)).monospacedDigit()
                        .foregroundStyle(.white.opacity(0.75))
                        .contentTransition(.numericText())
                }
                .padding(.bottom, 4)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { i, track in
                            PlaylistRow(index: i + 1, track: track)
                                .id(track.id)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .offset(y: -8)),
                                    removal: .opacity
                                ))
                        }
                    }
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
                .mask {
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0), .init(color: .black, location: 0.03),
                        .init(color: .black, location: 0.92), .init(color: .clear, location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                }
                .onChange(of: tracks.count) {
                    guard let last = tracks.last?.id else { return }
                    withAnimation(.fog(duration: 0.5)) { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .foregroundStyle(.white)
    }

    // MARK: - 底部面板

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            replyRow
            if showCard { savedCard }
            if phase == .ready {
                Button(action: save) {
                    Text("Save playlist")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 20)
                        .frame(height: 44)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 28)
        .overlay(alignment: .bottomTrailing) {
            if !resting && phase != .saved {
                micButton.padding(.trailing, 24).padding(.bottom, 28).transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {}
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { panelTop = $0 }
        .animation(.fog(duration: 0.3), value: phase)
    }

    private var replyRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
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
            .onTapGesture { if phase == .idle { start() } }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("让 AI 做一个歌单")
            .onGeometryChange(for: CGPoint.self) { proxy in
                let f = proxy.frame(in: .global)
                return CGPoint(x: f.midX, y: f.midY)
            } action: { agentCenter = $0 }

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

    private var savedCard: some View {
        HStack(spacing: 12) {
            MosaicCover(tracks: Array(tracks.prefix(4)), radius: 12, gap: 1.5)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 18, weight: .semibold))
                Text("\(tracks.count) tracks · \(minutes) min")
                    .font(.system(size: 15)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer(minLength: 0)
            PlayButton(key: title, look: .onGlass, size: 40)
        }
        .padding(10)
        .foregroundStyle(.white)
        .background(Color(hex: 0x171424).opacity(0.15), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.top, 12)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeight = $0 }
        .modifier(ShelfReveal(travel: cardTravel, natural: cardHeight))
    }

    private var micButton: some View {
        Button { busy ? cancel() : refine() } label: {
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
        .accessibilityLabel(busy ? "停止" : "用语音修改歌单")
    }

    // MARK: - 文案

    private var status: (String, StatusStyle) {
        switch phase {
        case .idle, .opening: return ("", .plain)
        case .listening: return showTranscript ? ("“\(request)”", .transcript) : ("Listening…", .plain)
        case .thinking: return (thinkingText, .plain)
        case .composing: return (narration, .reply)
        case .ready:
            return (swapped ? "Swapped in “\(Track.softer.title)”. Anything else?"
                            : "Here’s “\(title)”: \(tracks.count) tracks, about \(minutes) minutes.", .reply)
        case .saved: return ("Saved “\(title)” to your library.", .reply)
        }
    }

    /// 组歌单时，AI 在第几首落下时换一句解说
    private let narrationAt: [Int: String] = [
        0: "Starting soft, with felt piano…",
        3: "Some slow ambient for the middle stretch…",
        6: "A little brushed jazz so it doesn’t stall…",
        9: "And ending quiet.",
    ]

    // MARK: - 流程

    private func setPhase(_ new: Phase) {
        phase = new
        let agent: AgentState = switch new {
        case .idle, .opening: .resting
        case .listening: .listening
        case .thinking: .searching
        case .composing: .reviewing
        case .ready, .saved: .ready
        }
        motion.set(agent)
    }

    /// 跑一段可被打断的流程：runID 变了就停
    private func run(_ body: @escaping @MainActor (_ wait: (Double) async -> Bool) async -> Void) {
        let id = UUID()
        runID = id
        let pace = reduceMotion ? 0.4 : 1.0
        Task { @MainActor in
            await body { seconds in
                try? await Task.sleep(for: .seconds(seconds * pace))
                return runID == id
            }
        }
    }

    private func listen(_ wait: (Double) async -> Bool) async -> Bool {
        showTranscript = false
        setPhase(.listening)
        guard await wait(0.7) else { return false }
        showTranscript = true
        return await wait(2.4)
    }

    private func start() {
        request = "Make me a playlist for writing on a rainy afternoon, about 40 minutes."
        run { wait in
            setPhase(.opening)
            withAnimation(reduceMotion ? nil : .fog(duration: 1.02)) { fog = 1 }
            guard await wait(1.02), await listen(wait) else { return }

            thinkingText = "Thinking about rainy afternoons…"
            setPhase(.thinking)
            guard await wait(1.4) else { return }

            // 升级：雾带一路长满全屏，歌单的位置让出来
            narration = "Okay, building it now."
            setPhase(.composing)
            withAnimation(.fog(duration: 1.1)) { full = true }
            guard await wait(0.6) else { return }
            withAnimation(.fog(duration: 0.4)) { showPlaylist = true }
            guard await wait(0.5) else { return }

            for (i, track) in Track.rainy.enumerated() {
                if let line = narrationAt[i] { narration = line }
                withAnimation(.fog(duration: 0.45)) { tracks.append(track) }
                guard await wait(i == 0 ? 0.8 : 0.5) else { return }
            }
            withAnimation(.fog(duration: 0.4)) { titled = true }
            setPhase(.ready)
        }
    }

    /// 结果出来后点麦克风：第一次“换掉第三首”，之后“存下来”
    private func refine() {
        guard phase == .ready else { return }
        if swapped {
            request = "Perfect, save it."
            run { wait in
                guard await listen(wait) else { return }
                save()
            }
            return
        }
        request = "Swap the third one for something softer."
        run { wait in
            guard await listen(wait) else { return }
            thinkingText = "Finding something softer…"
            setPhase(.thinking)
            guard await wait(1.3) else { return }
            withAnimation(.fog(duration: 0.5)) {
                tracks[2] = Track.softer
                swapped = true
            }
            setPhase(.ready)
        }
    }

    private func cancel() {
        runID = UUID()
        if full {
            withAnimation(.fog(duration: 0.4)) { titled = true }
            setPhase(.ready)
        } else {
            reset()
        }
    }

    /// 存下来：歌单收起，雾退回底部，变成一张卡片
    private func save() {
        runID = UUID()
        setPhase(.saved)
        withAnimation(.fog(duration: 0.3)) { showPlaylist = false }
        withAnimation(.fog(duration: 0.9)) { full = false }
        showCard = true
        withAnimation(reduceMotion ? nil : .fog(duration: 0.88).delay(0.25)) { cardTravel = 1 }
    }

    /// 点雾外面：雾散开，新歌单出现在 Recently Played 第一行
    private func close() {
        let saved = Song(name: title, artist: "Playlist · \(tracks.count) tracks", duration: "\(minutes) min",
                         colors: tracks.first?.colors ?? [], mosaic: Array(tracks.prefix(4)))
        withAnimation(.fog(duration: 0.5).delay(0.15)) { savedSong = saved }
        reset()
    }

    private func reset() {
        runID = UUID()
        setPhase(.idle)
        withAnimation(.fog(duration: 0.3)) { showPlaylist = false }
        withAnimation(reduceMotion ? nil : .fog(duration: 0.52)) {
            fog = 0
            full = false
        }
        withAnimation(reduceMotion ? nil : .fog(duration: 0.46)) {
            cardTravel = 0
        } completion: {
            guard phase == .idle else { return }
            showCard = false
            tracks = []
            titled = false
            swapped = false
        }
    }
}

/// 歌单里的一行：序号、封面、歌名 / 艺人、时长
private struct PlaylistRow: View {
    let index: Int
    let track: Track

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("\(index)")
                    .font(.system(size: 15)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .frame(width: 22, alignment: .trailing)
                Cover(colors: track.colors, radius: 8, seed: track.id)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                    Text(track.artist).font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
                }
                Spacer(minLength: 0)
                Text(track.duration)
                    .font(.system(size: 15)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.vertical, 8)
            Rectangle().fill(Color.white.opacity(0.14)).frame(height: 0.5).padding(.leading, 86)
        }
    }
}

#Preview { PlaylistScreen().environment(Player()) }
