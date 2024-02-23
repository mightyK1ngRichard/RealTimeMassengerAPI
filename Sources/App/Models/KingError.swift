//
//  KingError.swift
//
//
//  Created by Dmitriy Permyakov on 23.02.2024.
//

import Foundation

enum KingError: Error {
    case dataToString
    case dataIsNil(String? = nil)
    case error(Error)

    var localizedDescription: String {
        switch self {
        case .dataToString:
            return "Не получилось закодировать Data в строку"
        case let .error(error):
            return error.localizedDescription
        case let .dataIsNil(message):
            return message ?? "Data is nil"
        }
    }
}
