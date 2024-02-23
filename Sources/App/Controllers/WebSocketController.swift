//
//  WebSocketController.swift
//  RealTimeMessengerAPI
//
//  Created by Dmitriy Permyakov on 19.02.2024.
//

import Vapor

// MARK: - WebSocketController

final class WebSocketController: RouteCollection {

    // MARK: Private Values

    private var wsClients: Set<Client> = Set()

    // MARK: Router

    func boot(routes: RoutesBuilder) throws {

        // Groups
        let apiGroup = routes.grouped("api", "v1")
        let messageGroup = apiGroup.grouped("message")

        // HTTP
        messageGroup.post(use: handleMessageFromExternalService)
        messageGroup.post("proxy", use: proxyExternalService)

        // WebSocket
        routes.webSocket("socket", onUpgrade: handleSocketUpgrade)
    }
}

// MARK: - Web Sockets

private extension WebSocketController {

    func handleSocketUpgrade(req: Request, ws: WebSocket) {
        Logger.log(message: "Подключение")

        ws.onText { [weak self] ws, text in
            guard let self, let data = text.data(using: .utf8) else {
                Logger.log(kind: .error, message: "Неверный привод типа `text.data(using: .utf8)`")
                return
            }

            do {
                let msgKind = try JSONDecoder().decode(MessageAbstract.self, from: data)

                switch msgKind.kind {
                case .connection:
                    try connectionHandler(ws: ws, data: data)

                case .message:
//                    try messageHandler(ws: ws, data: data)
                    try messageHandlerWithService(ws: ws, data: data)

                case .close:
                    break
                }

            } catch {
                Logger.log(kind: .error, message: error)
            }
        }

        ws.onClose.whenComplete { [weak self] _ in
            guard let self, let key = wsClients.first(where: { $0.ws === ws })?.userName else { return }
            do {
                try closeHandler(ws: ws, key: key)
            } catch {
                Logger.log(kind: .error, message: error)
            }
        }
    }

    func connectionHandler(ws: WebSocket, data: Data) throws {
        let msg = try JSONDecoder().decode(Message.self, from: data)
        let newClient = Client(ws: ws, userName: msg.userName)
        wsClients.insert(newClient)
        let msgConnection = Message(
            id: UUID(),
            kind: .connection,
            userName: msg.userName,
            dispatchDate: Date(),
            message: "",
            state: .received
        )
        let msgConnectionString = try msgConnection.encodeMessage()
        Logger.log(kind: .connection, message: "Пользователь с ником: [ \(msg.userName) ] добавлен в сессию")
        wsClients.forEach {
            $0.ws.send(msgConnectionString)
        }
    }

    @available(*, deprecated, renamed: "messageHandlerWithService", message: "Этот метод устарел. Теперь используется http сервис")
    func messageHandler(ws: WebSocket, data: Data) throws {
        var msg = try JSONDecoder().decode(Message.self, from: data)
        msg.state = [.error, .received, .received].randomElement()!
        let jsonString = try msg.encodeMessage()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Если обнаружена ошибка, сообщаем только пользователю
            switch msg.state {
            case .error:
                ws.send(jsonString)
            default:
                self.wsClients.forEach {
                    Logger.log(kind: .message, message: msg)
                    $0.ws.send(jsonString)
                }
            }
        }
    }

    func messageHandlerWithService(ws: WebSocket, data: Data) throws {
        let msg = try JSONDecoder().decode(Message.self, from: data)
        sendMessageToExternalService(message: msg) { result in
            switch result {
            case .success:
                Logger.log(kind: .info, message: "Сообщение успешно доставленно на сервис транспортного уровня")
            case let .failure(error):
                Logger.log(kind: .error, message: error.localizedDescription)
            }
        }
    }

    func closeHandler(ws: WebSocket, key: String) throws {
        guard let deletedClient = wsClients.remove(Client(ws: ws, userName: key)) else {
            Logger.log(kind: .error, message: "Не удалось удалить пользователя: [ \(key) ]")
            return
        }

        Logger.log(kind: .close, message: "Пользователь с ником: [ \(deletedClient.userName) ] удалён из очереди")
        let msgConnection = Message(
            id: UUID(),
            kind: .close,
            userName: key,
            dispatchDate: Date(),
            message: "",
            state: .received
        )
        let msgConnectionString = try msgConnection.encodeMessage()
        wsClients.forEach {
            $0.ws.send(msgConnectionString)
        }
    }
}

// MARK: - HTTP

private extension WebSocketController {

    func handleMessageFromExternalService(_ req: Request) async throws -> ServerResponse {
        let httpMessage = try req.content.decode(HttpMessage.self)
        guard let uid = UUID(uuidString: httpMessage.uid) else {
            throw Abort(.custom(code: HTTPResponseStatus.badRequest.code, 
                                reasonPhrase: "UUID не корректен"))
        }
        guard let ws = wsClients.first(where: { $0.userName == httpMessage.userName }) else {
            throw Abort(.custom(code: HTTPResponseStatus.internalServerError.code, 
                                reasonPhrase: "Пользователь: \(httpMessage.userName) не найден в сессии"))
        }

        // FIXME: Заменить на код Никиты, когда сервис транспортного уровня будет добавлен
        let msgState: MessageState = httpMessage.errorCode == "200" ? .received : .error
        let msg = Message(
            id: uid,
            kind: .message,
            userName: httpMessage.userName,
            dispatchDate: Date(),
            message: httpMessage.message,
            state: msgState
        )
        let msgString = try msg.encodeMessage()
        switch msg.state {
        case .error:
            try await ws.ws.send(msgString)
        default:
            wsClients.forEach {
                $0.ws.send(msgString)
            }
        }

        return ServerResponse(
            status: HTTPResponseStatus.ok.code,
            description: "Пользователь: \(httpMessage.userName) получил сообщение: \(httpMessage.message)"
        )
    }

    func sendMessageToExternalService(message: Message, completion: @escaping MKResultBlock<Bool, KingError>) {
        let uidString = message.id.uuidString
        let httpMessage = HttpMessage(
            uid: uidString,
            message: message.message,
            userName: message.userName,
            errorCode: nil
        )
        let msgData: Data
        do {
            msgData = try httpMessage.encodeMessage()
        } catch {
            completion(.failure(.error(error)))
            return
        }

        // FIXME: Заменить на URL Влада
        let externalServiceURL = "http://127.0.0.1:8080/api/v1/message/proxy"
        APIManager.shared.post(urlString: externalServiceURL, msgData: msgData, completion: completion)
    }
    
    /// Ручка, имитирующая работу сервиса Влада на трансортном уровне.
    func proxyExternalService(_ req: Request) async throws -> String {
        let msg = try req.content.decode(HttpMessage.self)
        Logger.log(message: "Имитация работы сервиса транспортного уровня. Полученно сообщение: \(msg)")
        sleep(1)
        let errorCode = ["200", "300"].randomElement()!
        let msgWithErrorStatus = HttpMessage(uid: msg.uid, message: msg.message, userName: msg.userName, errorCode: errorCode)
        let msgData: Data = try msgWithErrorStatus.encodeMessage()
        APIManager.shared.post(
            urlString: "http://127.0.0.1:8080/api/v1/message",
            msgData: msgData
        ) { result in
            switch result {
            case .success:
                Logger.log(message: "Успешно отправлены данные назад")
            case let .failure(error):
                Logger.log(kind: .error, message: error.localizedDescription)
            }
        }
        return "Закончил отправку"
    }
}
