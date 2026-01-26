//
//  AnalyticsEvent.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/25/26.
//

import Foundation

protocol AnalyticsEvent: Encodable {
    static var name: String { get }
}
