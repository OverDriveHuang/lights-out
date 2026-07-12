import Carbon.HIToolbox
import CoreGraphics
import Foundation

final class GlobalDisplayLayoutHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let onPressed: () -> Void
    private let onCombinationReleased: () -> Void
    private let onAllKeysReleased: () -> Void
    private var releasePollGeneration: UInt64 = 0

    init?(
        onPressed: @escaping () -> Void,
        onCombinationReleased: @escaping () -> Void,
        onAllKeysReleased: @escaping () -> Void
    ) {
        self.onPressed = onPressed
        self.onCombinationReleased = onCombinationReleased
        self.onAllKeysReleased = onAllKeysReleased

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                let hotKey = Unmanaged<GlobalDisplayLayoutHotKey>.fromOpaque(userData).takeUnretainedValue()
                switch GetEventKind(event) {
                case UInt32(kEventHotKeyPressed):
                    hotKey.releasePollGeneration &+= 1
                    hotKey.onPressed()
                case UInt32(kEventHotKeyReleased):
                    hotKey.onCombinationReleased()
                    hotKey.waitForAllKeysToBeReleased()
                default:
                    break
                }
                return noErr
            },
            eventTypes.count,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard handlerStatus == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: 0x4C4F4C59, id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_P),
            UInt32(controlKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
            return nil
        }
    }

    private func waitForAllKeysToBeReleased() {
        releasePollGeneration &+= 1
        let generation = releasePollGeneration
        pollForRelease(generation: generation)
    }

    private func pollForRelease(generation: UInt64) {
        guard generation == releasePollGeneration else { return }

        let flags = CGEventSource.flagsState(.combinedSessionState)
        let pIsDown = CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(kVK_ANSI_P))
        let modifiersAreDown = flags.contains(.maskControl) || flags.contains(.maskCommand)
        guard pIsDown || modifiersAreDown else {
            onAllKeysReleased()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) { [weak self] in
            self?.pollForRelease(generation: generation)
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}
