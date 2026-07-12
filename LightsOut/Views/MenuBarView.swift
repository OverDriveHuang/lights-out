import SwiftUI
import LaunchAtLogin

struct MenuBarView: View {
    @EnvironmentObject var viewModel: DisplaysViewModel
    @EnvironmentObject var layoutController: DisplayLayoutController
    @State private var isLoading: Bool = false
    @AppStorage("ShowStartupPrompt") private var showStartupPrompt: Bool = true

    var body: some View {
        ZStack {
            ContentView(isLoading: $isLoading)
                .environmentObject(viewModel)
                .environmentObject(layoutController)
                .disabled(isLoading)
                .opacity(isLoading ? 0.5 : 1.0)

            if showStartupPrompt {
                CustomUserPrompt(
                    title: "Enable Launch at Login",
                    message: "Would you like this app to launch automatically when you log in?",
                    primaryButton: ("Yes", {
                        showStartupPrompt = false
                        LaunchAtLogin.isEnabled = true
                    }),
                    secondaryButton: ("No", {
                        showStartupPrompt = false
                        LaunchAtLogin.isEnabled = false
                    })
                )
            }
        }
        .frame(width: 372)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.black.opacity(0.28)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
        .animation(.snappy, value: isLoading)
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: DisplaysViewModel
    @Binding var isLoading: Bool

    var body: some View {
        VStack(spacing: 0) {
            DisplayListView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

            Divider()

            MenuBarHeader(isLoading: $isLoading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
        }
        .padding(.horizontal, 14)

    }
}

#Preview("MenuBarView") {
    let viewModel = DisplaysViewModel(fetchOnInit: false)
    MenuBarView()
        .environmentObject(viewModel)
        .environmentObject(DisplayLayoutController(displaysViewModel: viewModel))
        .environmentObject(ErrorHandler())
}

#Preview("ContentView") {
    let viewModel = DisplaysViewModel(fetchOnInit: false)
    ContentView(isLoading: .constant(false))
        .environmentObject(viewModel)
        .environmentObject(DisplayLayoutController(displaysViewModel: viewModel))
        .environmentObject(ErrorHandler())
        .frame(width: 372)
}
