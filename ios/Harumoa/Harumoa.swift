import UIKit
import WebKit
import AVFoundation
import ContactsUI
import GoogleSignIn

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = HarumoaViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}

final class Assets: NSObject, WKURLSchemeHandler {
    let root = Bundle.main.url(forResource: "www", withExtension: nil)!
    var recordings: [String: URL] = [:]
    static func local(_ url: URL?) -> Bool { url?.scheme == "harumoa" && url?.host == "localhost" && url?.port == nil }
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        do {
            guard let url = task.request.url, Self.local(url), task.request.httpMethod == "GET" else { throw URLError(.unsupportedURL) }
            let path = url.path.removingPercentEncoding ?? url.path
            let file: URL
            if path.hasPrefix("/recordings/") {
                let token = String(path.dropFirst("/recordings/".count))
                guard UUID(uuidString: token) != nil, let recording = recordings[token] else { throw URLError(.fileDoesNotExist) }
                file = recording
            } else {
                guard !path.contains("\\"), !path.split(separator: "/").contains("..") else { throw URLError(.noPermissionsToReadFile) }
                file = root.appendingPathComponent(path == "/" ? "index.html" : String(path.dropFirst())).standardizedFileURL.resolvingSymlinksInPath()
                guard file.path.hasPrefix(root.resolvingSymlinksInPath().path + "/") else { throw URLError(.noPermissionsToReadFile) }
            }
            let data = try Data(contentsOf: file)
            let mime = ["html": "text/html", "js": "application/javascript", "css": "text/css", "svg": "image/svg+xml", "png": "image/png", "wav": "audio/wav", "m4a": "audio/mp4", "json": "application/json"][file.pathExtension] ?? "application/octet-stream"
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": mime, "Cache-Control": "no-store", "Content-Length": String(data.count)])!
            task.didReceive(response); task.didReceive(data); task.didFinish()
        } catch { task.didFailWithError(error) }
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
    func discard(_ token: String) { if let file = recordings.removeValue(forKey: token) { try? FileManager.default.removeItem(at: file) } }
}

