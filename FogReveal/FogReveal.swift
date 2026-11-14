import SwiftUI

/// 雾化展开：在内容上盖一层磨砂 + 深色，用一个从 `origin` 长出来的椭圆径向渐变当遮罩。
/// `progress` 0 = 清晰，1 = 雾已展开。遵循 Animatable，SwiftUI 会逐帧插值。
///
/// `band` 不为 nil 时，雾只占屏幕底部这么高的一条（pt），上缘是一段 140pt 的软边——
/// 原组件就是这样：App 上半部分保持清晰，雾只托住底部的对话和卡片。
struct FogReveal: ViewModifier, Animatable {
    var progress: Double
    /// 雾的圆心，全局坐标（.global）
    var origin: CGPoint
    var band: Double? = nil

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(progress, band ?? 0) }
        set {
            progress = newValue.first
            if band != nil { band = newValue.second }
        }
    }

    func body(content: Content) -> some View {
        content.overlay {
            if progress > 0.0005 {
                // 雾 = 同一个页面的模糊副本 + 深紫色罩（和原组件一样）。
                // 系统 Material 的模糊太轻，背后的文字会透出来，压在雾上的白字就读不清了。
                ZStack {
                    // 先压成一层再模糊；否则每段文字各自模糊，会出现一块块深色底
                    content.compositingGroup().blur(radius: 14)
                    Color(red: 29 / 255, green: 25 / 255, blue: 43 / 255).opacity(0.57)
                        .ignoresSafeArea()
                }
                .mask { BandMask(extent: band).ignoresSafeArea() }
                .opacity(fogOpacity)
                .mask {
                    GeometryReader { proxy in
                        let frame = proxy.frame(in: .global)
                        FogMask(progress: progress, center: CGPoint(x: origin.x - frame.minX, y: origin.y - frame.minY))
                    }
                    .ignoresSafeArea()
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

    /// 分段透明度：[0, .2, .58, 1] → [0, .37, .89, 1]，开头淡、中段才变浓
    private var fogOpacity: Double {
        let input = [0, 0.2, 0.58, 1.0]
        let output = [0, 0.37, 0.89, 1.0]
        let p = clamp01(progress)
        for i in 1..<input.count where p <= input[i] {
            let k = (p - input[i - 1]) / (input[i] - input[i - 1])
            return output[i - 1] + (output[i] - output[i - 1]) * k
        }
        return 1
    }
}

/// 椭圆径向渐变：半径 = 宽的 205%·p、高的 125%·p，四档软边
private struct FogMask: View {
    var progress: Double
    var center: CGPoint

    var body: some View {
        Canvas { ctx, size in
            let rx = (0.001 + 2.05 * progress) * size.width
            let ry = (0.001 + 1.25 * progress) * size.height
            ctx.translateBy(x: center.x, y: center.y)
            ctx.scaleBy(x: rx, y: ry) // 把单位圆拉成椭圆
            let stops = Gradient(stops: [
                .init(color: .black, location: 0.54),
                .init(color: .black.opacity(0.75), location: 0.68),
                .init(color: .black.opacity(0.2), location: 0.88),
                .init(color: .clear, location: 1.0),
            ])
            ctx.fill(
                Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)),
                with: .radialGradient(stops, center: .zero, startRadius: 0, endRadius: 1)
            )
        }
    }
}

/// 底部一条：从底往上 extent−140 以内全实，往上经过 .78 / .27 两档，到 extent 处透明
private struct BandMask: View {
    var extent: Double?

    var body: some View {
        if let extent {
            GeometryReader { proxy in
                let h = max(proxy.size.height, 1)
                let at = { (fromBottom: Double) in clamp01(1 - fromBottom / h) }
                LinearGradient(stops: [
                    .init(color: .clear, location: at(extent)),
                    .init(color: .black.opacity(0.27), location: at(extent - 43)),
                    .init(color: .black.opacity(0.78), location: at(extent - 96)),
                    .init(color: .black, location: at(extent - 140)),
                    .init(color: .black, location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
        } else {
            Color.black
        }
    }
}
