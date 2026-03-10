import AppKit
import Foundation
import UserNotifications

private enum SaveNotificationUserDefaultsKey {
    static let reopenRecords = "saveNotifications.reopenRecords"
    static let badgeCount = "saveNotifications.badgeCount"
    static let lastScheduledPayload = "saveNotifications.lastScheduledPayload"
    static let pendingUITestReopenRecordID = "saveNotifications.pendingUITestReopenRecordID"
}

struct SaveNotificationStore {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func reopenRecord(for id: UUID) -> SaveReopenRecord? {
        storedReopenRecords()[id]
    }

    func saveReopenRecord(_ record: SaveReopenRecord) {
        var records = storedReopenRecords()
        records[record.id] = record
        pruneOldRecordsIfNeeded(&records)
        persist(records)
    }

    func lastScheduledPayload() -> SaveNotificationPayload? {
        guard let data = userDefaults.data(forKey: SaveNotificationUserDefaultsKey.lastScheduledPayload) else {
            return nil
        }

        return try? decoder.decode(SaveNotificationPayload.self, from: data)
    }

    func setPendingUITestReopenRecordID(_ recordID: UUID) {
        userDefaults.set(recordID.uuidString, forKey: SaveNotificationUserDefaultsKey.pendingUITestReopenRecordID)
        userDefaults.synchronize()
    }

    func pendingUITestReopenRecordID() -> UUID? {
        guard let rawValue = userDefaults.string(forKey: SaveNotificationUserDefaultsKey.pendingUITestReopenRecordID) else {
            return nil
        }

        return UUID(uuidString: rawValue)
    }

    func clearPendingUITestReopenRecordID() {
        userDefaults.removeObject(forKey: SaveNotificationUserDefaultsKey.pendingUITestReopenRecordID)
        userDefaults.synchronize()
    }

    func nextBadgeCount() -> Int {
        let count = userDefaults.integer(forKey: SaveNotificationUserDefaultsKey.badgeCount) + 1
        userDefaults.set(count, forKey: SaveNotificationUserDefaultsKey.badgeCount)
        return count
    }

    func recordLastScheduledPayload(_ payload: SaveNotificationPayload) {
        guard let data = try? encoder.encode(payload) else {
            return
        }

        userDefaults.set(data, forKey: SaveNotificationUserDefaultsKey.lastScheduledPayload)
        userDefaults.synchronize()
    }

    func resetForTesting() {
        userDefaults.removeObject(forKey: SaveNotificationUserDefaultsKey.reopenRecords)
        userDefaults.removeObject(forKey: SaveNotificationUserDefaultsKey.badgeCount)
        userDefaults.removeObject(forKey: SaveNotificationUserDefaultsKey.lastScheduledPayload)
        userDefaults.removeObject(forKey: SaveNotificationUserDefaultsKey.pendingUITestReopenRecordID)
        userDefaults.synchronize()
    }

    private func storedReopenRecords() -> [UUID: SaveReopenRecord] {
        guard let data = userDefaults.data(forKey: SaveNotificationUserDefaultsKey.reopenRecords),
              let records = try? decoder.decode([UUID: SaveReopenRecord].self, from: data) else {
            return [:]
        }

        return records
    }

    private func persist(_ records: [UUID: SaveReopenRecord]) {
        guard let data = try? encoder.encode(records) else {
            return
        }

        userDefaults.set(data, forKey: SaveNotificationUserDefaultsKey.reopenRecords)
        userDefaults.synchronize()
    }

    private func pruneOldRecordsIfNeeded(_ records: inout [UUID: SaveReopenRecord]) {
        let sortedRecords = records.values.sorted { $0.createdAt > $1.createdAt }
        guard sortedRecords.count > 20 else {
            return
        }

        let keptIDs = Set(sortedRecords.prefix(20).map(\.id))
        records = records.filter { keptIDs.contains($0.key) }
    }
}

@MainActor
final class SaveNotificationCoordinator {
    static let shared = SaveNotificationCoordinator(notificationCenter: .current())

    private let store: SaveNotificationStore
    private let notificationCenter: UNUserNotificationCenter?
    private var routingErrorHandler: ((String) -> Void)?

    init(
        userDefaults: UserDefaults = .standard,
        notificationCenter: UNUserNotificationCenter? = nil
    ) {
        self.store = SaveNotificationStore(userDefaults: userDefaults)
        self.notificationCenter = notificationCenter
    }

    func prepareSuccessNotification(for result: SaveOperationResult) -> SaveNotificationPayload {
        let reopenRecord = result.reopenRecord
        saveReopenRecord(reopenRecord)

        let payload = SaveNotificationPayload(
            reopenRecordID: reopenRecord.id,
            sourceSessionID: result.sourceSessionID,
            payload: result.payload,
            fingerprint: result.fingerprint,
            trackCount: result.trackCount
        )
        store.recordLastScheduledPayload(payload)

        return payload
    }

