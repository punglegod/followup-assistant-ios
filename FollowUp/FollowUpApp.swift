import SwiftUI
import UIKit

@main
struct FollowUpApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            AppRoot().tint(Color(red: 0.12, green: 0.47, blue: 0.43)).environmentObject(store)
                .alert("操作未完成", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button("知道了") { store.error = nil }
                } message: { Text(store.error ?? "") }
                .task { store.refreshReminders() }
                .onChange(of: phase) { phase in if phase == .active { store.refreshReminders() } }
        }
    }
}

enum AppTab: Int, CaseIterable, Identifiable {
    case dashboard, customers, library, settings
    var id: Int { rawValue }
    var title: String {
        switch self { case .dashboard: return "回访"; case .customers: return "客户"; case .library: return "词库"; case .settings: return "设置" }
    }
    var icon: String {
        switch self { case .dashboard: return "bell.badge"; case .customers: return "person.2"; case .library: return "text.book.closed"; case .settings: return "gearshape" }
    }
}

struct AppRoot: View {
    @EnvironmentObject var store: Store
    @State private var selected = AppTab.dashboard
    var body: some View {
        ZStack {
            Dashboard().opacity(selected == .dashboard ? 1 : 0).allowsHitTesting(selected == .dashboard).accessibilityHidden(selected != .dashboard)
            CustomersView().opacity(selected == .customers ? 1 : 0).allowsHitTesting(selected == .customers).accessibilityHidden(selected != .customers)
            LibraryView().opacity(selected == .library ? 1 : 0).allowsHitTesting(selected == .library).accessibilityHidden(selected != .library)
            SettingsView().opacity(selected == .settings ? 1 : 0).allowsHitTesting(selected == .settings).accessibilityHidden(selected != .settings)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GlassDock(selection: $selected, transparency: store.archive.preferences.dockTransparency)
                .padding(.horizontal, 18).padding(.top, 6).padding(.bottom, 8)
        }
        .onChange(of: selected) { _ in
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

struct GlassDock: View {
    @Binding var selection: AppTab
    let transparency: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var indicator
    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.8)) { selection = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon).font(.system(size: 20, weight: .semibold))
                        Text(tab.title).font(.caption2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity).frame(minHeight: 52)
                    .foregroundStyle(selection == tab ? Color.accentColor : Color.primary)
                    .background {
                        if selection == tab { Capsule().fill(Color.accentColor.opacity(0.14)).matchedGeometryEffect(id: "selected", in: indicator) }
                    }.contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab == .library ? "问答与话术" : tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
                .accessibilityIdentifier("dock-\(tab.rawValue)")
            }
        }
        .padding(8)
        .modifier(DockGlassSurface(transparency: transparency))
    }
}

private struct DockGlassSurface: ViewModifier {
    let transparency: Double
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var tint: Color { colorScheme == .dark ? .black : .white }

    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(uiColor: .secondarySystemBackground), in: Capsule())
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(tint.opacity((1 - transparency) * 0.5)).interactive(), in: .capsule)
        } else {
            content.background {
                Capsule().fill(.ultraThinMaterial).opacity(1 - transparency * 0.8)
                    .overlay { Capsule().fill(tint.opacity((1 - transparency) * 0.5)) }
            }
            .overlay { Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.6).allowsHitTesting(false) }
            .shadow(color: .black.opacity(0.12), radius: 15, y: 7)
        }
    }
}
