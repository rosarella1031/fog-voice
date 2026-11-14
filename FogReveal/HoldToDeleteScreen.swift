import SwiftUI

/// 想法 2：按住一首歌，雾从手指下面慢慢长出来（像往玻璃上哈气）。
/// 按满 holdDuration 就删除；中途松手或手指滑开，雾退回去。
struct HoldToDeleteScreen: View {
    @State private var episodes = Song.samples
    @State private var progress = 0.0
    @State private var origin = CGPoint.zero
    @State private var holding: Song?
    @State private var touchActive = false
    @State private var pressToken = UUID()
    @State private var deletedCount = 0
    @State private var lastDeleted: String?

    private let holdDuration = 1.4

    var body: some View {
        ZStack(alignment: .topLeading) {
            list
                .modifier(FogReveal(progress: progress, origin: origin))

            // 雾上的文字：贴在手指下方，那里的雾最先变浓，白字才看得清
            GeometryReader { proxy in
                let frame = proxy.frame(in: .global)
                let y = min(max(origin.y - frame.minY + 96, 80), proxy.size.height - 80)
                label
                    .frame(width: proxy.size.width - 64)
                    .position(x: proxy.size.width / 2, y: y)
            }
            .opacity(min(1, progress * 2.5))
            .allowsHitTesting(false)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: holding?.id) { _, new in new != nil }
        .sensoryFeedback(.success, trigger: deletedCount)
    }

    private var label: some View {
            VStack(spacing: 6) {
                if let holding {
                    Text("继续按住")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("删除《\(holding.name)》")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
            }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Downloads").font(.system(size: 32, weight: .semibold)).tracking(-0.6)
            Text(lastDeleted.map { "已删除《\($0)》" } ?? "按住一首，删除它的下载")
                .font(.system(size: 15))
                .foregroundStyle(Color.inkMuted)
                .padding(.top, 6)
                .padding(.bottom, 12)
                .contentTransition(.opacity)

            ForEach(episodes) { ep in
                SongRow(song: ep)
                    .gesture(holdGesture(for: ep))
            }

            if episodes.isEmpty {
                Button("恢复示例") { withAnimation(.snappy) { episodes = Song.samples; lastDeleted = nil } }
                    .padding(.top, 12)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.paper.ignoresSafeArea())
    }

    private func holdGesture(for ep: Song) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if !touchActive {
                    touchActive = true
                    begin(ep, at: value.startLocation)
                } else if holding != nil, hypot(value.translation.width, value.translation.height) > 24 {
                    release() // 手指滑开 = 取消
                }
            }
            .onEnded { _ in
                touchActive = false
                if holding != nil { release() }
            }
    }

    private func begin(_ ep: Song, at point: CGPoint) {
        guard holding == nil else { return }
        holding = ep
        origin = point
        let token = UUID()
        pressToken = token
        // 按住期间雾匀速“呼”出来，按住多久就长多大
        withAnimation(.linear(duration: holdDuration)) { progress = 1 }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(holdDuration))
            guard pressToken == token, holding?.id == ep.id else { return }
            withAnimation(.snappy) {
                episodes.removeAll { $0.id == ep.id }
                lastDeleted = ep.name
            }
            deletedCount += 1
            release()
        }
    }

    private func release() {
        pressToken = UUID()
        withAnimation(.fog(duration: 0.52)) {
            progress = 0
            holding = nil
        }
    }
}

#Preview { HoldToDeleteScreen().environment(Player()) }
