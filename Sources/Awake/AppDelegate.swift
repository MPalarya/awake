import AppKit
import ServiceManagement
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let durationKey = "durationMinutes" // 0 = indefinitely
    private static let activeKey = "active"
    private static let durations: [(minutes: Int, title: String)] = [
        (0, "Indefinitely"),
        (15, "15 Minutes"),
        (30, "30 Minutes"),
        (60, "1 Hour"),
        (120, "2 Hours"),
        (240, "4 Hours"),
        (480, "8 Hours"),
    ]

    private let log = Logger(subsystem: "com.awake.app", category: "Awake")
    private let assertion = PowerAssertion()
    private var statusItem: NSStatusItem!
    private var expiryTimer: Timer?
    private var endDate: Date?

    private let toggleItem = NSMenuItem(title: "Keep Awake", action: #selector(toggle), keyEquivalent: "")
    private let untilItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private var durationItems: [NSMenuItem] = []

    private var duration: Int {
        get { UserDefaults.standard.integer(forKey: Self.durationKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.durationKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Self.durationKey: 0, Self.activeKey: false])

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.menu = buildMenu()

        // Resume an open-ended session across relaunches (e.g. Launch at Login); timed sessions don't resume.
        if UserDefaults.standard.bool(forKey: Self.activeKey) && duration == 0 {
            start()
        }
        updateIcon()

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)

        log.notice("Awake launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        assertion.release()
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        toggleItem.target = self
        loginItem.target = self
        untilItem.isEnabled = false

        menu.addItem(toggleItem)
        menu.addItem(untilItem)
        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Duration"))
        for (index, option) in Self.durations.enumerated() {
            let item = NSMenuItem(title: option.title, action: #selector(selectDuration), keyEquivalent: "")
            item.target = self
            item.tag = index
            durationItems.append(item)
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: "Quit Awake", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        toggleItem.state = assertion.isHeld ? .on : .off
        if let endDate {
            untilItem.title = "Until \(endDate.formatted(date: .omitted, time: .shortened))"
            untilItem.isHidden = false
        } else {
            untilItem.isHidden = true
        }
        let selected = duration
        for item in durationItems {
            item.state = Self.durations[item.tag].minutes == selected ? .on : .off
        }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    private func updateIcon() {
        let on = assertion.isHeld
        let image = NSImage(systemSymbolName: on ? "cup.and.saucer.fill" : "cup.and.saucer",
                            accessibilityDescription: on ? "Awake: on" : "Awake: off")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.appearsDisabled = !on
    }

    @objc private func toggle() {
        if assertion.isHeld { stop() } else { start() }
    }

    /// Picking a duration starts a session, or restarts the countdown if one is already running.
    @objc private func selectDuration(_ sender: NSMenuItem) {
        duration = Self.durations[sender.tag].minutes
        if assertion.isHeld { scheduleExpiry() } else { start() }
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                log.notice("Launch at Login disabled")
            } else {
                try service.register()
                log.notice("Launch at Login enabled")
            }
        } catch {
            log.error("Launch at Login failed: \(error.localizedDescription, privacy: .public)")
            if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        }
    }

    // MARK: - Session

    private func start() {
        guard assertion.acquire() else {
            log.error("Could not create power assertion")
            return
        }
        UserDefaults.standard.set(true, forKey: Self.activeKey)
        scheduleExpiry()
        updateIcon()
        log.notice("Keeping awake (\(self.duration == 0 ? "indefinitely" : "\(self.duration) min", privacy: .public))")
    }

    private func stop() {
        assertion.release()
        expiryTimer?.invalidate()
        expiryTimer = nil
        endDate = nil
        UserDefaults.standard.set(false, forKey: Self.activeKey)
        updateIcon()
        log.notice("Allowing sleep")
    }

    private func scheduleExpiry() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        endDate = nil
        guard duration > 0 else { return }
        armTimer(until: .now + TimeInterval(duration * 60))
    }

    /// One timer per session; nothing ticks in between.
    private func armTimer(until end: Date) {
        endDate = end
        let timer = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        expiryTimer = timer
    }

    // MARK: - Sleep / wake

    /// Timers don't count time spent asleep (e.g. lid closed on battery), so re-check the deadline against the wall clock.
    @objc private func didWake(_ note: Notification) {
        guard let endDate else { return }
        expiryTimer?.invalidate()
        if endDate <= .now { stop() } else { armTimer(until: endDate) }
    }
}