    func schedulePreparedSuccessNotification(_ payload: SaveNotificationPayload) async {
        do {
            guard let notificationCenter else {
                return
            }

            let settings = await notificationCenter.notificationSettings()
            let authorizationStatus = settings.authorizationStatus
            if authorizationStatus == .notDetermined {
                _ = try await notificationCenter.requestAuthorization(options: [.alert, .badge])
            }

            let updatedSettings = await notificationCenter.notificationSettings()
            guard updatedSettings.authorizationStatus == .authorized ||
                    updatedSettings.authorizationStatus == .provisional else {
                return
            }

            let badgeCount = store.nextBadgeCount()
            let content = UNMutableNotificationContent()
            content.title = notificationTitle(for: payload.payload)
            content.body = notificationBody(trackCount: payload.trackCount)
            content.badge = NSNumber(value: badgeCount)
            content.userInfo = try notificationUserInfo(for: payload)

            let request = UNNotificationRequest(
                identifier: payload.reopenRecordID.uuidString,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            )

            try await notificationCenter.add(request)
        } catch {}
    }

    func scheduleSuccessNotification(for result: SaveOperationResult) async {
        let payload = prepareSuccessNotification(for: result)
        await schedulePreparedSuccessNotification(payload)
    }

    func handleNotificationResponse(userInfo: [AnyHashable: Any]) {
        guard let payload = payload(from: userInfo) else {
            presentRoutingError("The save notification did not contain valid reopening data.")
            return
        }

        routeToSavedTracks(payload)
    }

    func handlePendingUITestRouteIfNeeded() {
        guard let reopenRecordID = store.pendingUITestReopenRecordID() else {
            return
        }

        store.clearPendingUITestReopenRecordID()

        guard let record = reopenRecord(for: reopenRecordID) else {
            return
        }

        routeToSavedTracks(
            SaveNotificationPayload(
                reopenRecordID: record.id,
                sourceSessionID: record.sourceSessionID,
                payload: record.payload,
                fingerprint: record.fingerprint,
                trackCount: record.trackCount
            )
        )
    }

    func reopenRecord(for id: UUID) -> SaveReopenRecord? {
        store.reopenRecord(for: id)
    }

    func saveReopenRecord(_ record: SaveReopenRecord) {
        store.saveReopenRecord(record)
    }

    func lastScheduledPayload() -> SaveNotificationPayload? {
        store.lastScheduledPayload()
    }

    func setPendingUITestReopenRecordID(_ recordID: UUID) {
        store.setPendingUITestReopenRecordID(recordID)
    }

    func setRoutingErrorHandlerForTesting(_ handler: ((String) -> Void)?) {
        routingErrorHandler = handler
    }

    private func routeToSavedTracks(_ payload: SaveNotificationPayload) {
        if let existingSession = EditorWindowCoordinator.shared.existingSession(forFingerprint: payload.fingerprint) {
            EditorWindowCoordinator.shared.openEditorWindow(for: existingSession)
            return
        }

        guard reopenRecord(for: payload.reopenRecordID) != nil else {
            presentRoutingError("The saved track details are no longer available.")
            return
        }

        EditorWindowCoordinator.shared.openEditorWindow(
            for: EditorSessionValue(reopenRecordID: payload.reopenRecordID)
        )
    }

    private func presentRoutingError(_ message: String) {
        if let routingErrorHandler {
            routingErrorHandler(message)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Unable to open saved tracks"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func payload(from userInfo: [AnyHashable: Any]) -> SaveNotificationPayload? {
        guard JSONSerialization.isValidJSONObject(userInfo),
              let data = try? JSONSerialization.data(withJSONObject: userInfo, options: []) else {
            return nil
        }

        return try? JSONDecoder().decode(SaveNotificationPayload.self, from: data)
    }

    private func notificationUserInfo(for payload: SaveNotificationPayload) throws -> [String: Any] {
        let data = try JSONEncoder().encode(payload)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        return object as? [String: Any] ?? [:]
    }

    private func notificationTitle(for payload: SavePayloadOption) -> String {
        switch payload {
        case .writeTags:
            return "Tags saved"
        case .writePictures:
            return "Pictures saved"
        case .writeTagsAndPictures:
            return "Tags and pictures saved"
        }
    }

    private func notificationBody(trackCount: Int) -> String {
        if trackCount == 1 {
            return "1 track was saved."
        }

        return "\(trackCount) tracks were saved."
    }

    func resetForTesting() {
        store.resetForTesting()
        routingErrorHandler = nil
    }
}
