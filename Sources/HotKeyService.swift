import AppKit
import Carbon

enum HotKeyServiceError: LocalizedError {
    case eventHandlerInstallationFailed(OSStatus)
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .eventHandlerInstallationFailed(let status):
            return "Unable to install global hotkey handler. Carbon status: \(status)"
        case .registrationFailed(let status):
            return "Unable to register global hotkey. Carbon status: \(status)"
        }
    }
}

final class HotKeyService {
    typealias Handler = () -> Void

    private let signature = OSType(0x5050616C)
    private var nextIdentifier: UInt32 = 1
    private var registrations: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: Handler] = [:]
    private var eventHandlerRef: EventHandlerRef?

    @discardableResult
    func register(keyCode: UInt32, modifiers: [HotKeyModifier], handler: @escaping Handler) throws -> UInt32 {
        try installEventHandlerIfNeeded()

        let identifier = nextIdentifier
        nextIdentifier += 1

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: identifier)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers.reduce(0) { $0 | $1.carbonFlag },
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let hotKeyRef else {
            throw HotKeyServiceError.registrationFailed(status)
        }

        registrations[identifier] = hotKeyRef
        handlers[identifier] = handler
        return identifier
    }

    func unregisterAll() {
        for hotKeyRef in registrations.values {
            UnregisterEventHotKey(hotKeyRef)
        }
        registrations.removeAll()
        handlers.removeAll()
    }

    deinit {
        unregisterAll()
        removeEventHandlerIfNeeded()
    }

    private func installEventHandlerIfNeeded() throws {
        guard eventHandlerRef == nil else {
            return
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else {
                    return noErr
                }

                let hotKeyService = Unmanaged<HotKeyService>.fromOpaque(userData).takeUnretainedValue()
                hotKeyService.handleHotKeyEvent(event)
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard status == noErr else {
            eventHandlerRef = nil
            throw HotKeyServiceError.eventHandlerInstallationFailed(status)
        }
    }

    private func removeEventHandlerIfNeeded() {
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func handleHotKeyEvent(_ event: EventRef?) {
        guard let event,
              let receivedID = receivedHotKeyID(from: event),
              receivedID.signature == signature,
              let handler = handlers[receivedID.id] else {
            return
        }

        handler()
    }

    private func receivedHotKeyID(from event: EventRef) -> EventHotKeyID? {
        var receivedID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &receivedID
        )

        guard status == noErr else {
            return nil
        }

        return receivedID
    }
}
