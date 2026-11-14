import SwiftUI

enum Style: String { case piano, jazz, electronic, ambient }

/// 助手能找到的曲目（虚构）
struct Track: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let seconds: Int
    let style: Style
    let blurb: String
    let colors: [Color]

    var duration: String { "\(seconds / 60):\(String(format: "%02d", seconds % 60))" }
}

extension Track {
    static let all: [Track] = [
        Track(id: "lanterns", title: "Paper Lanterns", artist: "Mina Aoki", album: "Low Tide", seconds: 222, style: .piano,
              blurb: "Soft felt piano, recorded close enough to hear the pedals.",
              colors: Palette.tulip),
        Track(id: "kettle", title: "Kettle Steam", artist: "The Quiet Hours", album: "Rooms", seconds: 310, style: .ambient,
              blurb: "Slow synth pads that rise and settle like a breath.",
              colors: Palette.lavender),
        Track(id: "window", title: "Window Seat", artist: "Lio Carver", album: "Blue Hour", seconds: 198, style: .jazz,
              blurb: "Brushed drums and an upright bass taking their time.",
              colors: Palette.iris),
        Track(id: "bloom", title: "Slow Bloom", artist: "Mina Aoki", album: "Low Tide", seconds: 266, style: .piano,
              blurb: "A long piano piece that opens one note at a time.",
              colors: Palette.sakura),
        Track(id: "tram", title: "Tram Lines", artist: "Northbound Static", album: "Night Bus", seconds: 177, style: .electronic,
              blurb: "A light beat with the hum of a city after midnight.",
              colors: Palette.pansy),
        Track(id: "linen", title: "Linen", artist: "Ada Morrow", album: "Linen", seconds: 235, style: .piano,
              blurb: "Piano and a single cello, warm and unhurried.",
              colors: Palette.daisy),
    ]
}

/// “理解”用户的话：和原组件一样只是关键词匹配
struct Preferences: Equatable {
    var maxMinutes: Int?
    var style: Style?

    func refined(by request: String) -> Preferences {
        let r = request.lowercased()
        var next = self
        if r.contains("any length") {
            next.maxMinutes = nil
        } else if let m = r.firstMatch(of: #/(\d{1,3})[\s-]*(?:minutes?|mins?)/#) {
            next.maxMinutes = Int(m.1)
        }
        if r.contains("any style") { next.style = nil }
        else if r.contains("piano") { next.style = .piano }
        else if r.contains("jazz") { next.style = .jazz }
        else if r.contains("electronic") { next.style = .electronic }
        else if r.contains("ambient") { next.style = .ambient }
        return next
    }

    var matches: [Track] {
        Track.all.filter { t in
            (maxMinutes.map { t.seconds <= $0 * 60 } ?? true) && (style.map { t.style == $0 } ?? true)
        }
    }
}

// MARK: - AI 歌单

extension Track {
    /// “下雨天写东西用、40 分钟左右”的歌单，按出场顺序（虚构曲目）
    static let rainy: [Track] = [
        all[0], // Paper Lanterns
        all[5], // Linen
        all[2], // Window Seat —— 之后会被换掉
        all[1], // Kettle Steam
        Track(id: "grey", title: "Grey Morning", artist: "Ada Morrow", album: "Linen", seconds: 251, style: .ambient,
              blurb: "Strings held so long they turn into weather.", colors: Palette.peony),
        Track(id: "tin", title: "Rain on Tin", artist: "The Quiet Hours", album: "Rooms", seconds: 284, style: .ambient,
              blurb: "Field recordings of a roof, slowed into a pad.", colors: Palette.hydrangea),
        Track(id: "coffee", title: "Late Coffee", artist: "Lio Carver", album: "Blue Hour", seconds: 207, style: .jazz,
              blurb: "A trio playing quietly so the room can talk.", colors: Palette.sunflower),
        all[4], // Tram Lines
        Track(id: "boats", title: "Paper Boats", artist: "Mina Aoki", album: "Low Tide", seconds: 243, style: .piano,
              blurb: "Short piano phrases that drift and return.", colors: Palette.camellia),
        Track(id: "lastlight", title: "Last Light", artist: "Ada Morrow", album: "Linen", seconds: 301, style: .piano,
              blurb: "A slow close, cello under piano.", colors: Palette.peony),
    ]

    /// 用户说“把第三首换成更柔和的”时换进来的那首
    static let softer = all[3] // Slow Bloom
}
