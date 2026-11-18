import SwiftUI
import UIKit

public struct PagewormRGB: Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var opacity: Double

    public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    fileprivate var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: opacity)
    }
}

public enum PagewormPalette {
    public static let paper = PagewormRGB(red: 0.98, green: 0.95, blue: 0.90)
    public static let nightPaper = PagewormRGB(red: 0.16, green: 0.13, blue: 0.12)
    public static let cream = PagewormRGB(red: 0.99, green: 0.97, blue: 0.93)
    public static let nightCream = PagewormRGB(red: 0.24, green: 0.19, blue: 0.17)
    public static let ink = PagewormRGB(red: 0.22, green: 0.16, blue: 0.13)
    public static let nightInk = PagewormRGB(red: 0.96, green: 0.92, blue: 0.86)
    public static let inkSoft = PagewormRGB(red: 0.43, green: 0.34, blue: 0.28)
    public static let nightInkSoft = PagewormRGB(red: 0.78, green: 0.70, blue: 0.62)
    public static let sage = PagewormRGB(red: 0.55, green: 0.66, blue: 0.50)
    public static let moss = PagewormRGB(red: 0.33, green: 0.48, blue: 0.38)
    public static let nightMoss = PagewormRGB(red: 0.48, green: 0.64, blue: 0.50)
    public static let blush = PagewormRGB(red: 0.90, green: 0.60, blue: 0.54)
    public static let gold = PagewormRGB(red: 0.83, green: 0.64, blue: 0.32)
    public static let spine = PagewormRGB(red: 0.58, green: 0.30, blue: 0.27)
    public static let belly = PagewormRGB(red: 0.86, green: 0.91, blue: 0.78)
}

public extension Color {
    static let pwPaper = Color.dynamic(light: .paper, dark: .nightPaper)
    static let pwCream = Color.dynamic(light: .cream, dark: .nightCream)
    static let pwInk = Color.dynamic(light: .ink, dark: .nightInk)
    static let pwInkSoft = Color.dynamic(light: .inkSoft, dark: .nightInkSoft)
    static let pwSage = Color(rgb: .sage)
    static let pwMoss = Color.dynamic(light: .moss, dark: .nightMoss)
    static let pwBlush = Color(rgb: .blush)
    static let pwGold = Color(rgb: .gold)
    static let pwSpine = Color(rgb: .spine)
    static let pwBelly = Color(rgb: .belly)

    static func dynamic(light: PagewormRGB, dark: PagewormRGB) -> Color {
        Color(uiColor: UIColor { traits in
            (traits.userInterfaceStyle == .dark ? dark : light).uiColor
        })
    }

    init(rgb: PagewormRGB) {
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: rgb.opacity)
    }
}

public extension UIColor {
    static let pwPaper = UIColor { traits in
        (traits.userInterfaceStyle == .dark ? PagewormPalette.nightPaper : PagewormPalette.paper).uiColor
    }
    static let pwInk = UIColor { traits in
        (traits.userInterfaceStyle == .dark ? PagewormPalette.nightInk : PagewormPalette.ink).uiColor
    }
    static let pwInkSoft = UIColor { traits in
        (traits.userInterfaceStyle == .dark ? PagewormPalette.nightInkSoft : PagewormPalette.inkSoft).uiColor
    }
    static let pwMoss = UIColor { traits in
        (traits.userInterfaceStyle == .dark ? PagewormPalette.nightMoss : PagewormPalette.moss).uiColor
    }
    static let pwCream = UIColor { traits in
        (traits.userInterfaceStyle == .dark ? PagewormPalette.nightCream : PagewormPalette.cream).uiColor
    }
}

public enum PagewormFont {
    public static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
    }
}
