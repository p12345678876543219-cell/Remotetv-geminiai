import UIKit
import Network

class TVRemoteViewController: UIViewController {
    
    // Giao diện hiển thị trạng thái kết nối
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Đang quét TV gần nhất..."
        label.textColor = .systemGreen
        label.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Lưu IP của TV tìm thấy đầu tiên
    private var connectedTVIP: String?
    private var udpConnection: NWConnection?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1.0)
        setupUI()
        autoDiscoverNearestTV()
    }
    
    // MARK: - 1. Tự động tìm TV gần nhất qua SSDP (UPnP)
    private func autoDiscoverNearestTV() {
        let host = NWEndpoint.Host("239.255.255.250")
        let port = NWEndpoint.Port(integerLiteral: 1900)
        
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        
        udpConnection = NWConnection(host: host, port: port, using: params)
        
        udpConnection?.stateUpdateHandler = { [weak self] state in
            if state == .ready {
                self?.sendSSDPDiscovery()
            }
        }
        
        udpConnection?.start(queue: .global())
    }
    
    private func sendSSDPDiscovery() {
        let ssdpMessage = """
        M-SEARCH * HTTP/1.1\r
        HOST: 239.255.255.250:1900\r
        MAN: "ssdp:discover"\r
        MX: 2\r
        ST: ssdp:all\r
        \r
        """
        
        guard let data = ssdpMessage.data(using: .utf8) else { return }
        
        udpConnection?.send(content: data, completion: .contentProcessed({ [weak self] error in
            if error == nil {
                self?.listenForTVResponse()
            }
        }))
    }
    
    private func listenForTVResponse() {
        udpConnection?.receiveMessage { [weak self] (data, context, isComplete, error) in
            guard let self = self, let data = data, let response = String(data: data, encoding: .utf8) else { return }
            
            // Lọc các phản hồi từ Smart TV (Samsung, LG, Android TV, Sony...)
            let tvKeywords = ["Samsung", "webOS", "BRAVIA", "Android", "DIAL", "roku"]
            if tvKeywords.contains(where: { response.localizedCaseInsensitiveContains($0) }) {
                if let remoteEndpoint = context?.remoteEndpoint,
                   case let .hostPort(host, _) = remoteEndpoint {
                    let ipString = "\(host)"
                    if self.connectedTVIP == nil {
                        self.connectedTVIP = ipString
                        DispatchQueue.main.async {
                            self.statusLabel.text = "Đã kết nối: \(ipString)"
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 2. Gửi lệnh điều khiển tới TV
    @objc private func handleControlTap(_ sender: UIButton) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        guard let command = sender.accessibilityIdentifier else { return }
        
        guard let tvIP = connectedTVIP else {
            statusLabel.text = "Chưa tìm thấy TV! Đang thử lại..."
            autoDiscoverNearestTV()
            return
        }
        
        print("Gửi lệnh [\(command)] tới TV tại IP: \(tvIP)")
        sendCommandToTV(ip: tvIP, keyCode: command)
    }
    
    private func sendCommandToTV(ip: String, keyCode: String) {
        // Ví dụ gửi lệnh qua giao thức HTTP REST / DIAL chuẩn của Smart TV (Port 8001/8060/8080)
        guard let url = URL(string: "http://\(ip):8060/keypress/\(keyCode)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    // MARK: - 3. Thiết kế giao diện D-Pad (Lên, Xuống, Trái, Phải, OK, Quay lại)
    private func setupUI() {
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        let dpadContainer = UIView()
        dpadContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dpadContainer)
        
        NSLayoutConstraint.activate([
            dpadContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dpadContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            dpadContainer.widthAnchor.constraint(equalToConstant: 260),
            dpadContainer.heightAnchor.constraint(equalToConstant: 260)
        ])
        
        let btnUp = createButton(title: "▲", id: "Up")
        let btnDown = createButton(title: "▼", id: "Down")
        let btnLeft = createButton(title: "◀", id: "Left")
        let btnRight = createButton(title: "▶", id: "Right")
        let btnOK = createButton(title: "OK", id: "Select", isPrimary: true)
        
        [btnUp, btnDown, btnLeft, btnRight, btnOK].forEach { dpadContainer.addSubview($0) }
        
        let btnSize: CGFloat = 75
        NSLayoutConstraint.activate([
            // Nút OK ở giữa
            btnOK.centerXAnchor.constraint(equalTo: dpadContainer.centerXAnchor),
            btnOK.centerYAnchor.constraint(equalTo: dpadContainer.centerYAnchor),
            btnOK.widthAnchor.constraint(equalToConstant: btnSize),
            btnOK.heightAnchor.constraint(equalToConstant: btnSize),
            
            // Nút Lên
            btnUp.bottomAnchor.constraint(equalTo: btnOK.topAnchor, constant: -12),
            btnUp.centerXAnchor.constraint(equalTo: dpadContainer.centerXAnchor),
            btnUp.widthAnchor.constraint(equalToConstant: btnSize),
            btnUp.heightAnchor.constraint(equalToConstant: btnSize),
            
            // Nút Xuống
            btnDown.topAnchor.constraint(equalTo: btnOK.bottomAnchor, constant: 12),
            btnDown.centerXAnchor.constraint(equalTo: dpadContainer.centerXAnchor),
            btnDown.widthAnchor.constraint(equalToConstant: btnSize),
            btnDown.heightAnchor.constraint(equalToConstant: btnSize),
            
            // Nút Trái
            btnLeft.rightAnchor.constraint(equalTo: btnOK.leftAnchor, constant: -12),
            btnLeft.centerYAnchor.constraint(equalTo: dpadContainer.centerYAnchor),
            btnLeft.widthAnchor.constraint(equalToConstant: btnSize),
            btnLeft.heightAnchor.constraint(equalToConstant: btnSize),
            
            // Nút Phải
            btnRight.leftAnchor.constraint(equalTo: btnOK.rightAnchor, constant: 12),
            btnRight.centerYAnchor.constraint(equalTo: dpadContainer.centerYAnchor),
            btnRight.widthAnchor.constraint(equalToConstant: btnSize),
            btnRight.heightAnchor.constraint(equalToConstant: btnSize)
        ])
        
        // Nút Quay lại (Back)
        let btnBack = createButton(title: "↩ Quay lại", id: "Back")
        view.addSubview(btnBack)
        NSLayoutConstraint.activate([
            btnBack.topAnchor.constraint(equalTo: dpadContainer.bottomAnchor, constant: 40),
            btnBack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            btnBack.widthAnchor.constraint(equalToConstant: 160),
            btnBack.heightAnchor.constraint(equalToConstant: 55)
        ])
    }
    
    private func createButton(title: String, id: String, isPrimary: Bool = false) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = isPrimary ? .systemBlue : UIColor(white: 0.18, alpha: 1.0)
        btn.layer.cornerRadius = 20
        btn.layer.borderWidth = 1.5
        btn.layer.borderColor = UIColor.systemCyan.withAlphaComponent(0.5).cgColor
        btn.accessibilityIdentifier = id
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(handleControlTap(_:)), for: .touchUpInside)
        return btn
    }
}