final class HarumoaViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, AVAudioRecorderDelegate, CNContactPickerDelegate {
    let assets = Assets()
    var web: WKWebView!
    var googleBusy = false
    var authGeneration = 0
    var recorder: AVAudioRecorder?
    var recordingID: String?
    var recordingURL: URL?
    var permissionReady = false
    var meter: Timer?
    var players: [String: AVAudioPlayer] = [:]
    let googleScopes = ["https://www.googleapis.com/auth/drive.file", "https://www.googleapis.com/auth/calendar.app.created", "https://www.googleapis.com/auth/calendar.calendarlist.readonly", "https://www.googleapis.com/auth/calendar.events.readonly"]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.93, alpha: 1)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.setURLSchemeHandler(assets, forURLScheme: "harumoa")
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all
        config.userContentController.add(self, name: "harumoa")
        let identity = UserDefaults.standard.dictionary(forKey: "harumoa.selectedGoogle") ?? [:]
        let bridge = try! String(contentsOf: Bundle.main.url(forResource: "bridge", withExtension: "js")!, encoding: .utf8)
        config.userContentController.addUserScript(WKUserScript(source: "window.__harumoaIdentity=" + json(identity) + ";" + bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self; web.uiDelegate = self
        web.accessibilityIdentifier = "HarumoaWeb"
        web.isInspectable = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(web)
        NSLayoutConstraint.activate([
            web.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor), web.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            web.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), web.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
        if let client = googleClient() { GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: client) }
        NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(foreground), name: UIApplication.didBecomeActiveNotification, object: nil)
        web.load(URLRequest(url: URL(string: "harumoa://localhost/index.html")!))
    }
    func json(_ value: Any) -> String { String(data: try! JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys]), encoding: .utf8)! }
    func event(_ name: String, _ payload: [String: Any]) {
        guard Assets.local(web.url) else { return }
        web.evaluateJavaScript("window.dispatchEvent(new CustomEvent(" + json(name) + ",{detail:" + json(payload) + "}));", completionHandler: nil)
    }
    func googleClient() -> String? {
        guard let client = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              client.range(of: #"^\d+-[\w-]+\.apps\.googleusercontent\.com$"#, options: .regularExpression) != nil else { return nil }
        return client
    }
    func googleError(_ id: String, _ code: String, _ message: String) { event("harumoa:google-auth", ["requestId": id, "error": code, "message": message]) }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, Assets.local(message.frameInfo.request.url), Assets.local(web.url),
              let body = message.body as? [String: Any], let method = body["method"] as? String, let args = body["args"] as? [Any], args.count <= 3 else { return }
        func string(_ i: Int) -> String { i < args.count ? (args[i] as? String ?? "") : "" }
        switch method {
        case "signIn", "authorize", "forget", "invalidateToken", "pickFile":
            let id = string(0)
            guard UUID(uuidString: id) != nil else { return }
            if method == "forget" || method == "invalidateToken" {
                authGeneration += 1
                GIDSignIn.sharedInstance.signOut()
                if method == "forget" {
                    UserDefaults.standard.removeObject(forKey: "harumoa.selectedGoogle")
                    web.evaluateJavaScript("window.__harumoaIdentity={};", completionHandler: nil)
                }
                event("harumoa:google-auth", ["requestId": id]); return
            }
            if method == "pickFile" {
                googleError(id, "ios_picker_pending", "iOS 가족 파일 선택 연결은 아직 준비 중입니다. 웹에서 연결해 주세요. / iOS family file selection is not configured yet. Use the web version."); return
            }
            guard googleClient() != nil else {
                googleError(id, "ios_oauth_missing", "개발자의 iOS Google 로그인 등록이 필요합니다. 로그인 없이 체험할 수 있어요. / The developer must configure iOS Google sign-in. You can use the local demo."); return
            }
            guard !googleBusy else { googleError(id, "busy", "Google connection is already open."); return }
            let scopes: [String]
            if method == "authorize" {
                guard string(1).utf8.count <= 2000, let bytes = string(1).data(using: .utf8), let requested = try? JSONSerialization.jsonObject(with: bytes) as? [String],
                      !requested.isEmpty, requested.allSatisfy({ googleScopes.contains($0) }) else { googleError(id, "workspace_denied", "Invalid Google scopes."); return }
                scopes = requested
            } else { scopes = [] }
            googleBusy = true
            let generation = authGeneration
            Task { @MainActor in
                defer { self.googleBusy = false }
                do {
                    let user: GIDGoogleUser
                    if method == "signIn" {
                        GIDSignIn.sharedInstance.signOut()
                        user = try await GIDSignIn.sharedInstance.signIn(withPresenting: self).user
                        guard generation == self.authGeneration else { GIDSignIn.sharedInstance.signOut(); self.googleError(id, "cancelled", "Google account changed."); return }
                        let identity = ["email": user.profile?.email ?? "", "name": user.profile?.name ?? ""]
                        guard !identity["email"]!.isEmpty else { throw URLError(.userAuthenticationRequired) }
                        UserDefaults.standard.set(identity, forKey: "harumoa.selectedGoogle")
                        self.event("harumoa:google-auth", ["requestId": id, "email": identity["email"]!, "name": identity["name"]!])
                    } else {
                        user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
                        guard generation == self.authGeneration else { GIDSignIn.sharedInstance.signOut(); self.googleError(id, "cancelled", "Google account changed."); return }
                        let selected = UserDefaults.standard.dictionary(forKey: "harumoa.selectedGoogle")?["email"] as? String
                        guard selected?.lowercased() == user.profile?.email.lowercased() else { self.googleError(id, "account_mismatch", "Reconnect the selected Google account."); return }
                        let missing = scopes.filter { !(user.grantedScopes ?? []).contains($0) }
                        let authorized: GIDGoogleUser
                        if !missing.isEmpty {
                            guard args.count > 2, args[2] as? Bool == true else { self.googleError(id, "interaction_required", "Approve Google storage access."); return }
                            authorized = try await user.addScopes(missing, presenting: self).user
                        } else { authorized = try await user.refreshTokensIfNeeded() }
                        guard generation == self.authGeneration else { GIDSignIn.sharedInstance.signOut(); self.googleError(id, "cancelled", "Google account changed."); return }
                        let granted = (authorized.grantedScopes ?? []).filter { self.googleScopes.contains($0) }
                        guard scopes.allSatisfy({ granted.contains($0) }), authorized.profile?.email.lowercased() == selected?.lowercased() else { self.googleError(id, "workspace_denied", "Required access was not granted."); return }
                        self.event("harumoa:google-auth", ["requestId": id, "access_token": authorized.accessToken.tokenString,
                            "expires_in": max(0, authorized.accessToken.expirationDate?.timeIntervalSinceNow ?? 0), "scope": granted.joined(separator: " "),
                            "email": authorized.profile?.email ?? "", "name": authorized.profile?.name ?? ""])
                    }
                } catch {
                    let code = (error as NSError).code == -5 ? "cancelled" : "interaction_required"
                    self.googleError(id, code, "Google 연결을 다시 시도해 주세요. / Retry Google connection.")
                }
            }
        case "recordStart": if UUID(uuidString: string(0)) != nil { startRecording(string(0)) }
        case "recordStop": if string(0) == recordingID { finishRecording() }
        case "recordCancel": if string(0) == recordingID { cancelRecording() }
        case "recordDiscard": assets.discard(string(0))
        case "openSettings": if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        case "requestPermission": if string(0) == "microphone", let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        case "shareInvitation":
            let text = string(0)
            guard text.utf8.count <= 12000, !text.isEmpty else { return }
            let sheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            sheet.popoverPresentationController?.sourceView = web; sheet.popoverPresentationController?.sourceRect = CGRect(x: web.bounds.midX, y: web.bounds.midY, width: 1, height: 1)
            present(sheet, animated: true)
        case "pickContact": let picker = CNContactPickerViewController(); picker.delegate = self; present(picker, animated: true)
        case "tap":
            guard args.count == 3, recorder == nil, UIApplication.shared.applicationState == .active else { return }
            if args[1] as? Bool == true { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            if args[0] as? Bool == true { play("click", volume: args[2] as? Double ?? 0) }
        case "success": if args.count == 2, args[0] as? Bool == true { play("success", volume: args[1] as? Double ?? 0) }
        case "stopFeedback": players.values.forEach { $0.stop() }
        default: break
        }
    }
    func play(_ name: String, volume: Double) {
        guard recorder == nil, UIApplication.shared.applicationState == .active, volume.isFinite, volume > 0 else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            if players[name] == nil { players[name] = try AVAudioPlayer(contentsOf: assets.root.appendingPathComponent("audio/" + name + ".wav")) }
            let player = players[name]!
            player.stop(); player.currentTime = 0; player.volume = Float(min(100, volume) / 100); player.play()
        } catch { /* Sound is optional; never prevent a save or navigation. */ }
    }
    func startRecording(_ id: String) {
        guard recordingID == nil else { event("harumoa:recording", ["requestId": id, "phase": "error", "message": "Finish the current recording first."]); return }
        recordingID = id
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self, self.recordingID == id else { return }
                guard granted else { self.cancelRecording(error: "마이크 권한을 허용한 뒤 다시 눌러 주세요. / Allow the microphone and retry.", code: "MIC_PERMISSION"); return }
                self.permissionReady = true
                if UIApplication.shared.applicationState == .active { self.beginRecording() }
            }
        }
    }
    func beginRecording() {
        guard let id = recordingID, permissionReady, recorder == nil else { return }
        permissionReady = false
        do {
            players.values.forEach { $0.stop() }
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("harumoa-" + UUID().uuidString.lowercased() + ".m4a")
            recordingURL = url
            let recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 96000])
            recorder.delegate = self; recorder.isMeteringEnabled = true
            guard recorder.prepareToRecord(), recorder.record(forDuration: 180) else { throw URLError(.cannotCreateFile) }
            self.recorder = recorder
            event("harumoa:recording", ["requestId": id, "phase": "recording", "seconds": 0, "level": 0])
            meter = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                guard let self, let recorder = self.recorder, let id = self.recordingID else { return }
                recorder.updateMeters()
                let level = pow(10, recorder.averagePower(forChannel: 0) / 20)
                self.event("harumoa:recording", ["requestId": id, "phase": "recording", "seconds": Int(recorder.currentTime), "level": level.isFinite ? max(0, min(1, level)) : 0])
            }
        } catch { cancelRecording(error: "녹음을 시작하지 못했어요. 다시 시도해 주세요. / Could not start recording. Retry.") }
    }
    func finishRecording() {
        guard let id = recordingID, let file = recordingURL, recorder != nil else { cancelRecording(); return }
        recordingID = nil; meter?.invalidate(); meter = nil
        recorder?.stop(); recorder = nil; recordingURL = nil; permissionReady = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        guard let data = try? Data(contentsOf: file), !data.isEmpty, data.count <= 10 * 1024 * 1024 else {
            try? FileManager.default.removeItem(at: file)
            event("harumoa:recording", ["requestId": id, "phase": "error", "message": "녹음 파일을 확인해 주세요. / Check the recording file."]); return
        }
        let token = UUID().uuidString.lowercased(); assets.recordings[token] = file
        event("harumoa:recording", ["requestId": id, "phase": "finished", "token": token, "mime": "audio/mp4", "url": "harumoa://localhost/recordings/" + token])
    }
    func cancelRecording(error: String? = nil, code: String = "RECORDING_FAILED") {
        let id = recordingID
        recordingID = nil; permissionReady = false; meter?.invalidate(); meter = nil
        recorder?.stop(); recorder = nil
        if let file = recordingURL { try? FileManager.default.removeItem(at: file) }
        recordingURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if let id { event("harumoa:recording", ["requestId": id, "phase": error == nil ? "cancelled" : "error", "code": code, "message": error ?? ""]) }
    }
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard recordingID != nil else { return }
        if flag { finishRecording() } else { cancelRecording(error: "Recording interrupted. Retry.") }
    }
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) { cancelRecording(error: "Recording interrupted. Retry.") }
    @objc func background() {
        cancelRecording(); players.values.forEach { $0.stop() }
        web.evaluateJavaScript("window.HMServices?.cleanup();", completionHandler: nil)
    }
    @objc func foreground() {
        if permissionReady { beginRecording() }
        web.evaluateJavaScript("window.dispatchEvent(new Event('focus'));", completionHandler: nil)
    }
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        event("harumoa:contact", ["name": CNContactFormatter.string(from: contact, style: .fullName) ?? "", "phone": contact.phoneNumbers.first?.value.stringValue ?? "", "email": contact.emailAddresses.first.map { String($0.value) } ?? ""])
    }
    func contactPickerDidCancel(_ picker: CNContactPickerViewController) { event("harumoa:contact", [:]) }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if Assets.local(action.request.url) { decisionHandler(.allow); return }
        if action.navigationType == .linkActivated, let url = action.request.url, ["https", "mailto", "tel"].contains(url.scheme ?? "") { UIApplication.shared.open(url) }
        decisionHandler(.cancel)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.navigationType == .linkActivated, let url = action.request.url, ["https", "mailto", "tel"].contains(url.scheme ?? "") { UIApplication.shared.open(url) }
        return nil
    }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "Harumoa", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() }); present(alert, animated: true)
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: "Harumoa", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) }); present(alert, animated: true)
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: "Harumoa", message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(alert.textFields?.first?.text) }); present(alert, animated: true)
    }
}
