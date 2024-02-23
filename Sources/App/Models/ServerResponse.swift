//
//  ServerResponse.swift
//  RealTimeMessengerAPI
//
//  Created by Dmitriy Permyakov on 23.02.2024.
//

import Vapor

struct ServerResponse: Content {
    let status: UInt
    let description: String
}
