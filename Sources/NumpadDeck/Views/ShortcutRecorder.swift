import SwiftUI

/// Click, press a combo, done. Esc cancels.
struct ShortcutRecorder: View {
    var keyCode: UInt16
    var modifiers: UInt
    var onRecord: (UInt16, UInt) -> Void
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            HStack(spacing: 6) {
                if recording {
                    Circle().fill(.red).frame(width: 7, height: 7)
                    Text("Pressione a combinação…")
                } else if keyCode == UInt16.max {
                    Image(systemName: "record.circle")
                    Text("Gravar atalho")
                } else {
                    Text(KeyNames.describe(keyCode: keyCode, modifiers: modifiers))
                        .font(.system(.body, design: .rounded).weight(.semibold))
                }
            }
            .frame(minWidth: 150)
        }
        .buttonStyle(.bordered)
        .tint(recording ? .red : nil)
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            if e.keyCode == 53 { stop(); return nil }          // Esc
            let mods = e.modifierFlags.intersection([.command, .shift, .option, .control]).rawValue
            onRecord(e.keyCode, mods)
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}
