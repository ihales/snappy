import Combine
import ServiceManagement

@MainActor
final class LoginItemManager: ObservableObject {
    @Published private(set) var isRegistered = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var statusUnavailable = false
    @Published private(set) var lastError: String?

    private var service: SMAppService { .mainApp }

    init() {
        refresh()
    }

    func setRegistered(_ shouldRegister: Bool) {
        lastError = nil
        var operationError: Error?

        do {
            if shouldRegister {
                guard service.status != .enabled, service.status != .requiresApproval else {
                    refresh()
                    return
                }
                try service.register()
            } else {
                guard service.status != .notRegistered, service.status != .notFound else {
                    refresh()
                    return
                }
                try service.unregister()
            }
        } catch {
            operationError = error
        }

        refresh()
        if let operationError, !requiresApproval {
            lastError = operationError.localizedDescription
        }
    }

    func refresh() {
        lastError = nil
        switch service.status {
        case .enabled:
            isRegistered = true
            requiresApproval = false
            statusUnavailable = false
        case .requiresApproval:
            isRegistered = true
            requiresApproval = true
            statusUnavailable = false
        case .notRegistered:
            isRegistered = false
            requiresApproval = false
            statusUnavailable = false
        case .notFound:
            // A fresh main-app login item may not have a Background Task
            // Management record until register() is called. Keep the toggle
            // actionable so registration can create that record and report
            // any real signing or authorization error.
            isRegistered = false
            requiresApproval = false
            statusUnavailable = false
        @unknown default:
            isRegistered = false
            requiresApproval = false
            statusUnavailable = true
        }
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
