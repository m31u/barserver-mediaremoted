import Foundation
import PrivateMediaRemote

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

struct MediaInfo {
    var Title: String
    var Artist: String
    var Album: String

    init(withInfo info: [AnyHashable: Any]) {
        Title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? "NONE"
        Artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "NONE"
        Album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? "NONE"
    }
}

class MediaRemoteManager {
    private var ws: WebSocketDaemonClient?

    init() {
        MRMediaRemoteRegisterForNowPlayingNotifications(DispatchQueue.main)

        observeNotification(
            withNotification: NSNotification.Name.mrMediaRemoteNowPlayingInfoDidChange
        ) { [self] in
            getNowPlayingInfo()
        }

        observeNotification(
            withNotification: NSNotification.Name
                .mrMediaRemoteNowPlayingApplicationIsPlayingDidChange
        ) { [self] in
            getIsNowPlaying()
        }

        waitForHeartbeat()

    }

    func waitForHeartbeat() {
        guard let url = URL(string: "http://localhost:3000/heartbeat") else {
            return
        }
        let req = URLRequest(url: url)

        let task = URLSession.shared.dataTask(with: req) { [self] _, _, err in
            if err != nil {
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + 5.0, execute: waitForHeartbeat)
                return
            }

            ws = WebSocketDaemonClient("ws://localhost:3000/daemon?name=networkd") {
                [self] in
                getNowPlayingInfo()
                getIsNowPlaying()
            }
        }

        task.resume()
    }

    func observeNotification(
        withNotification name: NSNotification.Name, withHandler handler: @escaping () -> Void
    ) {
        NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { _ in
            handler()
        }
    }

    func sendInfo(_ info: MediaInfo) {
        print(info)
        guard let ws = ws else {
            return
        }
        let data = [
            "title": info.Title,
            "artist": info.Artist,
            "album": info.Album,
        ]

        ws.send(data: ["type": "UPDATE_NOW_PLAYING", "data": data])
    }

    func getNowPlayingInfo() {
        MRMediaRemoteGetNowPlayingInfo(DispatchQueue.main) { [self] info in
            if let info = info {
                sendInfo(MediaInfo(withInfo: info))
            }
        }
    }

    func getIsNowPlaying() {
        MRMediaRemoteGetNowPlayingApplicationIsPlaying(DispatchQueue.main) { [self] isPlaying in
            guard let ws = ws else {
                return
            }

            ws.send(data: ["type": "UPDATE_IS_NOW_PLAYING", "data": isPlaying])
        }
    }
}

let remote = MediaRemoteManager()

RunLoop.main.run()
