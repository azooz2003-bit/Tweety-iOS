//
//  AnalyticsManager.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/25/26.
//

import Foundation
import FirebaseAnalytics

final class AnalyticsManager {
    static func log(_ event: AppEvent) {
        let concreteEvent = event.event
        let encoder = JSONEncoder()

        guard let eventData = try? encoder.encode(concreteEvent),
              var eventParams = eventData.toDictionary() else {
            return
        }

        guard let genericData = try? encoder.encode(GenericProperties.current),
              let genericParams = genericData.toDictionary() else {
            return
        }

        eventParams.merge(genericParams) { eventValue, _ in eventValue }

        let eventName = type(of: concreteEvent).name
        Analytics.logEvent(eventName, parameters: eventParams)
    }
}

extension Data {
    func toDictionary() -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: self) as? [String: Any]
    }
}
