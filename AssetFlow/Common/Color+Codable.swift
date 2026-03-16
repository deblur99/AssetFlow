import AppKit
import SwiftUI

// SwiftUI.Color는 Codable이 아니므로 NSColor를 거쳐 sRGB 성분으로 직렬화한다.
extension Color: @retroactive Codable {
    private enum CodingKeys: String, CodingKey { case r, g, b, a }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self = Color(
            .sRGB,
            red:     try c.decode(Double.self, forKey: .r),
            green:   try c.decode(Double.self, forKey: .g),
            blue:    try c.decode(Double.self, forKey: .b),
            opacity: try c.decode(Double.self, forKey: .a)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        // NSColor.usingColorSpace(_:) 실패 시 .sRGBLinear fallback
        let ns = NSColor(self).usingColorSpace(.sRGB)
               ?? NSColor(self).usingColorSpace(.genericRGB)
               ?? .black
        try c.encode(Double(ns.redComponent),   forKey: .r)
        try c.encode(Double(ns.greenComponent), forKey: .g)
        try c.encode(Double(ns.blueComponent),  forKey: .b)
        try c.encode(Double(ns.alphaComponent), forKey: .a)
    }
}
