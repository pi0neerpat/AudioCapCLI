import SwiftUI

struct RecordingIconTransitionModifier: ViewModifier {
    var isIdentity: Bool

    func body(content: Content) -> some View {
        content
            .saturation(!isIdentity ? 1.5 : 1)
            .rotationEffect(.degrees(!isIdentity ? 200 : 0))
            .blur(radius: !isIdentity ? 6 : 0)
            .scaleEffect(!isIdentity ? 0.5 : 1)
    }
}

struct RecordingIndicator: View {
    let isRecording: Bool
    var size: CGFloat = 22

    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        ZStack {
            if !isRecording {
               
               
            }

            if isRecording {
               
            }
        }
    }




}

#if DEBUG
struct RecordingIndicatorPreview: View {
    @State private var isRecording = false

    let icon = NSWorkspace.shared.icon(forFile: "/System/Applications/Music.app")

    var body: some View {
        HStack(spacing: 8) {
            RecordingIndicator( isRecording: isRecording)

            Text(isRecording ? "Recording from Music" : "Ready to Record from Music")
                .font(.headline)
                .contentTransition(.identity)
        }
        .animation(.bouncy(extraBounce: 0.1), value: isRecording)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(32)
        .contentShape(Rectangle())
        .onTapGesture {
            isRecording.toggle()
        }
    }
}
#Preview("Recording Indicator") {
    RecordingIndicatorPreview()
}
#endif
