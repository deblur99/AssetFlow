import AppKit
import SwiftUI

// MARK: - ImageElement: NSImage ↔ PNG Data 변환

extension ImageElement: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, isVisible, isLocked, opacity, rotation, frame, imageData, shadow
    }

    init(from decoder: any Decoder) throws {
        let c     = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self,    forKey: .id)
        name      = try c.decode(String.self,  forKey: .name)
        isVisible = try c.decode(Bool.self,    forKey: .isVisible)
        isLocked  = try c.decode(Bool.self,    forKey: .isLocked)
        opacity   = try c.decode(Double.self,  forKey: .opacity)
        rotation  = try c.decode(Double.self,  forKey: .rotation)
        frame     = try c.decode(CGRect.self,  forKey: .frame)
        let data  = try c.decode(Data.self,    forKey: .imageData)
        image     = NSImage(data: data) ?? NSImage()
        shadow    = try c.decodeIfPresent(ShadowConfig.self, forKey: .shadow)
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,        forKey: .id)
        try c.encode(name,      forKey: .name)
        try c.encode(isVisible, forKey: .isVisible)
        try c.encode(isLocked,  forKey: .isLocked)
        try c.encode(opacity,   forKey: .opacity)
        try c.encode(rotation,  forKey: .rotation)
        try c.encode(frame,     forKey: .frame)
        let png = image.tiffRepresentation.flatMap {
            NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:])
        } ?? Data()
        try c.encode(png, forKey: .imageData)
        try c.encodeIfPresent(shadow, forKey: .shadow)
    }
}

// MARK: - CanvasElement: 연관값이 있는 enum 커스텀 Codable

extension CanvasElement: Codable {
    private enum ElementType: String, Codable {
        case shape, path, image, text, background
    }
    private enum CodingKeys: String, CodingKey { case type, data }

    init(from decoder: any Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(ElementType.self, forKey: .type)
        switch kind {
        case .shape:
            self = .shape(try c.decode(ShapeElement.self, forKey: .data))
        case .path:
            self = .path(try c.decode(PathElement.self, forKey: .data))
        case .image:
            self = .image(try c.decode(ImageElement.self, forKey: .data))
        case .text:
            self = .text(try c.decode(TextElement.self, forKey: .data))
        case .background:
            self = .background(try c.decode(BackgroundElement.self, forKey: .data))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .shape(let e):
            try c.encode(ElementType.shape, forKey: .type)
            try c.encode(e, forKey: .data)
        case .path(let e):
            try c.encode(ElementType.path, forKey: .type)
            try c.encode(e, forKey: .data)
        case .image(let e):
            try c.encode(ElementType.image, forKey: .type)
            try c.encode(e, forKey: .data)
        case .text(let e):
            try c.encode(ElementType.text, forKey: .type)
            try c.encode(e, forKey: .data)
        case .background(let e):
            try c.encode(ElementType.background, forKey: .type)
            try c.encode(e, forKey: .data)
        }
    }
}
