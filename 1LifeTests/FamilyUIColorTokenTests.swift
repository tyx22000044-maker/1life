import XCTest
import SwiftUI
import UIKit
@testable import OneLife

/// Guards the Swiss Ledger colour contract behind `FamilyUI`'s solid-fill tokens:
/// light mode must keep looking exactly like paper-and-ink, and dark mode must
/// invert instead of dropping fixed black/white values onto a dark page.
@MainActor
final class FamilyUIColorTokenTests: XCTestCase {
    private func sRGB(_ color: Color, _ style: UIUserInterfaceStyle) -> (r: Double, g: Double, b: Double) {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(resolved.getRed(&r, green: &g, blue: &b, alpha: &a), "token must resolve to RGB")
        XCTAssertEqual(Double(a), 1, accuracy: 0.001, "solid-fill tokens are opaque")
        return (Double(r), Double(g), Double(b))
    }

    private func luminance(_ c: (r: Double, g: Double, b: Double)) -> Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }

    private func contrast(_ a: (r: Double, g: Double, b: Double), _ b: (r: Double, g: Double, b: Double)) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private var styles: [UIUserInterfaceStyle] { [.light, .dark] }

    func testSolidFillPairStaysReadableInBothAppearances() {
        for style in styles {
            XCTAssertGreaterThanOrEqual(
                contrast(sRGB(FamilyUI.buttonBackground, style), sRGB(FamilyUI.buttonForeground, style)),
                4.5,
                "ink button fails AA in \(style == .dark ? "dark" : "light") mode"
            )
        }
    }

    func testSignalFillsUseTheSameLabelTokenAndClearAA() {
        for style in styles {
            XCTAssertGreaterThanOrEqual(
                contrast(sRGB(FamilyUI.accent, style), sRGB(FamilyUI.buttonForeground, style)),
                4.5,
                "signal-coloured buttons must not rely on a fixed white label"
            )
        }
    }

    func testLightAppearanceKeepsTheHistoricalPaperAndInkValues() {
        XCTAssertEqual(luminance(sRGB(FamilyUI.buttonForeground, .light)), 1, accuracy: 0.001)
        XCTAssertLessThan(luminance(sRGB(FamilyUI.buttonBackground, .light)), 0.02)
    }

    func testDarkAppearanceInvertsInsteadOfPaintingBlackHoles() {
        XCTAssertGreaterThan(luminance(sRGB(FamilyUI.buttonBackground, .dark)), 0.7)
        XCTAssertLessThan(luminance(sRGB(FamilyUI.buttonForeground, .dark)), 0.02)
    }
}
