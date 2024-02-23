//
//  Client.swift
//
//
//  Created by Dmitriy Permyakov on 23.02.2024.
//

import Vapor

struct Client: Hashable {
    var ws: WebSocket
    var userName: String
}

// MARK: - Hashable

extension Client {

    static func == (lhs: Client, rhs: Client) -> Bool {
        lhs.userName == rhs.userName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(userName)
    }
}
