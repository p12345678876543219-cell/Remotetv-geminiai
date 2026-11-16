import SwiftUI
import Network
import UIKit

@main
struct TVRemoteMainApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @StateObject private var remoteManager = TVRemoteManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 28) {
                // Header trạng thái tự động kết nối
                VStack(spacing: 8) {
                    Text("AUTO TV REMOTE")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(remoteManager.isConnected ? Color.green : Color.orange)
                            .frame(width: 9, height: 9)
                        Text(remoteManager.statusMessage)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color(white: 0.1))
                    .clipShape(Capsule())
                }
                .padding(.top, 20)
                
                Spacer()

                // Cụm phím điều hướng D-Pad (Lên - Xuống - Trái - Phải - OK)
                ZStack {
                    Circle()
                        .fill(Color(white: 0.12))
                        .frame(width: 260, height: 260)
                        .overlay(
                            Circle()
                                .stroke(Color.cyan.opacity(0.25), lineWidth: 1.5)
                        )
                        .shadow(color: Color.cyan.opacity(0.15), radius: 15)

                    // LÊN
                    RemoteButton(icon: "chevron.up", offsetY: -82) {
                        remoteManager.sendKey(.up)
                    }

                    // XUỐNG
                    RemoteButton(icon: "chevron.down", offsetY: 82) {
                        remoteManager.sendKey(.down)
                    }

                    // TRÁI
                    RemoteButton(icon: "chevron.left", offsetX: -82) {
                        remoteManager.sendKey(.left)
                    }

                    // PHẢI
                    RemoteButton(icon: "chevron.right", offsetX: 82) {
                        remoteManager.sendKey(.right)
                    }

                    // NÚT OK
                    Button(action: {
                        triggerHaptic(.heavy)
                        remoteManager.sendKey(.ok)
                    }) {
                        Text("OK")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(width: 88, height: 88)
                            .background(Color.cyan)
                            .clipShape(Circle())
                            .shadow(color: Color.cyan.opacity(0.5), radius: 8)
                    }
                }

                // Cụm phím chức năng phía dưới (Quay lại & Quét lại TV)
                HStack(spacing: 20) {
                    Button(action: {
                        triggerHaptic(.medium)
                        remoteManager.sendKey(.back)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("QUAY LẠI")
                        }
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 155, height: 50)
                        .background(Color(white: 0.16))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                        )
                    }

                    Button(action: {
                        triggerHaptic(.light)
                        remoteManager.rescan()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.cyan)
                            .frame(width: 50, height: 50)
                            .background(Color(white: 0.16))
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
                .padding(.top, 12)

                Spacer()
            }
            .padding()
        }
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

struct RemoteButton: View {
    let icon: String
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 76, height: 76)
                .contentShape(Rectangle())
        }
        .offset(x: offsetX, y: offsetY)
    }
}

// MARK: - Tự động quét và kết nối TV gần nhất
class TVRemoteManager: ObservableObject {
    @Published var isConnected = false
    @Published var statusMessage = "Đang tìm TV gần nhất..."
    
    private var browsers: [NWBrowser] = []
    private var activeConnection: NWConnection?
    private var connectedTVName: String?

    enum RemoteKey: String {
        case up = "KEY_UP"
        case down = "KEY_DOWN"
        case left = "KEY_LEFT"
        case right = "KEY_RIGHT"
        case ok = "KEY_ENTER"
        case back = "KEY_RETURN"
    }

    init() {
        startScanningForNearbyTV()
    }

    func rescan() {
        browsers.forEach { $0.cancel() }
        browsers.removeAll()
        activeConnection?.cancel()
        isConnected = false
        connectedTVName = nil
        statusMessage = "Đang quét lại TV..."
        startScanningForNearbyTV()
    }

    func startScanningForNearbyTV() {
        // Quét đồng thời các giao thức Smart TV phổ biến (Samsung, Android TV, Cast, AirPlay)
        let serviceTypes = [
            "_samsungmsf._tcp",
            "_androidtvremote2._tcp",
            "_googlecast._tcp",
            "_airplay._tcp"
        ]

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        for type in serviceTypes {
            let browser = NWBrowser(for: .bonjour(type: type, domain: "local."), using: parameters)
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                guard let self = self, !self.isConnected else { return }
                
                // Ưu tiên kết nối ngay với TV đầu tiên phản hồi nhanh nhất (gần nhất)
                if let nearestTV = results.first {
                    self.connectToTV(endpoint: nearestTV.endpoint)
                }
            }
            browser.start(queue: .main)
            browsers.append(browser)
        }
    }

    private func connectToTV(endpoint: NWEndpoint) {
        let name: String
        if case let .service(serviceName, _, _, _) = endpoint {
            name = serviceName
        } else {
            name = "Smart TV"
        }

        let connection = NWConnection(to: endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.connectedTVName = name
                    self?.statusMessage = "Đã kết nối: \(name)"
                case .failed(_), .cancelled:
                    if self?.connectedTVName == name {
                        self?.isConnected = false
                        self?.statusMessage = "Mất kết nối, đang tìm lại..."
                    }
                default:
                    break
                }
            }
        }
        connection.start(queue: .global())
        self.activeConnection = connection
    }

    func sendKey(_ key: RemoteKey) {
        guard let connection = activeConnection, isConnected else {
            // Nếu chưa kịp kết nối xong thì thử quét lại ngay
            if !isConnected { rescan() }
            return
        }

        // Đóng gói payload JSON tiêu chuẩn gửi qua socket tới TV
        let payload = "{\"method\":\"ms.remote.control\",\"params\":{\"Cmd\":\"Click\",\"DataOfCmd\":\"\(key.rawValue)\",\"Option\":\"false\",\"TypeOfRemote\":\"SendRemoteKey\"}}"
        if let data = payload.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed({ _ in }))
        }
    }
}
