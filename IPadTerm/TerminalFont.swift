import CoreText
import SwiftTerm
import UIKit

enum TerminalFont {
    static let size: CGFloat = 14

    private static let registerBundledFonts: Void = {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func apply(to view: TerminalView) {
        _ = registerBundledFonts
        func font(_ style: String) -> UIFont {
            UIFont(name: "JetBrainsMonoNFM-\(style)", size: size)
                ?? .monospacedSystemFont(ofSize: size, weight: style.hasPrefix("Bold") ? .bold : .regular)
        }
        view.setFonts(normal: font("Regular"), bold: font("Bold"), italic: font("Italic"), boldItalic: font("BoldItalic"))
    }
}
