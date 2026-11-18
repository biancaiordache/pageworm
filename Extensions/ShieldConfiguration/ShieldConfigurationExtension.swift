import ManagedSettings
import ManagedSettingsUI
import PagewormCore
import PagewormDesign
import SwiftUI
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
        let state = AppGroupStore.load()
        let shield = state?.shield
        let title = InkyCopy.shieldTitle(name: state?.userName ?? "")
        let subtitle = InkyCopy.shieldSubtitle(
            bookTitle: shield?.bookTitle ?? "",
            pagesLeft: shield?.pagesLeftInChapter ?? 0
        )
        return ShieldConfiguration(
            backgroundBlurStyle: .systemThinMaterial,
            backgroundColor: .pwPaper,
            icon: inkyImage(stage: shield?.stage ?? .sprout, mood: shield?.mood ?? .sleepy),
            title: ShieldConfiguration.Label(text: title, color: .pwInk),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: .pwInkSoft),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Start reading", color: .pwCream),
            primaryButtonBackgroundColor: .pwMoss
        )
    }

    private func inkyImage(stage: InkyStage, mood: InkyMood) -> UIImage? {
        let renderer = ImageRenderer(content: InkyView(stage: stage, mood: mood, size: 96, animated: false))
        renderer.scale = 2
        return renderer.uiImage
    }
}
