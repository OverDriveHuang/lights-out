import SwiftUI

struct MenuBarHeader: View {
    @Binding var isLoading: Bool
    @EnvironmentObject var viewModel: DisplaysViewModel
    
    var body: some View {
        let commitID = Bundle.main.object(forInfoDictionaryKey: "GitCommit") as? String
        
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "display.2")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("LightsOut")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(commitID.map { "Commit \($0)" } ?? "Commit unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            HStack(spacing: 8) {
                Button {
                    isLoading = true
                    viewModel.fetchDisplays {
                        isLoading = false
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
                .disabled(isLoading)
                .help("Refresh displays")
            }
        }
    }
}

#Preview {
    MenuBarHeader(isLoading: .constant(false))
        .environmentObject(DisplaysViewModel())
        .frame(width: 372)
        .padding()
}
