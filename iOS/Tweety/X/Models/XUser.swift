//
//  XUser.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/14/25.
//

struct XUser: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let username: String
    let profile_image_url: String?
}
