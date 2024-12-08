import Combine
import SwiftUI

enum KeyboardCommand {
    case copy
    case paste
    case cut
    case custom(name: String) // Allows for future expansion
}

class KeyboardManager: ObservableObject {
    // Publish the last command so that views can observe and react to changes
    @Published var lastCommand: KeyboardCommand?

    // Singleton instance for simplicity
    static let shared = KeyboardManager()

    private init() {}

    // Trigger any command
    func trigger(command: KeyboardCommand) {
        lastCommand = command
    }
}

protocol KeyboardCommandResponder {
    func processCommand(_ command: KeyboardCommand)
}

struct KeyboardCommandModifier: ViewModifier {
    @ObservedObject var keyboardManager = KeyboardManager.shared
    var handler: KeyboardCommandResponder

    func body(content: Content) -> some View {
        content
            .onReceive(keyboardManager.$lastCommand) { command in
                if let command = command {
                    handler.processCommand(command)
                }
            }
    }
}

extension View {
    func keyboardCommands(handler: KeyboardCommandResponder) -> some View {
        modifier(KeyboardCommandModifier(handler: handler))
    }
}
