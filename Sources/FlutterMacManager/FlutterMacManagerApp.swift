import SwiftUI

@main
struct FlutterMacManagerApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            PopoverRootView(state: state)
                .frame(width: 460, height: 560)
        } label: {
            Label {
                Text(state.menuBarTitle)
            } icon: {
                Image(systemName: "hammer.circle.fill")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
