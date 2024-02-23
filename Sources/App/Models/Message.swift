//
//  Message.swift
//  RealTimeMessengerAPI
//
//  Created by Dmitriy Permyakov on 23.02.2024.
//

import Vapor

struct MessageAbstract: Codable {
    let kind: MessageKind
}

struct Message: Codable {
    let id: UUID
    let kind: MessageKind
    let userName: String
    let dispatchDate: Date
    let message: String
    var state: MessageState
}

struct HttpMessage: Content, Codable {
    let uid: String
    let message: String
    let userName: String
    let errorCode: String?
}

enum MessageKind: String, Codable {
    case connection
    case close
    case message
}

enum MessageState: String, Codable {
    case progress
    case received
    case error
}

// MARK: - Encode

extension Message {

    func encodeMessage() throws -> String {
        let msgData = try JSONEncoder().encode(self)
        guard let msgString = String(data: msgData, encoding: .utf8) else {
            throw KingError.dataToString
        }
        return msgString
    }
}

extension HttpMessage {

    func encodeMessage() throws -> String {
        let msgData = try JSONEncoder().encode(self)
        guard let msgString = String(data: msgData, encoding: .utf8) else {
            throw KingError.dataToString
        }
        return msgString
    }

    func encodeMessage() throws -> Data {
        try JSONEncoder().encode(self)
    }
}
