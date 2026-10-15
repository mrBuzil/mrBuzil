import SwiftUI

/// Стартовый экран-заглушка. Шаг 1: убедиться, что приложение собирается
/// и запускается на iPhone, iPad и Apple TV.
struct RootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Мои дела")
                .font(.largeTitle.bold())
            Text(Self.platformName)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    static var platformName: String {
        #if os(tvOS)
        return "Apple TV"
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #endif
    }
}

#Preview {
    RootView()
}
