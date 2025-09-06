import Foundation

class WebSocketDaemonClient: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private var url: String
    private var ws: URLSessionWebSocketTask?
    private var currentState: () -> Void

    init(_ serverUrl: String, _ currentStateCallback: @escaping () -> Void) {
        url = serverUrl
        currentState = currentStateCallback
        super.init()
        connect(withURL: self.url)
    }

    func urlSession(
        _ session: URLSession, webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        currentState()
        receive()
    }

    func connect(withURL url: String) {
        guard let url = URL(string: url) else {
            print("Invalid url client not initialized")
            return
        }

        ws = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
            .webSocketTask(with: url)

        if let ws = ws {
            ws.resume()
        }
    }

    func send(data: [String: Any]) {
        guard let ws = ws else {
            print("couldn't send, Websocket task not initialized")
            return
        }

        guard let json = try? JSONSerialization.data(withJSONObject: data) else {
            print("couldn't serialize message")
            return
        }

        guard let payload = String(data: json, encoding: .utf8) else {
            print("couldn't serialize message")
            return
        }

        ws.send(URLSessionWebSocketTask.Message.string(payload)) { error in
            if let error = error {
                print("error sending message \(error)")
            }
        }
    }

    func receive() {
        guard let ws = ws else {
            print("couldn't receive, Websocket task not initialized")
            return
        }

        ws.receive { [self] result in
            switch result {
            case .success:
                currentState()
                receive()
                break
            case .failure:
                connect(withURL: url)
                break
            }
        }
    }
}
