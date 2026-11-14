import SwiftUI

/// 全 App 共用的“正在播放”：同一时间只有一首在播，列表、卡片、详情页的按钮状态一致
@Observable
final class Player {
    var current: String?

    func toggle(_ key: String) {
        current = current == key ? nil : key
    }
}

/// 圆形播放键。播放中变成三根跳动的小竖条，再点一次停止。
struct PlayButton: View {
    enum Look { case onLight, onGlass, onArt }

    let key: String
    var look: Look = .onLight
    var size: CGFloat = 32

    @Environment(Player.self) private var player

    var body: some View {
        let playing = player.current == key
        Button {
            withAnimation(.fog(duration: 0.26)) { player.toggle(key) }
        } label: {
            ZStack {
                Image(systemName: "play.fill")
                    .font(.system(size: size * 0.36))
                    .offset(x: size * 0.03) // 三角形的视觉重心偏左，往右挪一点才看起来居中
                    .opacity(playing ? 0 : 1)
                PlayingBars(active: playing)
                    .scaleEffect(size / 36)
                    .opacity(playing ? 1 : 0)
            }
            .foregroundStyle(look == .onLight ? Color.ink : .white)
            .frame(width: size, height: size)
            .background(background, in: Circle())
            .frame(minWidth: 44, minHeight: 44) // 点击热区至少 44pt
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playing ? "停止" : "播放")
    }

    private var background: AnyShapeStyle {
        switch look {
        case .onLight: AnyShapeStyle(Color.black.opacity(0.06))
        case .onGlass: AnyShapeStyle(Color.white.opacity(0.16))
        case .onArt: AnyShapeStyle(.ultraThinMaterial.opacity(0.9))
        }
    }
}

/// 播放中的三根小竖条
struct PlayingBars: View {
    var active: Bool

    var body: some View {
        TimelineView(.animation(paused: !active)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<3) { i in
                    let phase = sin(t * 5.2 + Double(i) * 1.7)
                    Capsule().frame(width: 3, height: 6 + 7 * (phase + 1) / 2)
                }
            }
            .frame(height: 14)
        }
    }
}

/// 列表行之间的细线：每一行底下都有一根，从文字左边开始（和系统列表一样不压在封面下面）。
/// 不用 1 个物理像素：行的 y 坐标落在半像素上时，1px 的线会被抗锯齿摊薄到几乎看不见，
/// 模拟器窗口缩小显示时也会直接丢掉。0.5pt + 稍深一点的灰，在哪都稳定。
struct RowSeparator: View {
    var inset: CGFloat = 56

    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.14))
            .frame(height: 0.5)
            .padding(.leading, inset)
    }
}
