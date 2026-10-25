import BackgroundTasks
import Foundation
import SwiftData

/// Expiry, Recently Deleted and the 30-day purge. Runs on launch, whenever the app becomes active,
/// when the pin list appears, and opportunistically in the background. It never depends on running
/// at an exact time: each run catches up on everything that's due.
@MainActor
final class RetentionService {
    static let shared = RetentionService(context: SharedStore.context)

    struct Summary: Equatable {
        var expired = 0
        var purged = 0
        /// True when the run was put off because an export was in progress.
        var deferred = false
    }

    private let context: ModelContext
    private var pauseCount = 0
    private var deferredRun: (now: Date, keepIndefinitely: Bool)?

    init(context: ModelContext) {
        self.context = context
    }

    /// Moves expired pins to Recently Deleted and permanently removes pins that have been there 30 days.
    @discardableResult
    func run(now: Date = AppClock.now, keepIndefinitely: Bool = AppSettings.keepIndefinitely) -> Summary {
        guard pauseCount == 0 else {
            deferredRun = (now, keepIndefinitely)
            return Summary(deferred: true)
        }
        var summary = Summary()

        let inRecentlyDeleted = FetchDescriptor<Pin>(predicate: #Predicate { $0.deletedAt != nil })
        for pin in (try? context.fetch(inRecentlyDeleted)) ?? [] {
            if let deletedAt = pin.deletedAt, RetentionPolicy.shouldPurge(deletedAt: deletedAt, now: now) {
                context.delete(pin)
                summary.purged += 1
            }
        }

        if !keepIndefinitely {
            let activeUnkept = FetchDescriptor<Pin>(predicate: #Predicate { $0.deletedAt == nil && $0.isKept == false })
            for pin in (try? context.fetch(activeUnkept)) ?? [] {
                if RetentionPolicy.shouldExpire(capturedAt: pin.capturedAt, isKept: pin.isKept, keepIndefinitely: keepIndefinitely, now: now) {
                    // Stamped with when it moved, not when it hit 7 days, so every pin gets its full
                    // 30 days in Recently Deleted, even after a long break or after turning off
                    // "Keep records indefinitely".
                    pin.deletedAt = now
                    summary.expired += 1
                }
            }
        }

        if summary.expired > 0 || summary.purged > 0 {
            save()
        }
        return summary
    }

    func moveToRecentlyDeleted(_ pin: Pin, now: Date = AppClock.now) {
        moveToRecentlyDeleted([pin], now: now)
    }

    /// Several at once (Select in the Pins list), saved together.
    func moveToRecentlyDeleted(_ pins: [Pin], now: Date = AppClock.now) {
        for pin in pins {
            pin.deletedAt = now
        }
        save()
    }

    func recover(_ pin: Pin, now: Date = AppClock.now) {
        if RetentionPolicy.keepOnRecover(capturedAt: pin.capturedAt, now: now) {
            pin.isKept = true
        }
        pin.deletedAt = nil
        save()
    }

    func deleteNow(_ pin: Pin) {
        context.delete(pin)
        save()
    }

    func emptyRecentlyDeleted() {
        let inRecentlyDeleted = FetchDescriptor<Pin>(predicate: #Predicate { $0.deletedAt != nil })
        for pin in (try? context.fetch(inRecentlyDeleted)) ?? [] {
            context.delete(pin)
        }
        save()
    }

    /// Runs `work` with retention paused, so an export never races a clean-up.
    /// A clean-up requested meanwhile runs right after.
    func whilePaused<T>(_ work: () throws -> T) rethrows -> T {
        pauseCount += 1
        defer {
            pauseCount -= 1
            if pauseCount == 0, let request = deferredRun {
                deferredRun = nil
                run(now: request.now, keepIndefinitely: request.keepIndefinitely)
            }
        }
        return try work()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            print("Passing: retention save failed: \(error)")
        }
    }
}

/// The time retention and the expiry countdowns use.
enum AppClock {
    static var now: Date {
        #if DEBUG
        // Settings → Testing can push the clock forward to try the 7- and 30-day rules without
        // waiting. Debug builds only; the App Store build always uses the real time.
        let days = UserDefaults.standard.integer(forKey: SettingsKey.debugDayOffset)
        return Date().addingTimeInterval(TimeInterval(days) * RetentionPolicy.day)
        #else
        return Date()
        #endif
    }
}

/// Opportunistic background clean-up. iOS decides when (or whether) it runs, which is fine:
/// the next launch or return to the app catches up anyway.
enum RetentionScheduler {
    /// Must match `BGTaskSchedulerPermittedIdentifiers` in Support/Info.plist.
    static let taskIdentifier = (Bundle.main.bundleIdentifier ?? "com.example.passing") + ".retention"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Expected in the Simulator, which doesn't run background refresh.
            print("Passing: couldn't schedule background clean-up: \(error)")
        }
    }

    @MainActor
    static func handleAppRefresh() {
        RetentionService.shared.run()
        schedule()
    }
}
