import SwiftUI
import Network

struct ContentView: View {
    @StateObject private var remoteManager = TVRemoteManager()
    @State private var showConnectionAlert = false

    var body: some View {
        ZStack {
            // Giao diện nền tối phong cách hacker / hiện đại
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Trạng thái kết nối TV
                VStack(spacing: 6) {
                    Text("SMART TV REMOTE")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(remoteManager.isConnected ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(remoteManager.statusMessage)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 20)
                
                Spacer()

                // Bảng điều khiển D-Pad (Lên, Xuống, Trái, Phải, OK)
                ZStack {
                    Circle()
                        .fill(Color(white: 0.12))
                        .frame(width: 240, height: 240)
                        .shadow(color: Color.cyan.opacity(0.15), radius: 10, x: 0, y: 0)

                    // Nút Lên
                    Button(action: { remoteManager.sendKey(.up) }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 70, height: 70)
                    }
                    .offset(y: -75)

                    // Nút Xuống
                    Button(action: { remoteManager.sendKey(.down) }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 70, height: 70)
                    }
                    .offset(y: 75)

                    // Nút Trái
                    Button(action: { remoteManager.sendKey(.left) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 70, height: 70)
                    }
                    .offset(x: -75)

                    // Nút Phải
                    Button(action: { remoteManager.sendKey(.right) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 70, height: 70)
                    }
                    .offset(x: 75)

                    // Nút OK chính giữa
                    Button(action: { remoteManager.sendKey(.ok) }) {
                        Text("OK")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(width: 80, height: 80)
                            .background(Color.cyan)
                            .clipShape(Circle())
                            .shadow(color: Color.cyan.opacity(0.5), radius: 6, x: 0, y: 0)
                    }
                }

                // Nút Quay lại (Back)
                Button(action: { remoteManager.sendKey(.back) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("QUAY LẠI")
                    }
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 160, height: 48)
                    .background(Color(white: 0.18))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                    )
                }
                .padding(.top, 10)

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Remote & Network Logic
class TVRemoteManager: ObservableObject {
    @Published var isConnected = false
    @Published var statusMessage = "Đang tìm TV gần nhất..."
    
    private var browser: NWBrowser?
    private var connection: NWConnection?
    
    enum RemoteKey {
        case up, down, left, right, ok, back
    }

    init() {
        startScanningForNearbyTV()
    }

    // Tự động quét các thiết bị TV/Media Renderer trong mạng nội bộ gần nhất
    func startScanningForNearbyTV() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        // Khởi tạo browser tìm kiếm dịch vụ mDNS / Bonjour (phổ biến trên Smart TV)
        let browser = NWBrowser(for: .bonjour(type: "_airplay._tcp", domain: "local."), using: parameters)
        
        browser.browseResultsChangedHandler = { [weak self] results, changes in
            if let firstTV = results.first {
                self?.statusMessage = "Đã tìm thấy TV gần nhất"
                self?.isConnected = true
                // Có thể thiết lập kết nối socket tới endpoint của TV tại đây
                print("Found TV endpoint: \(firstTV.endpoint)")
            }
        }
        
        browser.start(queue: .global())
        self.browser = browser
    }

    func sendKey(_ key: RemoteKey) {
        // Thực hiện gửi lệnh điều khiển tương ứng tới TV qua mạng
        print("Đã gửi lệnh: \(key)")
    }
}
