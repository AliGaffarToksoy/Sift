import Foundation
import SiftCore

struct DeviceAuthorization: Decodable, Sendable {
    let device_code: String
    let user_code: String
    let verification_uri: String
    let expires_in: Int
    let interval: Int?
}

private struct OAuthResponse: Decodable {
    var access_token: String?
    var refresh_token: String?
    var expires_in: Int?
    var error: String?
}

struct DeltaResult: Sendable {
    var updates: [StoredMail]
    var removed: Set<String>
    var cursor: String
    var reset: Bool
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

actor MicrosoftMail {
    private let keychain = KeychainStore()
    private let session: URLSession
    private let scope = "https://graph.microsoft.com/User.Read https://graph.microsoft.com/Mail.ReadWrite https://graph.microsoft.com/Mail.Send offline_access"
    private let authority = "https://login.microsoftonline.com/common/oauth2/v2.0/"
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 90
        config.urlCache = nil
        session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
    }
    private func form(_ values: [String: String]) -> Data {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return Data(values.sorted { $0.key < $1.key }.map {
            "\($0.key.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }.joined(separator: "&").utf8)
    }
    private func oauth(_ endpoint: String, values: [String: String]) async throws -> (Data, Int) {
        guard let url = URL(string: authority + endpoint) else { throw SiftError.message("Geçersiz Microsoft adresi.") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form(values)
        let (data, response) = try await session.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
    func begin(clientID: String) async throws -> DeviceAuthorization {
        guard UUID(uuidString: clientID) != nil else { throw SiftError.message("Geçerli bir Microsoft Application (client) ID gir.") }
        let (data, status) = try await oauth("devicecode", values: ["client_id": clientID, "scope": scope])
        guard status == 200 else { throw SiftError.message("Microsoft girişi başlatılamadı (\(status)). Uygulama kaydında kişisel/kurumsal hesapları ve public client flows seçeneğini kontrol et.") }
        return try JSONDecoder().decode(DeviceAuthorization.self, from: data)
    }
    func finish(_ authorization: DeviceAuthorization, clientID: String) async throws -> MailAccount {
        let deadline = Date.now.addingTimeInterval(Double(authorization.expires_in))
        var interval = max(5, authorization.interval ?? 5)
        while Date.now < deadline {
            try await Task.sleep(for: .seconds(interval))
            let (data, status) = try await oauth("token", values: ["client_id": clientID, "grant_type": "urn:ietf:params:oauth:grant-type:device_code", "device_code": authorization.device_code])
            let response = try JSONDecoder().decode(OAuthResponse.self, from: data)
            if response.error == "authorization_pending" { continue }
            if response.error == "slow_down" { interval += 5; continue }
            guard status == 200, let access = response.access_token, let refresh = response.refresh_token else {
                throw SiftError.message("Microsoft girişi tamamlanamadı. İstek reddedilmiş veya süresi dolmuş olabilir; yeniden dene.")
            }
            struct Profile: Decodable { var id: String; var displayName: String?; var mail: String?; var userPrincipalName: String? }
            let profile: Profile = try await get("https://graph.microsoft.com/v1.0/me?$select=id,displayName,mail,userPrincipalName", token: access)
            try Task.checkCancellation()
            let account = MailAccount(id: profile.id, address: profile.mail ?? profile.userPrincipalName ?? "Outlook", name: profile.displayName ?? "Outlook", clientID: clientID)
            try keychain.save(TokenSet(accessToken: access, refreshToken: refresh, expiresAt: .now.addingTimeInterval(Double(response.expires_in ?? 3600))), account: account.id)
            return account
        }
        throw SiftError.message("Giriş kodunun süresi doldu. Yeni bir kod oluştur.")
    }
    private func access(_ account: MailAccount, forceRefresh: Bool = false) async throws -> String {
        let token = try keychain.load(account: account.id)
        if !forceRefresh, token.expiresAt > .now.addingTimeInterval(120) { return token.accessToken }
        let (data, status) = try await oauth("token", values: ["client_id": account.clientID, "grant_type": "refresh_token", "refresh_token": token.refreshToken, "scope": scope])
        let response = try JSONDecoder().decode(OAuthResponse.self, from: data)
        guard status == 200, let access = response.access_token else { throw SiftError.message("\(account.address): Microsoft oturumu yenilenemedi. Hesabı yeniden bağla.") }
        try keychain.save(TokenSet(accessToken: access, refreshToken: response.refresh_token ?? token.refreshToken, expiresAt: .now.addingTimeInterval(Double(response.expires_in ?? 3600))), account: account.id)
        return access
    }
    private struct HTTPFailure: Error { var status: Int }
    private func request(_ rawURL: String, token: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let url = GraphSafety.validatedURL(rawURL) else { throw SiftError.message("Güvenli olmayan posta sunucusu adresi engellendi.") }
        var request = URLRequest(url: url)
        request.httpMethod = method; request.httpBody = body
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("outlook.body-content-type=\"text\", IdType=\"ImmutableId\", odata.maxpagesize=50", forHTTPHeaderField: "Prefer")
        for attempt in 0..<3 {
            try Task.checkCancellation()
            let (data, response) = try await session.data(for: request)
            let http = response as? HTTPURLResponse
            let status = http?.statusCode ?? 0
            if (200..<300).contains(status) { return data }
            // Retry only reads: replaying a send/reply after an uncertain response could send twice.
            if method == "GET", (status == 429 || status >= 500), attempt < 2 {
                let wait = min(60, max(1, Double(http?.value(forHTTPHeaderField: "Retry-After") ?? "") ?? pow(2, Double(attempt + 1))))
                try await Task.sleep(for: .seconds(wait)); continue
            }
            throw HTTPFailure(status: status)
        }
        throw SiftError.message("Posta sunucusuna ulaşılamadı.")
    }
    private func get<T: Decodable>(_ url: String, token: String) async throws -> T {
        try JSONDecoder().decode(T.self, from: await request(url, token: token))
    }
    func sync(_ account: MailAccount, vip: Set<String>) async throws -> DeltaResult {
        do { return try await delta(account, vip: vip, token: access(account)) }
        catch let error as HTTPFailure where error.status == 401 {
            return try await delta(account, vip: vip, token: access(account, forceRefresh: true))
        } catch let error as HTTPFailure {
            throw SiftError.message("\(account.address): Eşitleme başarısız (\(error.status)). İnternet bağlantısını ve Microsoft izinlerini kontrol et.")
        }
    }
    private func delta(_ account: MailAccount, vip: Set<String>, token: String) async throws -> DeltaResult {
        let initial = "https://graph.microsoft.com/v1.0/me/mailFolders/inbox/messages/delta?$select=id,subject,bodyPreview,body,from,toRecipients,receivedDateTime,isRead,importance,webLink,internetMessageHeaders"
        var next = account.deltaLink ?? initial
        var reset = account.deltaLink == nil
        var updates: [String: StoredMail] = [:]
        var removed: Set<String> = []
        var visited: Set<String> = []
        while true {
            try Task.checkCancellation()
            guard visited.insert(next).inserted else { throw SiftError.message("Sunucu aynı eşitleme sayfasını tekrar gönderdi.") }
            let page: GraphDeltaPage
            do { page = try await get(next, token: token) }
            catch let error as HTTPFailure where error.status == 410 && !reset {
                next = initial; reset = true; updates = [:]; removed = []; visited = []; continue
            }
            for item in page.value {
                if item.removed != nil { updates[item.id] = nil; removed.insert(item.id) }
                else {
                    // Delta events may omit unchanged properties. Hydrate partial updates before replacing a cached message.
                    var full = item
                    if item.body == nil || item.from == nil || item.subject == nil {
                        do { full = try await get("https://graph.microsoft.com/v1.0/me/messages/" + GraphSafety.pathSegment(item.id) + "?$select=id,subject,bodyPreview,body,from,toRecipients,receivedDateTime,isRead,importance,webLink,internetMessageHeaders", token: token) }
                        catch let error as HTTPFailure where error.status == 404 { updates[item.id] = nil; removed.insert(item.id); continue }
                    }
                    updates[item.id] = full.stored(account: account, vip: vip); removed.remove(item.id)
                }
            }
            if let link = page.nextLink { next = link; continue }
            guard let cursor = page.deltaLink, GraphSafety.validatedURL(cursor) != nil else { throw SiftError.message("Eşitleme imleci eksik. Veriler değiştirilmedi.") }
            return DeltaResult(updates: Array(updates.values), removed: removed, cursor: cursor, reset: reset)
        }
    }
    func mutate(_ mail: StoredMail, account: MailAccount, action: String, text: String? = nil) async throws {
        let token = try await access(account)
        let base = "https://graph.microsoft.com/v1.0/me/messages/" + GraphSafety.pathSegment(mail.remoteID)
        let path: String; let method: String; let payload: [String: Any]
        switch action {
        case "archive": path = base + "/move"; method = "POST"; payload = ["destinationId": "archive"]
        case "read": path = base; method = "PATCH"; payload = ["isRead": true]
        case "reply": path = base + "/reply"; method = "POST"; payload = ["message": ["body": ["contentType": "Text", "content": text ?? ""]]]
        default: throw SiftError.message("Desteklenmeyen posta işlemi.")
        }
        do { _ = try await request(path, token: token, method: method, body: JSONSerialization.data(withJSONObject: payload)) }
        catch let error as HTTPFailure { throw SiftError.message("İşlem tamamlanamadı (\(error.status)). Posta sunucusundaki durumu kontrol edip yeniden dene.") }
    }
    func disconnect(_ account: MailAccount) throws { try keychain.delete(account: account.id) }
}
