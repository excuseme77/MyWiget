import SwiftUI

@main
struct RockApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 16) {
                Text("🪨").font(.system(size: 80))
                Text("Камень установлен")
                    .font(.title2.bold())
                Text("Зажми пустое место на рабочем столе → «+» (или «Изменить» → «Добавить виджет») → найди «Камень» → добавь. Тыкай в него.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.08))
            .preferredColorScheme(.dark)
        }
    }
}
