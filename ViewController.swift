import SwiftUI
import Network
import PhotosUI
import UIKit

@main
struct TVRemoteMainApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Main Tab Bar View
struct MainTabView: View {
    @StateObject private var remoteManager = TVRemoteManager()

    var body: some View {
        TabView {
            // TAB 1: ĐIỀU KHIỂN
            RemoteControlView(remoteManager: remoteManager)
                .tabItem {
                    Label("Điều khiển", systemImage: "gamecontroller.fill")
                }

            // TAB 2: DANH SÁCH THIẾT BỊ & ĐỔI TÊN
            DeviceListView(remoteManager: remoteManager)
                .tabItem {
                    Label("Thiết bị", systemImage: "tv.fill")
                }

            // TAB 3: TRUYỀN ẢNH LÊN TV
            CastImageView(remoteManager: remoteManager)
                .tabItem {
                    Label("Truyền ảnh", systemImage: "photo.fill.on.rectangle.fill")
                }
        }
        .accentColor(.cyan)
    }
}

// MARK: - Tab 1: Giao diện Điều khiển
struct RemoteControlView: View {
    @ObservedObject var remoteManager: TVRemoteManager

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header trạng thái
                VStack(spacing: 6) {
                    Text("SMART TV REMOTE")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(remoteManager.isConnected ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(remoteManager.statusMessage)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color(white: 0.1))
                    .clipShape(Capsule())
                }
                .padding(.top, 10)
                
                Spacer()

                // Cụm phím D-Pad
                ZStack {
                    Circle()
                        .fill(Color(white: 0.12))
                        .frame(width: 250, height: 250)
                        .overlay(Circle().stroke(Color.cyan.opacity(0.2), lineWidth: 1.5))
                        .shadow(color: Color.cyan.opacity(0.12), radius: 12)

                    RemoteButton(icon: "chevron.up", offsetY: -80) { remoteManager.sendKey(.up) }
                    RemoteButton(icon: "chevron.down", offsetY: 80) { remoteManager.sendKey(.down) }
                    RemoteButton(icon: "chevron.left", offsetX: -80) { remoteManager.sendKey(.left) }
                    RemoteButton(icon: "chevron.right", offsetX: 80) { remoteManager.sendKey(.right) }

                    Button(action: {
                        triggerHaptic(.heavy)
                        remoteManager.sendKey(.ok)
                    }) {
                        Text("OK")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(width: 84, height: 84)
                            .background(Color.cyan)
                            .clipShape(Circle())
                            .shadow(color: Color.cyan.opacity(0.4), radius: 6)
                    }
                }

                // Nút Quay lại
                Button(action: {
                    triggerHaptic(.medium)
                    remoteManager.sendKey(.back)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("QUAY LẠI")
                    }
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 150, height: 46)
                    .background(Color(white: 0.16))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.4), lineWidth: 1))
                }

                Spacer()
            }
            .padding()
        }
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
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
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 72, height: 72)
                .contentShape(Rectangle())
        }
        .offset(x: offsetX, y: offsetY)
    }
}

// MARK: - Tab 2: Danh sách thiết bị & Đổi tên
struct DeviceModel: Identifiable, Hashable {
    let id = UUID()
    let originalName: String
    let endpoint: NWEndpoint
    
    var key: String {
        if case let .service(name, _, _, _) = endpoint {
            return "tv_name_\(name)"
        }
        return "tv_name_\(endpoint.debugDescription)"
    }
    
    var customName: String {
        get { UserDefaults.standard.string(forKey: key) ?? originalName }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

struct DeviceListView: View {
    @ObservedObject var remoteManager: TVRemoteManager
    @State private var editingDevice: DeviceModel?
    @State private var newNameText = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    Section(header: Text("Thiết bị trong mạng nội bộ").font(.system(size: 12, design: .monospaced)).foregroundColor(.cyan)) {
                        if remoteManager.devices.isEmpty {
                            HStack {
                                Spacer()
                                Text("Đang quét tìm TV gần nhất...")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            .listRowBackground(Color(white: 0.08))
                        } else {
                            ForEach(remoteManager.devices, id: \.endpoint) { deviceModel in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(deviceModel.customName)
                                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                        Text("Gốc: \(deviceModel.originalName)")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    // Nút kết nối nhanh
                                    Button(action: {
                                        remoteManager.connectToDevice(deviceModel)
                                    }) {
                                        Text(remoteManager.currentConnectedEndpoint == deviceModel.endpoint ? "Đang kết nối" : "Chọn")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(remoteManager.currentConnectedEndpoint == deviceModel.endpoint ? Color.green : Color.cyan)
                                            .foregroundColor(.black)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(BorderlessButtonStyle())

                                    // Nút mở hộp thoại đổi tên
                                    Button(action: {
                                        editingDevice = deviceModel
                                        newNameText = deviceModel.customName
                                    }) {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(.cyan)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                .padding(.vertical, 6)
                                .listRowBackground(Color(white: 0.1))
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Danh sách TV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { remoteManager.rescan() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.cyan)
                    }
                }
            }
            .alert("Đổi tên thiết bị", isPresented: Binding(
                get: { editingDevice != nil },
                set: { if !$0 { editingDevice = nil } }
            )) {
                TextField("Tên mới", text: $newNameText)
                Button("Lưu") {
                    if let device = editingDevice {
                        var mutableDevice = device
                        mutableDevice.customName = newNameText
                        remoteManager.objectWillChange.send()
                    }
                    editingDevice = nil
                }
                Button("Hủy", role: .cancel) { editingDevice = nil }
            } message: {
                Text("Nhập tên gọi tùy chỉnh cho TV này.")
            }
        }
    }
}

// MARK: - Tab 3: Truyền ảnh lên màn hình TV
struct CastImageView: View {
    @ObservedObject var remoteManager: TVRemoteManager
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isSending = false
    @State private var sendStatus = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("TRUYỀN ẢNH LÊN TV")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
                    .padding(.top, 10)

                // Khung hiển thị ảnh xem trước
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(white: 0.1))
                        .frame(height: 280)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                        )

                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .cornerRadius(12)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("Chưa chọn ảnh nào")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal)

