import SwiftUI

private let glass = Color(hex: 0x171424).opacity(0.15)

// MARK: - 状态文字

enum StatusStyle { case plain, transcript, reply }

/// 一行状态。换文字时整行交叉淡入淡出（上移 1.5pt 离开、下方 2pt 进入）；
/// transcript（用户说的话）按语速逐词浮现，reply（助手回答）逐词淡入，每词间隔 42ms。
struct StatusLine: View {
    let text: String
    let style: StatusStyle
    @State private var start = Date()

    var body: some View {
        Group {
            if style == .plain {
                Text(text).foregroundStyle(.white)
            } else {
                TimelineView(.animation) { timeline in
                    words(elapsed: timeline.date.timeIntervalSince(start))
                }
            }
        }
        .font(.system(size: 17))
        .lineSpacing(1)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func words(elapsed: Double) -> Text {
        let list = text.split(separator: " ").map(String.init)
        let spoken = style == .transcript
        // 用户的话：大约 1.9 秒说完；助手：每词 42ms
        let gap = spoken ? 1.9 / Double(max(list.count, 1)) : 0.042
        let fade = spoken ? 0.3 : 0.24
        let base = spoken ? 0.62 : 1.0
        return list.enumerated().reduce(Text("")) { acc, item in
            let (i, word) = item
            let o = podcastCurve(clamp01((elapsed - Double(i) * gap) / fade))
            let piece = Text(i > 0 ? " " + word : word).foregroundStyle(Color.white.opacity(base * o))
            return Text("\(acc)\(piece)")
        }
    }
}

// MARK: - 结果卡片

struct TrackCard: View {
    let track: Track
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: 12) {
                Cover(colors: track.colors, radius: 15, seed: track.id)
                    .aspectRatio(1, contentMode: .fit)
                    .containerRelativeFrame(.horizontal) { w, _ in w * 0.3 }
                VStack(alignment: .leading, spacing: 6) {
                    Text(track.title).font(.system(size: 20, weight: .semibold)).tracking(-0.3).lineLimit(2)
                    Text(track.artist).font(.system(size: 17)).foregroundStyle(.white.opacity(0.9))
                    Spacer(minLength: 8)
                    HStack {
                        Text(track.duration).font(.system(size: 17)).monospacedDigit().foregroundStyle(.white.opacity(0.9))
                        Spacer(minLength: 0)
                        // 卡片本身点开详情；这个键只负责播放，点它不会打开详情
                        PlayButton(key: track.id, look: .onGlass, size: 36)
                            .padding(.vertical, -4)
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .frame(minHeight: 140)
            .foregroundStyle(.white)
            .background(glass, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(track.title), \(track.artist)")
    }
}

/// 横滑卡片：吸附对齐，离中心越远缩得越小（最多 8%）
struct TrackCarousel: View {
    let matches: [Track]
    @Binding var anchorID: String?
    let onOpen: (Track) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(matches) { track in
                    TrackCard(track: track) { onOpen(track) }
                        .containerRelativeFrame(.horizontal) { w, _ in matches.count == 1 ? w : w - 42 }
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content.scaleEffect(1 - min(1, abs(phase.value)) * 0.08)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 24, for: .scrollContent)
        .scrollPosition(id: $anchorID)
    }
}

/// 卡片抽屉：高度 = 真实高度 × travel，内容贴底；travel 过了 0.31 才开始淡入并上移 10pt
struct ShelfReveal: ViewModifier, Animatable {
    var travel: Double
    var natural: CGFloat

    var animatableData: Double {
        get { travel }
        set { travel = newValue }
    }

    func body(content: Content) -> some View {
        let p = smooth(span(travel, 0.31, 1))
        content
            .opacity(p)
            .offset(y: 10 * (1 - p))
            .frame(height: natural * travel, alignment: .bottom)
    }
}

// MARK: - 详情卡片

struct TrackDetail: View {
    let track: Track
    let onBack: () -> Void
    @Environment(Player.self) private var player

    var body: some View {
        let playing = player.current == track.id
        VStack(alignment: .leading, spacing: 12) {
            // 返回放在卡片左上角自己的一行，不挤在文字栏里
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                    Text("Results").font(.system(size: 15))
                }
                .foregroundStyle(.white.opacity(0.8))
                .frame(height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
            .padding(.bottom, -4)
            .accessibilityLabel("返回结果")

            HStack(alignment: .top, spacing: 12) {
                Cover(colors: track.colors, radius: 17, seed: track.id)
                    .aspectRatio(1, contentMode: .fit)
                    .containerRelativeFrame(.horizontal) { w, _ in w * 0.33 }
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title).font(.system(size: 20, weight: .semibold))
                    Text("\(track.artist) · \(track.album)").font(.system(size: 15)).foregroundStyle(.white.opacity(0.75))
                    Text(track.blurb).font(.system(size: 17)).foregroundStyle(.white.opacity(0.95)).padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { withAnimation(.fog(duration: 0.26)) { player.toggle(track.id) } } label: {
                HStack {
                    ZStack {
                        Image(systemName: "play.fill").opacity(playing ? 0 : 1)
                        PlayingBars(active: playing).opacity(playing ? 1 : 0)
                    }
                    .frame(width: 18)
                    Text(playing ? "Playing" : "Play")
                        .contentTransition(.opacity)
                    Spacer()
                    Text(track.duration).monospacedDigit()
                }
                .font(.system(size: 17))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(.white.opacity(0.12), in: Capsule())
                .contentShape(Capsule())
                .animation(.fog(duration: 0.26), value: playing)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .foregroundStyle(.white)
        .background(glass, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
    }
}

