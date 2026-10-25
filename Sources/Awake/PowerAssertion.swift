import IOKit.pwr_mgt

/// An IOKit power assertion that blocks idle display and system sleep, the same thing `caffeinate -d` does.
/// While it is held, the app does no work at all: the kernel enforces it, and the OS frees it if the process exits.
@MainActor
final class PowerAssertion {
    private var id = IOPMAssertionID(kIOPMNullAssertionID)

    var isHeld: Bool { id != IOPMAssertionID(kIOPMNullAssertionID) }

    /// Returns false if the assertion could not be created.
    func acquire() -> Bool {
        guard !isHeld else { return true }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Awake is keeping this Mac awake" as CFString,
            &id)
        guard result == kIOReturnSuccess else {
            id = IOPMAssertionID(kIOPMNullAssertionID)
            return false
        }
        return true
    }

    func release() {
        guard isHeld else { return }
        IOPMAssertionRelease(id)
        id = IOPMAssertionID(kIOPMNullAssertionID)
    }
}
