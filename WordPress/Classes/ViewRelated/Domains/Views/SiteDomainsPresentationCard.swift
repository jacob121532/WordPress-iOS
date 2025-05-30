import SwiftUI
import DesignSystem

/// A card with a title, a description and buttons that return an action
struct SiteDomainsPresentationCard: View {
    let title: String
    let description: String
    let destinations: [Destination]

    var body: some View {
        VStack(spacing: Length.Padding.medium) {
            VStack(spacing: Length.Padding.single) {
                VStack(spacing: -Length.Padding.large) {
                    DashboardDomainsCardSearchView()
                    Text(title)
                        .style(.heading4)
                        .foregroundColor(.DS.Foreground.primary)
                }

                Text(description)
                    .style(.bodyLarge(.regular))
                    .foregroundColor(.DS.Foreground.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Length.Padding.single)
            }

            VStack(spacing: Length.Padding.single) {
                ForEach(destinations) { destination in
                    DSButton(
                        title: destination.title,
                        style: .init(
                            emphasis: destination.style,
                            size: .large,
                            isJetpack: AppConfiguration.isJetpack
                        )) {
                            destination.action()
                        }
                }
            }
        }
    }
}

extension SiteDomainsPresentationCard {
    struct Destination: Identifiable {
        let id: UUID = UUID()
        let title: String
        let style: DSButtonStyle.Emphasis
        let action: (() -> Void)
    }
}
