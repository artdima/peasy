import AppKit
import SwiftUI

/// Text laid out at its exact width. SwiftUI rounds text up to whole points,
/// which adds up across a row of pills; the mockups place text fractionally.
struct FittedText: View {
    let string: String
    var size: CGFloat = 13
    var weight: Font.Weight = .regular
    var tabular = false

    var body: some View {
        Text(verbatim: string)
            .font(.system(size: size, weight: weight))
            .monospacedDigit(tabular)
            .lineLimit(1)
            .fixedSize()
            .frame(width: width, alignment: .leading)
    }

    private var width: CGFloat {
        let font = tabular
            ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight.nsWeight)
            : NSFont.systemFont(ofSize: size, weight: weight.nsWeight)
        return (string as NSString).size(withAttributes: [.font: font]).width
    }
}

private extension Text {
    func monospacedDigit(_ enabled: Bool) -> Text {
        enabled ? monospacedDigit() : self
    }
}

private extension Font.Weight {
    var nsWeight: NSFont.Weight {
        switch self {
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        default: .regular
        }
    }
}