                // Nút chọn ảnh từ thư viện
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Chọn ảnh từ thư viện")
                    }
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.cyan)
                    .clipShape(Capsule())
                }
                .padding(.horizontal)
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            selectedImage = uiImage
                            sendStatus = ""
                        }
                    }
                }

                // Nút gửi ảnh lên TV
                Button(action: {
                    guard let image = selectedImage else { return }
                    isSending = true
                    sendStatus = "Đang gửi ảnh..."
                    remoteManager.sendImageToTV(image) { success in
                        DispatchQueue.main.async {
                            isSending = false
                            sendStatus = success ? "Đã truyền ảnh thành công lên TV!" : "Không thể gửi ảnh (Chưa kết nối TV)."
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        if isSending {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(isSending ? "Đang truyền..." : "Truyền ảnh lên TV")
                    }
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(selectedImage == nil ? Color.gray : Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(selectedImage == nil ? Color(white: 0.2) : Color.green)
                    .clipShape(Capsule())
                }
                .disabled(selectedImage == nil || isSending)
                .padding(.horizontal)

                if !sendStatus.isEmpty {
                    Text(sendStatus)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(sendStatus.contains(" thành công") ? .green : .orange)
                        .padding(.top, 5)
                }

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Manager xử lý mạng & kết nối
class TVRemoteManager: ObservableObject {
    @Published var isConnected = false
    @Published var statusMessage = "Đang tìm TV gần nhất..."
    @Published var devices: [DeviceModel] = []
    @Published var currentConnectedEndpoint: NWEndpoint?

    private var browsers: [NWBrowser] = []
    private var activeConnection: NWConnection?

    enum RemoteKey: String {
        case up = "KEY_UP"
        case down = "KEY_DOWN"
        case left = "KEY_LEFT"
        case right = "KEY_RIGHT"
        case ok = "KEY_ENTER"
        case back = "KEY_RETURN"
    }

    init() {
        startScanning()
    }

    func rescan() {
        browsers.forEach { $0.cancel() }
        browsers.removeAll()
        devices.removeAll()
        activeConnection?.cancel()
        isConnected = false
        currentConnectedEndpoint = nil
        statusMessage = "Đang quét lại mạng..."
        startScanning()
    }

    func startScanning() {
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
                guard let self = self else { return }
                DispatchQueue.main.async {
                    var newDeviceList: [DeviceModel] = []
                    for result in results {
                        let name: String
                        if case let .service(serviceName, _, _, _) = result.endpoint {
                            name = serviceName
                        } else {
                            name = "Smart TV"
                        }
                        let model = DeviceModel(originalName: name, endpoint: result.endpoint)
                        if !newDeviceList.contains(where: { $0.endpoint == result.endpoint }) {
                            newDeviceList.append(model)
                        }
                    }
                    self.devices = newDeviceList

                    // Tự động kết nối TV gần nhất (đầu tiên) nếu chưa kết nối
                    if !self.isConnected, let first = newDeviceList.first {
                        self.connectToDevice(first)
                    }
                }
            }
            browser.start(queue: .main)
            browsers.append(browser)
        }
    }

    func connectToDevice(_ device: DeviceModel) {
        activeConnection?.cancel()
        
        let connection = NWConnection(to: device.endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.currentConnectedEndpoint = device.endpoint
                    self?.statusMessage = "Đã kết nối: \(device.customName)"
                case .failed(_), .cancelled:
                    if self?.currentConnectedEndpoint == device.endpoint {
                        self?.isConnected = false
                        self?.currentConnectedEndpoint = nil
                        self?.statusMessage = "Mất kết nối với \(device.customName)"
                    }
                default:
                    break
                }
            }
        }
        connection.start(queue: .global())
        activeConnection = connection
    }

    func sendKey(_ key: RemoteKey) {
        guard let connection = activeConnection, isConnected else {
            if !isConnected, let first = devices.first {
                connectToDevice(first)
            }
            return
        }

        let payload = "{\"method\":\"ms.remote.control\",\"params\":{\"Cmd\":\"Click\",\"DataOfCmd\":\"\(key.rawValue)\",\"Option\":\"false\",\"TypeOfRemote\":\"SendRemoteKey\"}}"
        if let data = payload.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed({ _ in }))
        }
    }

    func sendImageToTV(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        guard let connection = activeConnection, isConnected,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(false)
            return
        }

        // Đóng gói dữ liệu ảnh gửi qua luồng TCP kết nối hiện tại
        connection.send(content: imageData, completion: .contentProcessed { error in
            completion(error == nil)
        })
    }
}
