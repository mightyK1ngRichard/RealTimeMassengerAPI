//
//  APIManager.swift
//  RealTimeMessengerAPI
//
//  Created by Dmitriy Permyakov on 23.02.2024.
//

import Foundation

final class APIManager {
    static let shared = APIManager()
    private init() {}

    func post(urlString: String, msgData: Data, completion: @escaping MKResultBlock<Bool, KingError>) {
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = APIMethod.post.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = msgData
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                asyncMain() {
                    completion(.failure(.error(error)))
                }
                return
            }
            guard data != nil else {
                asyncMain() {
                    completion(.failure(.dataIsNil("Данные с сервиса: \(urlString) is nil")))
                }
                return
            }
            completion(.success(true))
        }.resume()
    }
}

// MARK: - APIMethods

extension APIManager {

    enum APIMethod: String {
        case get
        case post

        var method: String {
            return self.rawValue.uppercased()
        }
    }
}
