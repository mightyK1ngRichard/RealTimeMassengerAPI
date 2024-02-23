//
//  DispatchQueue+Extenstions.swift
//  RealTimeMessengerAPI
//
//  Created by Dmitriy Permyakov on 23.02.2024.
//

import Foundation

func asyncMain(execute: @escaping MKRVoidBlock) {
    DispatchQueue.main.async(execute: execute)
}
