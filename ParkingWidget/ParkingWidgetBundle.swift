//
//  ParkingWidgetBundle.swift
//  ParkingWidget
//
//  Widget bundle: Home Screen widgets.
//

import WidgetKit
import SwiftUI

@main
struct ParkingWidgetBundle: WidgetBundle {
    var body: some Widget {
        ParkingHomeWidget()
        ParkingHomeWidgetLight()
        ParkingVehicleIdentityWidget()
        ParkingTimelineCardWidget()
        ParkingLockWidget()
    }
}
