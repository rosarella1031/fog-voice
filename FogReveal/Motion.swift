import SwiftUI

// MARK: - 基础插值工具

/// CSS 的 cubic-bezier(x1, y1, x2, y2)，用牛顿迭代反解 t
struct CubicBezier {
    let x1, y1, x2, y2: Double

    func callAsFunction(_ x: Double) -> Double {
        let x = min(max(x, 0), 1)
        let cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx
        let cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by
        var t = x
        for _ in 0..<8 {
            let e = ((ax * t + bx) * t + cx) * t - x
            let d = (3 * ax * t + 2 * bx) * t + cx
            if abs(e) < 1e-6 || abs(d) < 1e-6 { break }
            t -= e / d
        }
        t = min(max(t, 0), 1)
        return ((ay * t + by) * t + cy) * t
    }
}

/// 原组件 organic-ui 的缓动：cubic-bezier(0.42, 0, 0.3, 1)
let podcastCurve = CubicBezier(x1: 0.42, y1: 0, x2: 0.3, y2: 1)

extension Animation {
    static func fog(duration: Double) -> Animation {
        .timingCurve(0.42, 0, 0.3, 1, duration: duration)
    }
}

func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
func clamp01(_ v: Double) -> Double { min(max(v, 0), 1) }
/// 把 v 在 [lo, hi] 里的位置映射成 0…1
func span(_ v: Double, _ lo: Double, _ hi: Double) -> Double { clamp01((v - lo) / (hi - lo)) }
/// smoothstep：value² · (3 − 2·value)
func smooth(_ v: Double) -> Double { v * v * (3 - 2 * v) }

/// 当前时间（秒），所有逐帧动画共用一个时钟
func now() -> Double { Date.timeIntervalSinceReferenceDate }

// MARK: - 可随时改目标的补间 / 弹簧

/// 从当前值出发、走完整时长的补间（等价于 framer-motion 的 animate(value, target)）
struct Tween {
    var from = 0.0, to = 0.0, start = 0.0, duration = 0.0

    func value(at t: Double) -> Double {
        guard duration > 0 else { return to }
        return mix(from, to, podcastCurve(clamp01((t - start) / duration)))
    }

    mutating func retarget(_ target: Double, at t: Double, duration d: Double) {
        from = value(at: t); to = target; start = t; duration = d
    }
}

/// 临界阻尼弹簧，近似原组件 useSpring(stiffness: 112, damping: 22)
struct CriticalSpring {
    var from = 0.0, to = 0.0, start = 0.0
    let omega = 10.6 // √112

    func value(at t: Double) -> Double {
        let dt = max(0, t - start)
        return to + (from - to) * (1 + omega * dt) * exp(-omega * dt)
    }

    mutating func retarget(_ target: Double, at t: Double) {
        from = value(at: t); to = target; start = t
    }
}

/// 模拟“说话音量”的包络：3.1 秒里 [0, 0, 1, 0, 0]
struct VoiceEnvelope {
    var start: Double?
    static let duration = 3.1
    private static let times = [0, 0.18, 0.52, 0.9, 1.0]
    private static let values = [0, 0, 1, 0, 0.0]

    func value(at t: Double) -> Double {
        guard let start else { return 0 }
        let k = (t - start) / Self.duration
        guard k > 0, k < 1 else { return 0 }
        for i in 1..<Self.times.count where k <= Self.times[i] {
            let local = (k - Self.times[i - 1]) / (Self.times[i] - Self.times[i - 1])
            return mix(Self.values[i - 1], Self.values[i], podcastCurve(local))
        }
        return 0
    }
}
