import ManagedSettings
import ManagedSettingsUI
import PagewormCore
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        let snapshot = SharedStore.snapshot(in: AppGroupDefaults.suite())
        let subtitle: String
        if snapshot.bookTitle.isEmpty {
            subtitle = "Open Pageworm and read a few pages. I'll open the door."
        } else if snapshot.pagesToNextChapter <= 0 {
            subtitle = "The last chapter of \(snapshot.bookTitle) is done. Open Pageworm for the next book."
        } else {
            let pages = snapshot.pagesToNextChapter
            subtitle = "\(pages) \(pages == 1 ? "page" : "pages") to the next chapter of \(snapshot.bookTitle)."
        }
        let ink = UIColor(red: 0.173, green: 0.141, blue: 0.125, alpha: 1)
        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            backgroundColor: UIColor(red: 0.965, green: 0.941, blue: 0.902, alpha: 1),
            icon: ShieldInky.image(),
            title: ShieldConfiguration.Label(text: "Inky closed this one", color: ink),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor(red: 0.42, green: 0.35, blue: 0.31, alpha: 1)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Start reading", color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.486, green: 0.227, blue: 0.290, alpha: 1),
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: ink)
        )
    }
}

enum ShieldInky {
    static func image() -> UIImage {
        let side: CGFloat = 160
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            let sage = UIColor(red: 0.561, green: 0.647, blue: 0.541, alpha: 1)
            let paper = UIColor(red: 0.992, green: 0.976, blue: 0.953, alpha: 1)
            let ink = UIColor(red: 0.173, green: 0.141, blue: 0.125, alpha: 1)
            let blush = UIColor(red: 0.906, green: 0.718, blue: 0.647, alpha: 1)
            let mark = UIColor(red: 0.486, green: 0.227, blue: 0.290, alpha: 1)
            paper.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 8, y: 8, width: 144, height: 144))
            sage.setFill()
            for index in 0..<3 {
                let x = 28 + CGFloat(index) * 28
                ctx.cgContext.fillEllipse(in: CGRect(x: x, y: 78, width: 42, height: 42))
            }
            ctx.cgContext.fillEllipse(in: CGRect(x: 78, y: 42, width: 62, height: 62))
            ink.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 96, y: 62, width: 8, height: 8))
            ctx.cgContext.fillEllipse(in: CGRect(x: 116, y: 62, width: 8, height: 8))
            blush.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 92, y: 78, width: 10, height: 7))
            ctx.cgContext.fillEllipse(in: CGRect(x: 118, y: 78, width: 10, height: 7))
            mark.setFill()
            ctx.cgContext.fill(CGRect(x: 22, y: 58, width: 12, height: 36))
        }
    }
}
