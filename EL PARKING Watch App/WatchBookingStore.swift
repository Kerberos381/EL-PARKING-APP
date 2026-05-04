// WatchBookingStore.swift
// EL PARKING Watch App
// Receives booking data from the iPhone via WatchConnectivity and stores it
// in the shared App Group so the complication widget can read it.

import Foundation
import WatchConnectivity
import WidgetKit

// App Group shared between Watch App + Watch Widget Extension.
private let suiteName = "group.com.StivMalakjan.EL-PARKING-WATCH"

class WatchBookingStore: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchBookingStore()

    @Published var spot:     String? = nil
    @Published var fromTime: String? = nil
    @Published var toTime:   String? = nil
    @Published var isToday:  Bool    = false

    private override init() {
        // Restore last received values on launch.
        let d = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        self.spot     = d.string(forKey: "watch_spot")
        self.fromTime = d.string(forKey: "watch_fromTime")
        self.toTime   = d.string(forKey: "watch_toTime")
        self.isToday  = d.bool(forKey: "watch_isToday")
        super.init()

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        let spot     = userInfo["spot"]     as? String
        let fromTime = userInfo["fromTime"] as? String
        let toTime   = userInfo["toTime"]   as? String
        let isToday  = userInfo["isToday"]  as? Bool ?? false

        let d = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        d.set(spot,     forKey: "watch_spot")
        d.set(fromTime, forKey: "watch_fromTime")
        d.set(toTime,   forKey: "watch_toTime")
        d.set(isToday,  forKey: "watch_isToday")

        DispatchQueue.main.async {
            self.spot     = spot
            self.fromTime = fromTime
            self.toTime   = toTime
            self.isToday  = isToday
            // Reload complication timelines so the watch face updates immediately.
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}
}
