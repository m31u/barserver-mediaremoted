import Foundation
import PrivateMediaRemote

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
            getCurrentPlayer()
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
                getCurrentPlayer()
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

    func getCurrentPlayer() {
        MRMediaRemoteGetNowPlayingClient(DispatchQueue.main) { [self] client in
            guard let client = client, let clientName = client.displayName else {
                print("Client not retrieved")
                return
            }

            guard let ws = ws else {
                print("Websocket connection no initialized")
                return
            }

            ws.send(data: ["type": "UPDATE_CURRENT_PLAYER", "data": clientName])
        }
    }

}

let remote = MediaRemoteManager()

RunLoop.main.run()
