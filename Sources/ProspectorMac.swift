//
//  ProspectorMac.swift
//  ProspectorMac
//
//  Created by etudiant on 2026-01-01.
//  Swift version: 6.4
//

import SwiftUI
import CoreLocation
import MapKit
import Cocoa
import WebKit

// MARK: - WebsiteStatus Enum
enum WebsiteStatus: String, CaseIterable, Codable {
    case unknown, secure, outdated, noSite, error
}

// MARK: - ProspectStatus Enum
enum ProspectStatus: String, CaseIterable, Codable {
    case all, noSite, siteOutdated, readyToContact, contacted
}

// MARK: - Prospect Model
struct Prospect: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String?
    var category: String?
    var city: String?
    var address: String?
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var website: String?
    var hasWebsite: Bool = false
    var websiteStatus: WebsiteStatus = .unknown
    var websiteAudit: WebsiteAudit?
    var email: String?
    var phone: String?
    var directorName: String?
    var siret: String?
    var raisonSociale: String?
    var nomCommercial: String?
    var photoURLs: [String]?
    var openingHours: [String]?
    var googleRating: Double?
    var googleReviewCount: Int?
    var googleReviews: [GoogleReview]?
    var figmaUrl: String?
    var maquetteJson: String?
    var maquettePath: String?
    var status: ProspectStatus = .all
    var isSample: Bool = false
    var emailSubject: String?
    var emailBody: String?
    var pitchScript: String?
    var createdAt: Date = Date()
    var lastUpdated: Date = Date()

    var opportunityBadge: String? {
        guard let rating = googleRating else { return nil }
        switch rating {
        case 4.5...5.0: return "★★★★★ Excellent"
        case 4.0..<4.5: return "★★★★ Very Good"
        case 3.5..<4.0: return "★★★★ Good"
        case 3.0..<3.5: return "★★★ Fair"
        case 0..<3.0: return "★ Needs Improvement"
        default: return nil
        }
    }

    var isReady: Bool {
        hasWebsite && websiteStatus == .secure && googleRating != nil && googleRating! >= 4.0
    }
}

// MARK: - UserProfile (identité de l'expéditeur, demandée au lancement)
struct UserProfile: Codable {
    var name: String = ""
    var phone: String = ""
    var email: String = ""

    var isComplete: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - GoogleReview (avis client réel, jamais inventé)
struct GoogleReview: Codable {
    var author: String
    var rating: Double?
    var text: String
    var date: String?
}

/// Ville déduite d'une adresse ("87 Rue X, 64600 Anglet" → "Anglet")
func cityFromAddress(_ address: String?) -> String? {
    guard let a = address, !a.isEmpty,
          let re = try? NSRegularExpression(pattern: "(\\d{5})\\s+([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ' \\-]{1,40})"),
          let m = re.firstMatch(in: a, range: NSRange(a.startIndex..., in: a)),
          m.numberOfRanges > 2, let r = Range(m.range(at: 2), in: a) else { return nil }
    let city = String(a[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    return city.isEmpty ? nil : city
}

/// Dernier filet ville : reverse-geocode Photon (léger, ~1 s)
func fetchReverseCity(lat: Double, lon: Double) async -> String? {
    guard lat != 0 || lon != 0,
          let url = URL(string: "https://photon.komoot.io/reverse?lat=\(lat)&lon=\(lon)&lang=fr") else { return nil }
    var request = URLRequest(url: url)
    request.timeoutInterval = 12
    request.setValue("ProspectorMac/1.0", forHTTPHeaderField: "User-Agent")
    guard let (data, _) = try? await URLSession.shared.data(for: request),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let props = ((json["features"] as? [[String: Any]])?.first?["properties"] as? [String: Any]) else { return nil }
    for k in ["city", "town", "village", "locality", "district"] {
        if let c = props[k] as? String, !c.isEmpty { return c }
    }
    return nil
}

// MARK: - WebsiteAudit Model
struct WebsiteAudit: Codable {
    var hasHttps: Bool = false
    var isMobileFriendly: Bool = false
    var textContentLength: Int = 0
    var performanceScore: Int = 0
    var accessibilityScore: Int = 0
    var issues: [String] = []
}

// MARK: - Database Manager
@MainActor final class DatabaseManager: ObservableObject {
    @Published var prospects: [Prospect] = []
    private let fileURL: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = documents.appendingPathComponent("prospector.plist")
        load()
    }

    func load() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Prospect].self, from: data) {
            prospects = decoded
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(prospects) {
            try? data.write(to: fileURL)
        }
    }

    func addProspect(_ prospect: Prospect) {
        prospects.append(prospect)
        save()
    }

    func updateProspect(_ prospect: Prospect) {
        if let index = prospects.firstIndex(where: { $0.id == prospect.id }) {
            prospects[index] = prospect
            save()
        } else {
            addProspect(prospect)
        }
    }

    func clearAll() {
        prospects.removeAll()
        save()
    }

    // Même commerce déjà enregistré ? (même nom + même lieu)
    func containsSame(as prospect: Prospect) -> Bool {
        prospects.contains { existing in
            guard let a = existing.name?.lowercased(), !a.isEmpty,
                  let b = prospect.name?.lowercased(), a == b else { return false }
            let samePlace = abs(existing.latitude - prospect.latitude) < 0.0005
                && abs(existing.longitude - prospect.longitude) < 0.0005
            let sameAddr = !(prospect.address?.isEmpty ?? true)
                && (existing.address ?? "") == (prospect.address ?? "")
            return samePlace || sameAddr
        }
    }
}

// MARK: - AppState
@MainActor final class AppState: ObservableObject {
    @Published var isLoading = false
    @Published var connectionStatus: ConnectionStatus = .unknown
    @Published var apiKey = "__CLE_SUPPRIMEE__"
    @Published var radius: Double = 10.0
    @Published var filterStatus: ProspectStatus = .all
    @Published var selectedModel: String = "auto"
    @Published var availableModels: [String] = []
    @Published var userProfile = UserProfile()
    @Published var showingOnboarding = false
    private let profileKey = "prospector.userProfile"

    init() {
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let saved = try? JSONDecoder().decode(UserProfile.self, from: data) {
            userProfile = saved
        }
        showingOnboarding = !userProfile.isComplete
    }

    func saveProfile(name: String, phone: String, email: String) {
        let profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        userProfile = profile
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
        showingOnboarding = false
    }

    enum ConnectionStatus: Equatable {
        case unknown, connecting, connected, disconnected, error(String)
    }

    func testConnection() async -> Bool {
        connectionStatus = .connecting

        // La clé FreeLLMAPI est refusée sur /models mais acceptée sur /chat/completions :
        // on teste donc la connexion avec une mini-complétion.
        guard let url = URL(string: "http://127.0.0.1:31415/v1/chat/completions") else {
            connectionStatus = .error("Invalid URL")
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": "auto",
            "messages": [["role": "user", "content": "Réponds uniquement : OK"]],
            "max_tokens": 5,
            "temperature": 0
        ])

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                connectionStatus = .connected
                // Liste des modèles en bonus (non bloquant si /models refuse la clé)
                await fetchModelList()
                return true
            } else {
                connectionStatus = .error("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
        } catch {
            connectionStatus = .error(error.localizedDescription)
        }

        return false
    }

    private func fetchModelList() async {
        guard let url = URL(string: "http://127.0.0.1:31415/v1/models") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 6
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let (data, response) = try? await URLSession.shared.data(for: request),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let modelsResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataArray = modelsResponse["data"] as? [[String: Any]] {
            availableModels = dataArray.compactMap { $0["id"] as? String }
        }
    }
}

// MARK: - LocationManager
@MainActor final class LocationManager: NSObject, ObservableObject {
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    @Published var isLocating = false

    private let locationManager = CLLocationManager()
    private var lastRequestDate = Date.distantPast

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Sync with the real system status (crucial: otherwise we stay .notDetermined forever)
        authorizationStatus = locationManager.authorizationStatus
    }

    /// Force une nouvelle demande (bouton "Scanner" / "Réessayer").
    func requestLocation() {
        // Anti-spam: 1s minimum entre deux demandes, mais jamais de blocage définitif
        if Date().timeIntervalSince(lastRequestDate) < 1.0 { return }
        lastRequestDate = Date()
        locationError = nil
        isLocating = true

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            isLocating = false
            locationError = "Localisation refusée : autorisez ProspectorMac dans Réglages Système > Confidentialité > Localisation."
        case .authorized, .authorizedAlways:
            locationManager.requestLocation()
        @unknown default:
            isLocating = false
            break
        }
    }

    func requestLocationIfNeeded() {
        // Only request if we don't have a location yet and authorization allows it
        guard currentLocation == nil, !isLocating else { return }
        requestLocation()
    }

    func openSystemLocationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }

    func updateCity(_ location: CLLocationCoordinate2D) {
        // City geocoding would happen here
    }
}

// MARK: - LocationManagerDelegate Conformance
// Using nonisolated to satisfy CLLocationManagerDelegate protocol requirements
// while safely updating @Published properties on the main actor
extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus

            // Handle authorization changes
            switch manager.authorizationStatus {
            case .authorized, .authorizedAlways:
                // User granted permission, request location
                self.isLocating = true
                self.locationManager.requestLocation()
            case .restricted, .denied:
                self.isLocating = false
                self.locationError = "Localisation refusée dans les paramètres"
            case .notDetermined:
                // Still waiting for user decision
                break
            @unknown default:
                self.isLocating = false
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            self.currentLocation = location.coordinate
            self.locationError = nil
            self.isLocating = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // kCLErrorDomain denied = permission refusée, sinon erreur transitoire
            self.locationError = error.localizedDescription
            self.isLocating = false
        }
    }
}

// MARK: - AIService
@MainActor final class AIService: ObservableObject {
    @Published var isLoading = false
    @Published var availableModels: [String] = []
    private let baseURL = "http://127.0.0.1:31415/v1"
    private var apiKey = ""

    func setApiKey(_ key: String) {
        apiKey = key
    }

    func setModel(_ model: String) {
        // Models are stored locally
    }

    func fetchModels() async -> [String] {
        guard let url = URL(string: "\(baseURL)/models") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let models = response?["data"] as? [[String: Any]] ?? []
            self.availableModels = models.compactMap { $0["id"] as? String }
            return self.availableModels
        } catch {
            return []
        }
    }

    func checkConnection() async -> Bool {
        // /models refuse certaines clés valides : on teste via une mini-complétion.
        guard let url = URL(string: "\(baseURL)/chat/completions") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": "auto",
            "messages": [["role": "user", "content": "Réponds uniquement : OK"]],
            "max_tokens": 5,
            "temperature": 0
        ])

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func generateText(prompt: String, model: String = "auto", maxTokens: Int = 4000, temperature: Double = 0.7) async throws -> String {
        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let messages: [[String: String]] = [["role": "user", "content": prompt]]
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": temperature
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = response?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        return message?["content"] as? String ?? ""
    }

    // Résumé de l'état du site, réutilisé pour personnaliser l'email et le pitch
    func siteAuditSummary(for prospect: Prospect) -> String {
        guard let site = prospect.website, !site.isEmpty else {
            return "Pas de site web détecté"
        }
        var points: [String] = []
        if let audit = prospect.websiteAudit {
            points.append(audit.hasHttps ? "site sécurisé (HTTPS)" : "site NON sécurisé (pas de HTTPS)")
            points.append(audit.isMobileFriendly ? "adapté aux mobiles" : "NON adapté aux mobiles")
            if !audit.issues.isEmpty {
                points.append("problèmes détectés : " + audit.issues.prefix(3).joined(separator: ", "))
            }
            if audit.textContentLength > 0 && audit.textContentLength < 500 {
                points.append("contenu textuel très pauvre")
            }
        } else {
            points.append("audit non encore réalisé")
        }
        return "Site web : \(site)\nÉtat : " + points.joined(separator: " | ")
    }

    func generateEmailContent(for prospect: Prospect, sender: UserProfile) async throws -> (subject: String, body: String) {
        var senderParts: [String] = []
        if !sender.name.isEmpty { senderParts.append(sender.name) }
        if !sender.phone.isEmpty { senderParts.append("tél " + sender.phone) }
        if !sender.email.isEmpty { senderParts.append(sender.email) }
        let senderCard = senderParts.isEmpty ? "non renseigné" : senderParts.joined(separator: " — ")
        var signatureLines = [sender.name.isEmpty ? "L'équipe" : sender.name]
        if !sender.phone.isEmpty { signatureLines.append(sender.phone) }
        if !sender.email.isEmpty { signatureLines.append(sender.email) }
        let signatureFallback = signatureLines.joined(separator: "\n")
        let prompt = """
        Tu es un commercial d'une agence web française spécialisée dans les commerces locaux.
        Rédige un email de prospection personnalisé en français.

        Commerce : \(prospect.name ?? "Entreprise") (\(prospect.category ?? "commerce"))
        Ville : \(prospect.city ?? "Ville inconnue")
        \(siteAuditSummary(for: prospect))
        Expéditeur : \(senderCard)

        Règles :
        - Adapte l'angle au cas : SANS site → insiste sur l'invisibilité sur Google et les clients perdus ; site AVEC défauts → cite 1 ou 2 problèmes concrets de l'audit ; site sain → propose d'aller plus loin (référencement, réservation en ligne).
        - Ton chaleureux et professionnel, vouvoiement obligatoire, 180 mots maximum.
        - Termine par une proposition d'appel de 15 minutes et signe avec l'expéditeur ci-dessus (nom + tél + email quand ils sont fournis, sinon une signature générique).
        - Retourne UNIQUEMENT un objet JSON valide : {"subject": "...", "body": "..."} (utilise \\n pour les retours à la ligne du corps).
        """

        let rawResponse = try await generateText(prompt: prompt)

        // Nettoie les éventuels blocs ```json ... ``` autour de la réponse
        var cleaned = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Le modèle peut entourer le JSON de texte ("thinking process", explications) :
        // on extrait le premier objet {...} complet avant de parser.
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}"), start <= end,
           let data = String(cleaned[start...end]).data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
           let subject = json["subject"],
           let body = json["body"] {
            return (subject: subject, body: body)
        }

        // Repli si l'IA ne renvoie pas un JSON propre (signé avec le vrai profil)
        let fallbackBody: String
        if prospect.hasWebsite {
            fallbackBody = "Bonjour,\n\nJ'ai analysé le site web de \(prospect.name ?? "votre entreprise") et j'ai repéré quelques points qui freinent probablement vos demandes de devis (affichage mobile, vitesse, contenu).\n\nJe vous propose un appel de 15 minutes pour vous montrer concrètement ce qu'on peut améliorer.\n\nAu plaisir d'échanger,\n\n\(signatureFallback)"
        } else {
            fallbackBody = "Bonjour,\n\nSans site web, \(prospect.name ?? "votre entreprise") reste invisible pour les clients qui cherchent \(prospect.category ?? "vos services") à \(prospect.city ?? "proximité") sur Google.\n\nJe vous propose un appel de 15 minutes pour vous montrer ce qu'un site simple et efficace changerait pour vous.\n\nAu plaisir d'échanger,\n\n\(signatureFallback)"
        }
        return (subject: "Votre présence en ligne (\(prospect.name ?? "votre entreprise"))", body: fallbackBody)
    }

    func generatePitchScript(for prospect: Prospect, senderName: String) async throws -> String {
        let who = senderName.isEmpty ? "un commercial d'une agence web" : senderName
        let prompt = """
        Tu es un coach en prospection téléphonique pour une agence web française.
        Rédige un script d'appel en français pour appeler ce commerce (l'appelant se présentera comme « \(who) »).

        Commerce : \(prospect.name ?? "Entreprise") (\(prospect.category ?? "commerce"))
        Ville : \(prospect.city ?? "Ville inconnue")
        \(siteAuditSummary(for: prospect))

        Structure exacte :
        1. ACCROCHE (20 secondes : présentation + une phrase qui donne envie d'écouter, adaptée à l'état du site)
        2. ARGUMENTAIRE (3 bénéfices concrets liés à l'audit du site ci-dessus)
        3. QUESTIONS À POSER (2 ou 3 questions ouvertes pour qualifier le besoin)
        4. OBJECTIONS (« on a déjà un site », « pas le budget », « pas le temps » : une réponse courte et bienveillante pour chacune)

        Ton oral et naturel, vouvoiement, 300 mots maximum. Texte brut, sans JSON.
        """

        let raw = try await generateText(prompt: prompt)
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Contenu IA d'une page du site multi-pages : TEXTES uniquement (la mise en
    // page est locale). Petit format = rapide et rarement tronqué.
    func generateSiteContent(page: SitePage, data: SiteInput, ds: DesignSystem, photoNote: String? = nil) async throws -> String {
        let prompt = SiteBuilder.prompt(page: page, data: data, ds: ds, photoNote: photoNote)
        for model in ["qwen3.8-27b", "auto"] {
            guard let raw = try? await generateText(prompt: prompt, model: model, maxTokens: 2500, temperature: 0.85),
                  let cleaned = SiteBuilder.cleanContent(raw) else { continue }
            if SiteBuilder.contentValid(cleaned, phoneDigits: data.phoneDigits) { return cleaned }
            // Trop court ou avec un lien : on demande une version compacte propre
            let retry = prompt + "\nRappel : 3 cartes minimum, aucun lien, aucun numéro. Réponds en HTML brut."
            if let raw2 = try? await generateText(prompt: retry, model: model, maxTokens: 1500, temperature: 0.4),
               let cleaned2 = SiteBuilder.cleanContent(raw2),
               SiteBuilder.contentValid(cleaned2, phoneDigits: data.phoneDigits) { return cleaned2 }
        }
        throw URLError(.cannotParseResponse)
    }

    // Décrit une photo du commerce (ambiance, plats, décor) pour nourrir le portrait.
    // Best-effort : tout échec rend nil, le site se génère sans.
    func describePhoto(atPath path: String) async -> String? {
        guard let img = try? Data(contentsOf: URL(fileURLWithPath: path)), !img.isEmpty,
              img.count < 1_500_000,
              let url = URL(string: "http://127.0.0.1:31415/v1/chat/completions") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 75
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": "qwen-3-vl-30b-a3b-instruct",
            "max_tokens": 300, "temperature": 0.3,
            "messages": [["role": "user", "content": [
                ["type": "text", "text": "Décris en 2 phrases ce qu'on voit : plats, couleurs, décor, ambiance. Français, concret, sans inventer de nom."],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(img.base64EncodedString())"]]
            ]]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let msg = choices.first?["message"] as? [String: Any] else { return nil }
        let content = msg["content"]
        let text: String?
        if let s = content as? String { text = s }
        else if let parts = content as? [[String: Any]] {
            text = parts.compactMap { $0["text"] as? String }.joined(separator: " ")
        } else { text = nil }
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), t.count > 20 else { return nil }
        return String(t.prefix(400))
    }

    // Extrait le vrai email/téléphone depuis les pages d'un site (via le scraper local)
    func fetchSiteContact(website: String) async -> (email: String?, phone: String?) {
        guard let url = URL(string: "http://127.0.0.1:31416/scrape/contact") else { return (nil, nil) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["url": website])
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            var email = json?["email"] as? String
            var phone = json?["phone"] as? String
            if email?.isEmpty == true { email = nil }
            if phone?.isEmpty == true { phone = nil }
            return (email, phone)
        } catch {
            return (nil, nil)
        }
    }

    func auditWebsite(url: String) async throws -> [String: Any] {
        guard let endpointURL = URL(string: "http://127.0.0.1:31416/scrape/website") else {
            return [
                "isMobileFriendly": true,
                "textContentLength": 0,
                "performanceScore": 0,
                "accessibilityScore": 0,
                "issues": ["URL invalide"]
            ]
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["url": url])

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [
                "isMobileFriendly": true,
                "textContentLength": 0,
                "performanceScore": 0,
                "accessibilityScore": 0,
                "issues": []
            ]
        }

        guard let audit = response["audit"] as? [String: Any] else {
            return [
                "isMobileFriendly": true,
                "textContentLength": 0,
                "performanceScore": 50,
                "accessibilityScore": 50,
                "issues": ["Audit non disponible"]
            ]
        }

        var issues: [String] = []

        if let hasHttps = audit["hasHttps"] as? Bool, !hasHttps {
            issues.append("Site non sécurisé (HTTPS)")
        }

        if let isMobileFriendly = audit["isMobileFriendly"] as? Bool, !isMobileFriendly {
            issues.append("Pas mobile-friendly")
        }

        if let textLength = audit["textContentLength"] as? Int, textLength < 500 {
            issues.append("Contenu insuffisant")
        }

        return [
            "isMobileFriendly": audit["isMobileFriendly"] as? Bool ?? true,
            "textContentLength": audit["textContentLength"] as? Int ?? 0,
            "performanceScore": 50,
            "accessibilityScore": 50,
            "issues": issues
        ]
    }
}

// MARK: - ProspectorMacApp
@main
struct ProspectorMacApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var aiService = AIService()
    @StateObject private var database = DatabaseManager()

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    init() {
        // Setup ESC key handler using NSEvent
        setupEscapeKeyHandler()
    }

    private static var escapeMonitor: Any?

    private func setupEscapeKeyHandler() {
        // Retain the monitor, otherwise it is deallocated immediately
        Self.escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape key
                // Ne ferme que les sheets/fenêtres secondaires, jamais en boucle
                if NSApp.keyWindow != nil {
                    NSApp.keyWindow?.close()
                    return nil
                }
            }
            return event
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            TabView {
                // Pas de NavigationView : sa colonne detail vide elargissait la fenetre pour rien
                ContentView()
                    .environmentObject(appState)
                    .environmentObject(locationManager)
                    .environmentObject(aiService)
                    .environmentObject(database)
                    .tabItem {
                        Label("Scanner", systemImage: "magnifyingglass")
                    }
                    .tag(0)

                ProspectMapView()
                    .environmentObject(appState)
                    .environmentObject(locationManager)
                    .environmentObject(aiService)
                    .environmentObject(database)
                    .tabItem {
                        Label("Carte", systemImage: "map")
                    }
                    .tag(1)
            }
            .frame(minWidth: 1000, minHeight: 650)
            .task {
                // L'IA a besoin de la clé dès le lancement (email/pitch/maquette l'utilisent)
                await MainActor.run { aiService.setApiKey(appState.apiKey) }
                // Test connection to FreeLLMAPI on launch
                _ = await appState.testConnection()
            }
            // Popup d'identité au lancement (attachée au TabView, pas à ContentView :
            // deux .sheet sur la même vue = freeze/conflit SwiftUI)
            .sheet(isPresented: $appState.showingOnboarding) {
                OnboardingView()
                    .environmentObject(appState)
            }
        }
        .defaultSize(width: 1080, height: 700)

        SettingsPhase(appState: appState, aiService: aiService)
    }
}

// MARK: - Window Command for Settings
struct SettingsPhase: Scene {
    @ObservedObject var appState: AppState
    @ObservedObject var aiService: AIService

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(aiService)
                .frame(maxWidth: 500, minHeight: 400)
        }
    }
}

// MARK: - OnboardingView (popup d'identité au lancement)
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bienvenue 👋")
                .font(.title)
                .bold()
            Text("Qui signe les emails et les appels ? Ces infos serviront de signature dans toute l'appli.")
                .foregroundColor(.secondary)
            TextField("Ton nom (ex : Julien Martin)", text: $name)
                .textFieldStyle(.roundedBorder)
            TextField("Ton téléphone (ex : 06 12 34 56 78)", text: $phone)
                .textFieldStyle(.roundedBorder)
            TextField("Ton email (ex : julien@monagence.fr)", text: $email)
                .textFieldStyle(.roundedBorder)
            if name.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("Indique au moins ton nom pour continuer.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                Spacer()
                Button("Enregistrer") {
                    appState.saveProfile(name: name, phone: phone, email: email)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text("Modifiable à tout moment dans Réglages → Mon profil.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(minWidth: 420)
        .onAppear {
            name = appState.userProfile.name
            phone = appState.userProfile.phone
            email = appState.userProfile.email
        }
    }
}

// MARK: - ContentView
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var aiService: AIService
    @EnvironmentObject var database: DatabaseManager

    @State private var showingSettings = false
    @State private var selectedProspect: Prospect?
    @State private var isShowingDetail = false
    @State private var scanInProgress = false
    @State private var scanningPhase: ScanningPhase = .idle
    @State private var scanningMessage: String = ""
    @State private var totalProcessed: Int = 0
    @State private var scannedProspects: Set<UUID> = []
    @State private var showingClearConfirm = false
    @State private var lastScanWasSample = false
    @State private var bulkEnriching = false
    @State private var bulkDone = 0
    @State private var bulkTotal = 0
    @State private var bulkLabel = ""
    @State private var bulkTask: Task<Void, Never>? = nil
    @State private var sortOption: SortOption = .name

    enum SortOption: String, CaseIterable {
        case name = "Nom"
        case company = "Raison sociale"
        case distance = "Distance"
    }

    enum ScanningPhase: String {
        case idle = "Idle", locating = "Localisation", searching = "Recherche", processing = "Analyse", complete = "Terminé"

        var description: String {
            self.rawValue
        }
    }

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Action Bar
                HStack {
                    Button(action: startScan) {
                        Label(scanningPhase == .idle ? "Scanner autour de moi" : "Réanalyser", systemImage: "map.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(scanningPhase != .idle)

                    if scanningPhase != .idle && scanningPhase != .complete {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .tint(.accentColor)
                            .frame(width: 20, height: 20)
                            .transition(.opacity)
                    }

                    Spacer()

                    // Loading animation indicator
                    if scanningPhase != .idle {
                        HStack(spacing: 8) {
                            Text(scanningPhase.description)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if !scanningMessage.isEmpty {
                                Text("(\(scanningMessage))")
                                    .font(.caption2)
                                    .foregroundColor(Color(NSColor.textColor).opacity(0.7))
                            }
                        }
                    }

                    Spacer()

                    // Radius selector
                    Picker("Rayon", selection: $appState.radius) {
                        Text("1 km").tag(1.0)
                        Text("5 km").tag(5.0)
                        Text("10 km").tag(10.0)
                        Text("20 km").tag(20.0)
                        Text("30 km").tag(30.0)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    Spacer()

                    // Filter selector
                    Menu {
                        Button("Tous") { appState.filterStatus = .all }
                        Button("Sans site web") { appState.filterStatus = .noSite }
                        Button("Site obsolète") { appState.filterStatus = .siteOutdated }
                        Button("Prêts à contacter") { appState.filterStatus = .readyToContact }
                    } label: {
                        Label("Filtrer", systemImage: "line.3.horizontal.decrease")
                    }

                    Spacer()

                    // Tri : nom / raison sociale / distance au point de localisation
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { opt in
                            Button(opt.rawValue) { sortOption = opt }
                        }
                    } label: {
                        Label("Tri : \(sortOption.rawValue)", systemImage: "arrow.up.arrow.down")
                    }

                    Spacer()

                    // Enrichissement groupé : retrouve tél/site/avis pour tous les commerces sans téléphone
                    if bulkEnriching {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("\(bulkDone)/\(bulkTotal) \(bulkLabel)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Button("Stop") { bulkTask?.cancel() }
                                .font(.caption)
                        }
                    } else {
                        Button(action: startBulkEnrich) {
                            Label("Trouver les coordonnées", systemImage: "phone.badge.plus")
                        }
                        .help("Recherche le vrai téléphone, site, email et avis de chaque commerce incomplet sur Google Maps")
                        .disabled(database.prospects.isEmpty || scanningPhase != .idle)
                    }

                    Spacer()

                    // Connection status indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(appState.connectionStatus == .connected ? Color.green : Color.red)
                            .frame(width: 10, height: 10)

                        Text(connectionStatusText)
                            .font(.caption)
                    }
                    .onTapGesture {
                        showingSettings = true
                    }

                    Spacer()

                    // Clear button (ex: supprimer les anciennes données Paris)
                    Button(role: .destructive, action: { showingClearConfirm = true }) {
                        Label("Effacer", systemImage: "trash")
                    }
                    .help("Supprimer tous les prospects")
                    .disabled(database.prospects.isEmpty)

                    // Settings button
                    Button(action: { showingSettings = true }) {
                        Label("Réglages", systemImage: "gearshape")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))
                .border(Color(NSColor.separatorColor), width: 0.5)

                Divider()

                // Bandeau localisation : montre la vraie position ou explique le repli Paris
                if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                    HStack(spacing: 8) {
                        Image(systemName: "location.slash")
                            .foregroundColor(.orange)
                        Text("Localisation refusée — le scan utilise Paris par défaut.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Autoriser...") { locationManager.openSystemLocationSettings() }
                            .buttonStyle(.link)
                            .font(.caption)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12))
                    Divider()
                } else if let loc = locationManager.currentLocation {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(String(format: "Position : %.4f, %.4f", loc.latitude, loc.longitude))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if locationManager.isLocating {
                            ProgressView().scaleEffect(0.6)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    Divider()
                }

                // Progression de l'enrichissement groupé des coordonnées
                if bulkEnriching {
                    HStack(spacing: 8) {
                        ProgressView(value: Double(bulkDone), total: Double(max(bulkTotal, 1)))
                            .frame(width: 160)
                        Text("Coordonnées : \(bulkDone)/\(bulkTotal) — \(bulkLabel)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Button("Stop") { bulkTask?.cancel() }
                            .font(.caption)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.10))
                    Divider()
                }

                // Avertissement données de démo (Paris) quand OSM était injoignable
                if lastScanWasSample {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Données de démo (Paris) — OpenStreetMap injoignable. Effacez puis rescannez.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12))
                    Divider()
                }

                // Prospects Grid with loading overlay
                ScrollView {
                    GroupBox {
                        VStack(spacing: 16) {
                            if scanningPhase == .locating {
                                VStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(1.5)
                                    Text("Détection de votre position...")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                            } else if scanningPhase == .searching {
                                VStack(spacing: 8) {
                                    ProgressView(value: CGFloat(totalProcessed), total: 100)
                                        .padding(.horizontal)
                                    Text("Recherche des commerces autour de vous...")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                            } else if scanningPhase == .processing {
                                VStack(spacing: 8) {
                                    ProgressView(value: CGFloat(totalProcessed), total: 100)
                                        .padding(.horizontal)
                                    Text("Analyse des sites web (\(totalProcessed)/\(database.prospects.count))...")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                            } else if database.prospects.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)

                                    Text("Cliquez sur « Scanner autour de moi » pour découvrir vos prospects locaux")
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, minHeight: 300)
                            } else {
                                let filteredProspects = filteredProspectsList
                                if filteredProspects.isEmpty {
                                    VStack {
                                        Text("Aucun prospect correspond au filtre")
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 200)
                                } else {
                                    LazyVGrid(columns: columns, spacing: 24) {
                                        ForEach(filteredProspects) { prospect in
                                            ProspectCard(prospect: prospect)
                                                .onTapGesture {
                                                    selectedProspect = prospect
                                                    isShowingDetail = true
                                                }
                                        }
                                    }
                                    .padding()
                                }
                            }
                        }
                        .padding()
                    }
                    .cornerRadius(8)
                }
            }

            // Settings Sheet (attachée au VStack) + Detail Sheet (attachée à une vue de fond
            // distincte : deux .sheet sur la même vue = freeze/conflit SwiftUI)
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(appState)
                    .environmentObject(aiService)
                    .environmentObject(database)
                    .frame(maxWidth: 500, maxHeight: 440)
            }
            .background(
                EmptyView().sheet(item: $selectedProspect) { prospect in
                    ProspectDetailView(prospect: prospect)
                        .environmentObject(database)
                        .environmentObject(aiService)
                        .frame(maxWidth: 800, maxHeight: 600)
                }
            )
            .alert("Tout effacer ?", isPresented: $showingClearConfirm) {
                Button("Effacer", role: .destructive) {
                    database.clearAll()
                    lastScanWasSample = false
                }
                Button("Annuler", role: .cancel) { }
            } message: {
                Text("Supprime tous les prospects enregistrés (y compris les anciennes données de Paris).")
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            locationManager.requestLocationIfNeeded()
            Task {
                await aiService.fetchModels()
            }
        }
    }

    private var connectionStatusText: String {
        switch appState.connectionStatus {
        case .connected:
            return "Connecté"
        case .connecting:
            return "Connexion..."
        case .disconnected:
            return "Déconnecté"
        case .error:
            return "Erreur"
        case .unknown:
            return "?"
        }
    }

    private var filteredProspectsList: [Prospect] {
        let base: [Prospect]
        switch appState.filterStatus {
        case .all:
            base = database.prospects
        case .noSite:
            base = database.prospects.filter { !$0.hasWebsite }
        case .siteOutdated:
            base = database.prospects.filter { $0.websiteStatus == .outdated }
        case .readyToContact:
            base = database.prospects.filter { $0.isReady }
        case .contacted:
            base = database.prospects.filter { $0.status == .contacted }
        }
        switch sortOption {
        case .name:
            return base.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .company:
            return base.sorted {
                let a = $0.raisonSociale ?? $0.nomCommercial ?? $0.name ?? ""
                let b = $1.raisonSociale ?? $1.nomCommercial ?? $1.name ?? ""
                return a < b
            }
        case .distance:
            guard let loc = locationManager.currentLocation else { return base }
            return base.sorted {
                distanceKm(from: loc, to: $0) < distanceKm(from: loc, to: $1)
            }
        }
    }

    private func distanceKm(from loc: CLLocationCoordinate2D, to p: Prospect) -> Double {
        let R = 6371.0
        let dLat = (p.latitude - loc.latitude) * .pi / 180
        let dLon = (p.longitude - loc.longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(loc.latitude * .pi / 180) * cos(p.latitude * .pi / 180)
            * sin(dLon / 2) * sin(dLon / 2)
        return 2 * R * asin(sqrt(a))
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(minimum: 300), spacing: 24)]
    }

    private func startScan() {
        // Reset state
        scanningPhase = .locating
        scanningMessage = "Obtention de votre position..."
        totalProcessed = 0
        scannedProspects.removeAll()

        Task {
            await performScan()
        }
    }

    private func performScan() async {
        // 1. Demande la vraie position et ATTEND jusqu'à 8s (au lieu de scanner immédiatement)
        if locationManager.currentLocation == nil {
            locationManager.requestLocation()
            for _ in 0..<16 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if locationManager.currentLocation != nil { break }
                // Si permission refusée, inutile d'attendre 8s
                if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                    break
                }
            }
        }

        // 2. Fallback Paris UNIQUEMENT si vraiment aucune position, en le disant clairement
        let location: CLLocationCoordinate2D
        if let loc = locationManager.currentLocation {
            location = loc
        } else {
            location = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
            scanningMessage = "Position indisponible — repli sur Paris"
        }

        scanningPhase = .searching
        if scanningMessage.isEmpty || scanningMessage == "Obtention de votre position..." {
            scanningMessage = "Recherche des commerces..."
        }

        let places = await searchPlaces(coordinates: location, radius: appState.radius)

        await MainActor.run {
            totalProcessed = places.count
        }

        scanningPhase = .processing
        scanningMessage = "Analyse des sites web..."

        var newProspects: [Prospect] = []

        for place in places {
            let prospect = Prospect(
                id: UUID(),
                name: place.name,
                category: place.types.first ?? place.category,
                city: ((place.city?.isEmpty == false && place.city != "Ville inconnue") ? place.city! : (cityFromAddress(place.formattedAddress) ?? "Ville inconnue")),
                address: place.formattedAddress,
                latitude: place.latitude ?? location.latitude,
                longitude: place.longitude ?? location.longitude,
                website: place.website,
                hasWebsite: place.website != nil,
                websiteStatus: place.website != nil ? .secure : .noSite,
                email: place.email,
                phone: place.phone,
                siret: place.siret,
                raisonSociale: place.raisonSociale,
                nomCommercial: place.nomCommercial,
                googleRating: place.rating,
                googleReviewCount: place.reviewCount,
                isSample: place.isSample,
                createdAt: Date(),
                lastUpdated: Date()
            )
            newProspects.append(prospect)
        }

        await MainActor.run {
            for prospect in newProspects {
                // Évite les doublons entre scans (même nom + même lieu)
                if !database.containsSame(as: prospect) {
                    database.updateProspect(prospect)
                }
            }
        }

        await MainActor.run {
            scanningPhase = .processing
            scanningMessage = "Génération des éléments de contact..."
        }

        // Generate emails and analyze websites
        await generateContactInfo(for: newProspects)

        await MainActor.run {
            scanningPhase = .complete
            scanningMessage = "\(newProspects.count) prospects trouvés"
            lastScanWasSample = !newProspects.isEmpty && newProspects.allSatisfy(\.isSample)
        }

        // Complete after delay to show completion
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        await MainActor.run {
            scanningPhase = .idle
        }
    }

    // Enrichissement groupé : même appel Google Maps que la fiche, mais pour tous
    // les commerces sans téléphone. ~10-15 s par commerce, annulable via Stop.
    private func startBulkEnrich() {
        // Inclut les commerces sans tél OU sans email : Google peut révéler un site à scraper
        let missing = database.prospects.filter { ($0.phone ?? "").isEmpty || ($0.email ?? "").isEmpty }
        guard !missing.isEmpty else {
            scanningMessage = "Tous les commerces ont déjà un téléphone"
            scanningPhase = .complete
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run { scanningPhase = .idle }
            }
            return
        }
        bulkTask?.cancel()
        bulkEnriching = true
        bulkDone = 0
        bulkTotal = missing.count
        bulkLabel = "Démarrage..."
        bulkTask = Task {
            for prospect in missing {
                if Task.isCancelled { break }
                await MainActor.run {
                    bulkLabel = prospect.name ?? "Commerce"
                }
                await enrichOneWithGoogle(id: prospect.id)
                if Task.isCancelled { break }
                await MainActor.run { bulkDone += 1 }
                // Petite pause anti-blocage Google
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
            await MainActor.run {
                bulkEnriching = false
                bulkTask = nil
                bulkLabel = ""
            }
        }
    }

    // Un seul commerce enrichi via Google Maps + email du site trouvé (partagé fiche/bulk)
    private func enrichOneWithGoogle(id: UUID) async {
        guard var current = database.prospects.first(where: { $0.id == id }),
              let url = URL(string: "http://127.0.0.1:31416/scrape/google-place") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "name": current.name ?? "",
            "city": current.city ?? ""
        ])
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    json["error"] == nil else { return }
            if let phone = json["phone"] as? String, !phone.isEmpty { current.phone = phone }
            if let site = json["website"] as? String, !site.isEmpty {
                current.website = site
                current.hasWebsite = true
                if current.websiteStatus == .noSite { current.websiteStatus = .secure }
            }
            if let rating = json["rating"] as? Double { current.googleRating = rating }
            if let rc = json["reviewsCount"] as? Int { current.googleReviewCount = rc }
            if let rw = json["reviews"] as? [[String: Any]], !rw.isEmpty {
                let parsed: [GoogleReview] = rw.compactMap { r in
                    guard let text = r["text"] as? String, !text.isEmpty else { return nil }
                    return GoogleReview(author: (r["author"] as? String) ?? "Client Google",
                                        rating: (r["rating"] as? Double) ?? (r["rating"] as? Int).map(Double.init),
                                        text: text, date: r["date"] as? String)
                }
                if !parsed.isEmpty { current.googleReviews = parsed }
            }
            if let hours = json["hours"] as? [String], !hours.isEmpty { current.openingHours = hours }
            if let photos = json["photos"] as? [String], !photos.isEmpty { current.photoURLs = Array(photos.prefix(6)) }
            if let os = json["openState"] as? String, !os.isEmpty {
                var h = current.openingHours ?? []
                let line = "Actuellement : " + os
                if !h.contains(line) { h.insert(line, at: 0); current.openingHours = h }
            }
            if let addr = json["address"] as? String, !addr.isEmpty,
               (current.address == nil || current.address!.isEmpty) {
                current.address = addr
            }
            if current.city == nil || current.city == "Ville inconnue" {
                if let c = cityFromAddress(current.address) { current.city = c }
                else if let c = await fetchReverseCity(lat: current.latitude, lon: current.longitude) { current.city = c }
            }
            current.lastUpdated = Date()
            await MainActor.run { database.updateProspect(current) }
            if let site = current.website, !site.isEmpty,
               (current.email ?? "").isEmpty || (current.phone ?? "").isEmpty {
                let real = await aiService.fetchSiteContact(website: site)
                if let email = real.email, !email.isEmpty {
                    var withEmail = database.prospects.first(where: { $0.id == id }) ?? current
                    withEmail.email = email
                    if let p = real.phone, !p.isEmpty, (withEmail.phone ?? "").isEmpty {
                        withEmail.phone = p
                    }
                    await MainActor.run { database.updateProspect(withEmail) }
                }
            }
        } catch {
            // Un commerce injoignable ne bloque pas les suivants
        }
    }

    private func generateContactInfo(for prospects: [Prospect]) async {
        for i in prospects.indices {
            await MainActor.run {
                totalProcessed = i + 1
            }

            var updated = prospects[i]

            // 1) Vrais email/téléphone extraits du site web quand il existe,
            //    puis audit du site (sauve contact + audit en une fois)
            if let website = updated.website, !website.isEmpty {
                let real = await fetchRealContactInfo(website: website)
                if let email = real.email, !email.isEmpty { updated.email = email }
                if let phone = real.phone, !phone.isEmpty { updated.phone = phone }
                await analyzeWebsite(prospect: updated, url: website)
                if let saved = database.prospects.first(where: { $0.id == updated.id }) {
                    updated = saved
                }
            }

            // 2) Aucune fabrication : seuls les contacts réellement trouvés sont affichés.
            //    Les manques se complètent à la main dans la fiche (bouton Sauvegarder).
            await MainActor.run {
                database.updateProspect(updated)
            }
        }
    }

    // Extrait le vrai email/téléphone depuis les pages du site (via AIService)
    private func fetchRealContactInfo(website: String) async -> (email: String?, phone: String?) {
        await aiService.fetchSiteContact(website: website)
    }

    private func analyzeWebsite(prospect: Prospect, url: String) async {
        do {
            let auditResult = try await aiService.auditWebsite(url: url)

            await MainActor.run {
                var updatedProspect = prospect
                updatedProspect.websiteAudit = WebsiteAudit(
                    hasHttps: true,
                    isMobileFriendly: auditResult["isMobileFriendly"] as? Bool ?? false,
                    textContentLength: auditResult["textContentLength"] as? Int ?? 0,
                    performanceScore: auditResult["performanceScore"] as? Int ?? 0,
                    accessibilityScore: auditResult["accessibilityScore"] as? Int ?? 0,
                    issues: auditResult["issues"] as? [String] ?? []
                )

                database.updateProspect(updatedProspect)
            }
        } catch {
            print("Website audit error for \(prospect.name ?? "unknown"): \(error)")
        }
    }

    private func scanNearbyBusinesses() async {
        guard let location = locationManager.currentLocation else { return }

        // Search for businesses using the Express server
        let places = await searchPlaces(coordinates: location, radius: appState.radius)

        for place in places {
            let prospect = Prospect(
                id: UUID(),
                name: place.name,
                category: place.types.first ?? place.category,
                city: ((place.city?.isEmpty == false && place.city != "Ville inconnue") ? place.city! : (cityFromAddress(place.formattedAddress) ?? "Ville inconnue")),
                address: place.formattedAddress,
                latitude: place.latitude ?? location.latitude,
                longitude: place.longitude ?? location.longitude,
                website: place.website,
                hasWebsite: place.website != nil,
                websiteStatus: place.website != nil ? .secure : .noSite,
                email: place.email,
                phone: place.phone,
                siret: place.siret,
                raisonSociale: place.raisonSociale,
                nomCommercial: place.nomCommercial,
                googleRating: place.rating,
                googleReviewCount: place.reviewCount,
                isSample: place.isSample,
                createdAt: Date(),
                lastUpdated: Date()
            )

            database.updateProspect(prospect)
        }
    }

    private func searchPlaces(coordinates: CLLocationCoordinate2D, radius: Double) async -> [PlaceResult] {
        var results: [PlaceResult] = []

        let query = "http://127.0.0.1:31416/scrape/google-maps"
        guard let url = URL(string: query) else { return [] }

        let body: [String: Any] = [
            "latitude": coordinates.latitude,
            "longitude": coordinates.longitude,
            "radius": Int(radius * 1000)
        ]

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let places = response?["places"] as? [[String: Any]] ?? []

            for place in places {
                results.append(PlaceResult(
                    name: place["name"] as? String,
                    types: place["types"] as? [String] ?? [],
                    category: place["category"] as? String ?? "",
                    city: place["city"] as? String ?? "Ville inconnue",
                    formattedAddress: place["address"] as? String ?? "",
                    website: place["website"] as? String,
                    email: place["email"] as? String,
                    phone: place["phone"] as? String,
                    latitude: place["latitude"] as? Double,
                    longitude: place["longitude"] as? Double,
                    rating: place["rating"] as? Double,
                    reviewCount: place["reviews"] as? Int,
                    isSample: place["sample"] as? Bool ?? false,
                    siret: place["siret"] as? String,
                    raisonSociale: place["raisonSociale"] as? String,
                    nomCommercial: place["nomCommercial"] as? String
                ))
            }
        } catch {
            print("Scraping error: \(error)")
        }

        return results
    }
}

// MARK: - PlaceResult Helper
extension ContentView {
    struct PlaceResult {
        let name: String?
        let types: [String]
        let category: String?
        let city: String?
        let formattedAddress: String?
        let website: String?
        let email: String?
        let phone: String?
        let latitude: Double?
        let longitude: Double?
        let rating: Double?
        let reviewCount: Int?
        let isSample: Bool
        let siret: String?
        let raisonSociale: String?
        let nomCommercial: String?

        init(name: String? = nil, types: [String] = [], category: String? = nil, city: String? = nil, formattedAddress: String? = nil, website: String? = nil, email: String? = nil, phone: String? = nil, latitude: Double? = nil, longitude: Double? = nil, rating: Double? = nil, reviewCount: Int? = nil, isSample: Bool = false, siret: String? = nil, raisonSociale: String? = nil, nomCommercial: String? = nil) {
            self.name = name
            self.types = types
            self.category = category
            self.city = city
            self.formattedAddress = formattedAddress
            self.website = website
            self.email = email
            self.phone = phone
            self.latitude = latitude
            self.longitude = longitude
            self.rating = rating
            self.reviewCount = reviewCount
            self.isSample = isSample
            self.siret = siret
            self.raisonSociale = raisonSociale
            self.nomCommercial = nomCommercial
        }
    }
}

// Icône info : survol = infobulle SIRENE, clic = fiche complète (copiable)
struct OfficialInfoBadge: View {
    let prospect: Prospect
    @State private var showPopover = false

    private var tooltip: String {
        let rs = (prospect.raisonSociale?.isEmpty == false) ? prospect.raisonSociale! : "Non renseignée"
        let nc = (prospect.nomCommercial?.isEmpty == false) ? prospect.nomCommercial! : "Non renseigné"
        let siret = (prospect.siret?.isEmpty == false) ? prospect.siret! : "Non renseigné"
        return "Raison sociale : \(rs)\nNom commercial : \(nc)\nSIRET : \(siret)\nGPS : \(String(format: "%.5f", prospect.latitude)), \(String(format: "%.5f", prospect.longitude))"
    }

    var body: some View {
        Button(action: { showPopover.toggle() }) {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .popover(isPresented: $showPopover) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Informations officielles").font(.headline)
                infoLine(label: "Raison sociale", value: prospect.raisonSociale)
                infoLine(label: "Nom commercial", value: prospect.nomCommercial)
                infoLine(label: "SIRET", value: prospect.siret)
                HStack {
                    Text("GPS :").foregroundColor(.secondary)
                    Text("\(String(format: "%.5f", prospect.latitude)), \(String(format: "%.5f", prospect.longitude))")
                        .textSelection(.enabled)
                }.font(.caption)
            }
            .padding()
            .frame(minWidth: 280)
        }
    }

    private func infoLine(label: String, value: String?) -> some View {
        HStack {
            Text(label + " :").foregroundColor(.secondary)
            Text((value?.isEmpty == false) ? value! : "Non renseigné")
                .textSelection(.enabled)
        }.font(.caption)
    }
}

// MARK: - ProspectCard
struct ProspectCard: View {
    let prospect: Prospect
    @EnvironmentObject var locationManager: LocationManager

    private var distanceText: String? {
        guard let loc = locationManager.currentLocation else { return nil }
        let R = 6371.0
        let dLat = (prospect.latitude - loc.latitude) * .pi / 180
        let dLon = (prospect.longitude - loc.longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(loc.latitude * .pi / 180) * cos(prospect.latitude * .pi / 180)
            * sin(dLon / 2) * sin(dLon / 2)
        let km = 2 * R * asin(sqrt(a))
        return km < 1 ? String(format: "à %d m", Int(km * 1000)) : String(format: "à %.1f km", km)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(prospect.name ?? "Entreprise")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                OfficialInfoBadge(prospect: prospect)

                Spacer()

                if prospect.isSample {
                    Text("Démo")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }

                if let badge = prospect.opportunityBadge {
                    Text(badge)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                }
            }

            HStack(spacing: 6) {
                Text(prospect.category ?? "Non catégorisé")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let dist = distanceText {
                    Text("· \(dist)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            Text(prospect.city ?? "Ville inconnue")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let website = prospect.website {
                Text(website)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let phone = prospect.phone, !phone.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.secondary)
                    Text(phone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let email = prospect.email, !email.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.secondary)
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if let rating = prospect.googleRating {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text(String(format: "%.1f", rating))
                        .font(.caption)
                }
            }

            HStack(spacing: 12) {
                if prospect.email != nil {
                    Label(prospect.email ?? "", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                if prospect.figmaUrl != nil {
                    Label("Figma OK", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - ProspectDetailView
struct ProspectDetailView: View {
    let prospect: Prospect
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var database: DatabaseManager
    @EnvironmentObject var aiService: AIService
    @Environment(\.dismiss) private var dismiss

    @State private var isGeneratingMaquette = false
    @State private var isGeneratingEmail = false
    @State private var isGeneratingPitch = false
    @State private var editEmail = ""
    @State private var editPhone = ""
    @State private var editWebsite = ""
    @State private var editCity = ""
    @State private var emailError: String?
    @State private var pitchError: String?
    @State private var maquetteError: String?
    @State private var isEnriching = false
    @State private var enrichError: String?

    // Version à jour depuis la base (l'IA et le scan mettent à jour en arrière-plan)
    private var liveProspect: Prospect {
        database.prospects.first(where: { $0.id == prospect.id }) ?? prospect
    }

    private var emailAngleHint: String {
        let p = liveProspect
        if !p.hasWebsite {
            return "Angle : commerce sans site web — invisibilité sur Google."
        }
        if let audit = p.websiteAudit, !audit.issues.isEmpty {
            return "Angle : \(audit.issues.count) point(s) détecté(s) — " + audit.issues.prefix(2).joined(separator: ", ") + "."
        }
        return "Angle : site existant — aller plus loin (référencement, contenus)."
    }

    var body: some View {
        // Pas de NavigationView : dans un .sheet macOS ça freeze (même cause que Réglages).
        VStack(spacing: 0) {
            HStack {
                Text(prospect.name ?? "Détails du prospect")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button("Fermer") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GroupBox(label: Text("Informations Principales")) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(prospect.name ?? "Entreprise")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text(prospect.category ?? "Non spécifié")
                                    .foregroundColor(.secondary)

                                Text(prospect.address ?? "Adresse non renseignée")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                if let website = prospect.website, let url = URL(string: website) {
                                    Link(website, destination: url)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }

                            Spacer()

                            if let badge = prospect.opportunityBadge {
                                Text(badge)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.2))
                                    .foregroundColor(.red)
                                    .cornerRadius(4)
                            }
                        }
                        .padding()
                    }

                    GroupBox(label: Text("Coordonnées (modifiables)")) {
                        VStack(alignment: .leading, spacing: 8) {
                            coordRow(label: "Email :", text: $editEmail, placeholder: "Non trouvé")
                            coordRow(label: "Tél :", text: $editPhone, placeholder: "Non trouvé")
                            coordRow(label: "Site web :", text: $editWebsite, placeholder: "Aucun site")
                            coordRow(label: "Ville :", text: $editCity, placeholder: "Ville inconnue")
                            if let siret = prospect.siret, !siret.isEmpty {
                                HStack {
                                    Text("SIRET :")
                                        .foregroundColor(.secondary)
                                    Text(siret)
                                        .foregroundColor(.primary)
                                        .textSelection(.enabled)
                                }
                            }
                            HStack {
                                Text("Seuls les contacts réellement trouvés sont affichés — complétez à la main si besoin.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Sauvegarder") { saveContactEdits() }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!contactEdited)
                            }
                        }
                        .padding()
                    }

                    GroupBox(label: Text("Informations officielles (SIRENE)")) {
                        VStack(alignment: .leading, spacing: 6) {
                            officialRow(label: "Raison sociale", value: liveProspect.raisonSociale)
                            officialRow(label: "Nom commercial", value: liveProspect.nomCommercial)
                            officialRow(label: "SIRET", value: liveProspect.siret)
                            HStack {
                                Text("GPS :")
                                    .foregroundColor(.secondary)
                                    .frame(width: 110, alignment: .leading)
                                Text("\(String(format: "%.5f", liveProspect.latitude)), \(String(format: "%.5f", liveProspect.longitude))")
                                    .textSelection(.enabled)
                            }.font(.caption)
                            if liveProspect.raisonSociale == nil && liveProspect.nomCommercial == nil && liveProspect.siret == nil {
                                Text("Pas de données SIRENE pour ce commerce (source OSM / Photon). Rescannez pour tenter SIRENE.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                    }

                    GroupBox(label: Text("Recherche Google")) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let err = enrichError {
                                Text(err).font(.caption).foregroundColor(.red)
                            }
                            if isEnriching {
                                ProgressView("Recherche sur Google Maps...")
                            } else {
                                Text("Retrouve le vrai téléphone, le site web et les avis du commerce sur Google Maps.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button("Rechercher sur Google Maps") {
                                    Task { await enrichFromGoogle() }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding()
                    }

                    if prospect.hasWebsite {
                        GroupBox(label: Text("Site Web")) {
                            VStack(alignment: .leading, spacing: 8) {
                                if let website = prospect.website, let url = URL(string: website) {
                                    Link(website, destination: url)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Text("Statut: \(prospect.websiteStatus.rawValue.capitalized)")
                            }
                            .padding()
                        }
                    }

                    GroupBox(label: Text("Email personnalisé")) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let err = emailError {
                                Text(err).font(.caption).foregroundColor(.red)
                            }
                            if let subject = liveProspect.emailSubject, let body = liveProspect.emailBody {
                                Text(subject)
                                    .font(.headline)
                                Text(body)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .padding(8)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(6)
                                HStack {
                                    Button("Copier") {
                                        copyToClipboard("\(subject)\n\n\(body)")
                                    }
                                    Button("Régénérer") {
                                        Task { await generateEmail() }
                                    }
                                    .disabled(isGeneratingEmail)
                                    if isGeneratingEmail { ProgressView().scaleEffect(0.7) }
                                }
                            } else if isGeneratingEmail {
                                ProgressView("Rédaction de l'email...")
                            } else {
                                Text(emailAngleHint)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button("Générer l'email personnalisé") {
                                    Task { await generateEmail() }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding()
                    }

                    GroupBox(label: Text("Pitch d'appel")) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let err = pitchError {
                                Text(err).font(.caption).foregroundColor(.red)
                            }
                            if let pitch = liveProspect.pitchScript, !pitch.isEmpty {
                                Text(pitch)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .padding(8)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(6)
                                HStack {
                                    Button("Copier") {
                                        copyToClipboard(pitch)
                                    }
                                    Button("Régénérer") {
                                        Task { await generatePitch() }
                                    }
                                    .disabled(isGeneratingPitch)
                                    if isGeneratingPitch { ProgressView().scaleEffect(0.7) }
                                }
                            } else if isGeneratingPitch {
                                ProgressView("Rédaction du pitch...")
                            } else {
                                Text("Script d'appel adapté à l'état du site : accroche, argumentaire, questions et objections.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button("Générer le pitch d'appel") {
                                    Task { await generatePitch() }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding()
                    }

                    if let err = maquetteError {
                        Text(err).font(.caption).foregroundColor(.red)
                    }
                    if isGeneratingMaquette {
                        ProgressView("Génération de l'aperçu...")
                    } else if let existing = siteFileURL {
                        HStack {
                            Button("Voir le site généré") {
                                persistAdoptedDir(existing.deletingLastPathComponent())
                                openMaquetteWindow(fileURL: existing)
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Régénérer") {
                                Task { await generateAndOpenMaquette(force: true) }
                            }
                            Button("Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([existing.deletingLastPathComponent()])
                            }
                        }
                        .font(.caption)
                    } else {
                        Button("Générer l'aperçu du site") {
                            Task {
                                await generateAndOpenMaquette()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .onAppear(perform: prefillContactEdits)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private func enrichFromGoogle() async {
        isEnriching = true
        enrichError = nil
        defer { isEnriching = false }
        guard let url = URL(string: "http://127.0.0.1:31416/scrape/google-place") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 70
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "name": liveProspect.name ?? "",
            "city": liveProspect.city ?? ""
        ])
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                enrichError = "Réponse Google illisible."
                return
            }
            if json["error"] != nil {
                enrichError = "Google Maps injoignable pour l'instant, réessayez plus tard."
                return
            }
            var updated = liveProspect
            var found = false
            if let phone = json["phone"] as? String, !phone.isEmpty {
                updated.phone = phone
                found = true
            }
            if let site = json["website"] as? String, !site.isEmpty {
                updated.website = site
                updated.hasWebsite = true
                if updated.websiteStatus == .noSite { updated.websiteStatus = .secure }
                found = true
            }
            if let rating = json["rating"] as? Double { updated.googleRating = rating }
            if let rc = json["reviewsCount"] as? Int { updated.googleReviewCount = rc }
            if let hours = json["hours"] as? [String], !hours.isEmpty { updated.openingHours = hours }
            if let photos = json["photos"] as? [String], !photos.isEmpty { updated.photoURLs = Array(photos.prefix(6)) }
            if let rw = json["reviews"] as? [[String: Any]], !rw.isEmpty {
                updated.googleReviews = rw.compactMap { r in
                    guard let text = r["text"] as? String, !text.isEmpty else { return nil }
                    return GoogleReview(author: (r["author"] as? String) ?? "Client Google",
                                        rating: (r["rating"] as? Double) ?? (r["rating"] as? Int).map(Double.init),
                                        text: text, date: r["date"] as? String)
                }
                if updated.googleReviews?.isEmpty == true { updated.googleReviews = nil }
            }
            if let os = json["openState"] as? String, !os.isEmpty {
                var h = updated.openingHours ?? []
                let line = "Actuellement : " + os
                if !h.contains(line) { h.insert(line, at: 0); updated.openingHours = h }
            }
            if let addr = json["address"] as? String, !addr.isEmpty,
               (updated.address == nil || updated.address!.isEmpty) {
                updated.address = addr
            }
            // Ville : l'adresse Google contient le CP, sinon reverse Photon (léger)
            if updated.city == nil || updated.city == "Ville inconnue" {
                if let c = cityFromAddress(updated.address) { updated.city = c }
                else if let c = await fetchReverseCity(lat: updated.latitude, lon: updated.longitude) { updated.city = c }
            }
            updated.lastUpdated = Date()
            database.updateProspect(updated)
            prefillContactEdits()
            // Le site (trouvé ou déjà connu) est re-scrappé : on complète email ET tél manquants
            if let site = updated.website, !site.isEmpty,
               (updated.email ?? "").isEmpty || (updated.phone ?? "").isEmpty {
                let real = await aiService.fetchSiteContact(website: site)
                var withContact = database.prospects.first(where: { $0.id == updated.id }) ?? updated
                var changed = false
                if let email = real.email, !email.isEmpty, (withContact.email ?? "").isEmpty {
                    withContact.email = email
                    changed = true
                }
                if let p = real.phone, !p.isEmpty, (withContact.phone ?? "").isEmpty {
                    withContact.phone = p
                    changed = true
                }
                if changed {
                    database.updateProspect(withContact)
                    prefillContactEdits()
                    found = true
                }
            }
            if !found {
                enrichError = "Rien trouvé sur Google Maps pour ce commerce."
            }
        } catch {
            enrichError = "Échec : \(error.localizedDescription). Vérifiez que le scraper est lancé."
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func generateEmail() async {
        isGeneratingEmail = true
        emailError = nil
        defer { isGeneratingEmail = false }
        do {
            let content = try await aiService.generateEmailContent(for: liveProspect, sender: appState.userProfile)
            var updated = liveProspect
            updated.emailSubject = content.subject
            updated.emailBody = content.body
            updated.lastUpdated = Date()
            database.updateProspect(updated)
        } catch {
            emailError = "Échec : \(error.localizedDescription). Vérifiez que FreeLLMAPI est lancé."
            print("Error generating email: \(error)")
        }
    }

    private func generatePitch() async {
        isGeneratingPitch = true
        pitchError = nil
        defer { isGeneratingPitch = false }
        do {
            let pitch = try await aiService.generatePitchScript(for: liveProspect, senderName: appState.userProfile.name)
            var updated = liveProspect
            updated.pitchScript = pitch
            updated.lastUpdated = Date()
            database.updateProspect(updated)
        } catch {
            pitchError = "Échec : \(error.localizedDescription). Vérifiez que FreeLLMAPI est lancé."
            print("Error generating pitch: \(error)")
        }
    }

    private func prefillContactEdits() {
        let p = liveProspect
        editEmail = p.email ?? ""
        editPhone = p.phone ?? ""
        editWebsite = p.website ?? ""
        editCity = p.city ?? ""
    }

    private var contactEdited: Bool {
        let p = liveProspect
        return editEmail != (p.email ?? "")
            || editPhone != (p.phone ?? "")
            || editWebsite != (p.website ?? "")
            || editCity != (p.city ?? "")
    }

    private func coordRow(label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func officialRow(label: String, value: String?) -> some View {
        HStack {
            Text(label + " :")
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .leading)
            Text((value?.isEmpty == false) ? value! : "Non renseigné")
                .textSelection(.enabled)
        }.font(.caption)
    }

    private func saveContactEdits() {
        var updated = liveProspect
        let email = editEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = editPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        var site = editWebsite.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = editCity.trimmingCharacters(in: .whitespacesAndNewlines)
        if !site.isEmpty && !site.contains("://") { site = "https://" + site }
        updated.email = email.isEmpty ? nil : email
        updated.phone = phone.isEmpty ? nil : phone
        updated.website = site.isEmpty ? nil : site
        updated.hasWebsite = !site.isEmpty
        if updated.hasWebsite && updated.websiteStatus == .noSite {
            updated.websiteStatus = .secure
        }
        if !updated.hasWebsite {
            updated.websiteStatus = .noSite
            updated.websiteAudit = nil
        }
        updated.city = city.isEmpty ? nil : city
        updated.lastUpdated = Date()
        database.updateProspect(updated)
    }

    // Racine des sites persistants (Documents/ProspectorMac/Sites)
    private var sitesBaseDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ProspectorMac/Sites", isDirectory: true)
    }

    // Dossier persistant du site : chemin sauvegardé d'abord, sinon réadoption
    // d'un dossier orphelin (généré avant la persistance, ou plist réinitialisé).
    // Sans ce repli, rouvrir l'app proposait « Générer » et créait un doublon « (2) ».
    private var siteFileURL: URL? {
        if let p = liveProspect.maquettePath, !p.isEmpty {
            let u = URL(fileURLWithPath: p).appendingPathComponent("index.html")
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        if let adopted = adoptableSiteDir(for: liveProspect) {
            return adopted.appendingPathComponent("index.html")
        }
        return nil
    }

    // Dossier existant sur disque avec index.html, non réclamé par un autre
    // prospect : on le réadopte au lieu de créer un doublon « (2) ».
    private func adoptableSiteDir(at dir: URL, for prospect: Prospect) -> Bool {
        let idx = dir.appendingPathComponent("index.html").path
        guard FileManager.default.fileExists(atPath: idx) else { return false }
        let claimed = database.prospects.contains {
            $0.id != prospect.id && ($0.maquettePath == dir.path)
        }
        return !claimed
    }

    private func adoptableSiteDir(for prospect: Prospect) -> URL? {
        let dir = sitesBaseDir.appendingPathComponent(siteFolderName(for: prospect), isDirectory: true)
        return adoptableSiteDir(at: dir, for: prospect) ? dir : nil
    }

    // Enregistre le lien vers un dossier réadopté (no-op si déjà correct)
    private func persistAdoptedDir(_ dir: URL) {
        var updated = database.prospects.first(where: { $0.id == liveProspect.id }) ?? liveProspect
        if updated.maquettePath != dir.path {
            updated.maquettePath = dir.path
            if updated.maquetteJson == nil { updated.maquetteJson = "{\"fullHtml\":true}" }
            database.updateProspect(updated)
        }
    }

    private func freshSiteDir(for prospect: Prospect) -> URL {
        let base = sitesBaseDir
        let stem = siteFolderName(for: prospect)
        var candidate = base.appendingPathComponent(stem, isDirectory: true)
        var n = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let idx = candidate.appendingPathComponent("index.html").path
            // Dossier vide/abandonné ou orphelin réadoptable : on le réutilise, pas de « (2) »
            if !FileManager.default.fileExists(atPath: idx) { return candidate }
            if adoptableSiteDir(at: candidate, for: prospect) { return candidate }
            // Sinon il appartient à un autre commerce du même nom : on suffixe
            n += 1
            candidate = base.appendingPathComponent("\(stem) (\(n))", isDirectory: true)
        }
        return candidate
    }

    private func siteFolderName(for prospect: Prospect) -> String {
        let base = (prospect.name ?? "commerce").trimmingCharacters(in: .whitespacesAndNewlines)
        var s = base.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>")).joined(separator: "-")
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { s = "commerce" }
        if s.count > 60 { s = String(s.prefix(60)) }
        return s
    }

    private func generateAndOpenMaquette(force: Bool = false) async {
        isGeneratingMaquette = true
        maquetteError = nil
        defer { isGeneratingMaquette = false }

        do {
            // Site déjà généré et pas de régénération forcée : on rouvre, on ne régénère pas
            if !force, let existing = siteFileURL {
                persistAdoptedDir(existing.deletingLastPathComponent())
                openMaquetteWindow(fileURL: existing)
                return
            }
            // Dossier persistant : style.css + une page HTML par rubrique + photos
            // locales (la WebView lit tout le dossier, la nav est en liens relatifs)
            let dir: URL
            if let saved = liveProspect.maquettePath, !saved.isEmpty {
                dir = URL(fileURLWithPath: saved) // régénération au même endroit
            } else {
                dir = freshSiteDir(for: liveProspect)
            }
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            // 1) Photos Google téléchargées en local (garantit l'affichage)
            let googlePhotos = await downloadMaquettePhotos(Array((liveProspect.photoURLs ?? []).prefix(4)), dir: dir)
            // 1a) VRAIES photos du site du commerce (vitrine, plats, réalisations) :
            // le scraper va sur le site existant et en extrait les images — en premier,
            // car ce sont les plus représentatives. Best-effort : repli Google sinon.
            let sitePhotos = await downloadSiteImages(liveProspect.website, dir: dir, max: max(0, 6 - googlePhotos.count))
            let localPhotos = Array((sitePhotos + googlePhotos).prefix(6))
            // 1b) Carte du quartier (screenshot Maps réel) pour la page Contact
            let mapName = await downloadMapShot(lat: liveProspect.latitude, lon: liveProspect.longitude, dir: dir)
            // 1c) L'IA "regarde" la première photo (ambiance, plats, décor) — best-effort
            let photoNote: String? = await {
                guard let first = localPhotos.first else { return nil }
                return await aiService.describePhoto(atPath: dir.appendingPathComponent(first).path)
            }()
            // 2) UN thème dealé pour ce commerce (jamais deux sites pareils) + CSS local
            // (toujours valide, tokens des skills Hallmark + Impeccable)
            let ds = dealTheme(name: liveProspect.name ?? "commerce", category: liveProspect.category)
            let p = liveProspect
            let data = SiteInput(
                name: p.name ?? "Entreprise", category: p.category ?? "commerce",
                city: p.city ?? "", address: p.address, phone: p.phone, email: p.email,
                website: p.website, siret: p.siret, director: p.directorName,
                latitude: p.latitude, longitude: p.longitude,
                rating: p.googleRating, reviewCount: p.googleReviewCount,
                reviews: (p.googleReviews ?? []).map {
                    SiteReview(author: $0.author, rating: $0.rating, text: $0.text, date: $0.date)
                },
                hours: p.openingHours ?? [], photoNames: localPhotos, mapName: mapName
            )
            let pages = sitePages(photoCount: localPhotos.count)
            try SiteBuilder.css(ds).write(to: dir.appendingPathComponent("style.css"), atomically: true, encoding: .utf8)
            // Fiche récapitulative : toutes les données collectées, lisible par un humain
            try? SiteBuilder.infosMarkdown(data: data, pages: pages, ds: ds).write(to: dir.appendingPathComponent("INFOS.md"), atomically: true, encoding: .utf8)
            let fallbackServices = SiteBuilder.defaultServices(category: data.category)
            // 3) L'IA écrit les TEXTES (accueil + prestations) ; le reste est local
            for page in pages {
                let body: String
                switch page {
                case .index:
                    if let ai = try? await aiService.generateSiteContent(page: .index, data: data, ds: ds, photoNote: photoNote),
                       let assembled = SiteBuilder.assembleIndex(ai: ai, data: data, ds: ds) {
                        body = assembled
                    } else {
                        body = SiteBuilder.fallbackIndex(data: data, services: fallbackServices, ds: ds)
                    }
                case .prestations:
                    if let ai = try? await aiService.generateSiteContent(page: .prestations, data: data, ds: ds, photoNote: photoNote),
                       let assembled = SiteBuilder.assemblePrestations(ai: ai, data: data, ds: ds) {
                        body = assembled
                    } else {
                        body = SiteBuilder.fallbackPrestations(data: data, services: fallbackServices, ds: ds)
                    }
                case .galerie:
                    body = SiteBuilder.galerieBody(data: data)
                case .contact:
                    body = SiteBuilder.contactBody(data: data)
                }
                let title = page == .index ? "Accueil" : page.navLabel
                let html = SiteBuilder.wrap(title: title, current: page, pages: pages, data: data, body: body)
                try html.write(to: dir.appendingPathComponent(page.file), atomically: true, encoding: .utf8)
            }
            let fileURL = dir.appendingPathComponent(SitePage.index.file)
            var updated = database.prospects.first(where: { $0.id == liveProspect.id }) ?? liveProspect
            updated.maquettePath = dir.path
            updated.maquetteJson = "{\"site\":\"multipage\",\"pages\":\(pages.count)}"
            database.updateProspect(updated)
            openMaquetteWindow(fileURL: fileURL)
        } catch {
            maquetteError = "Échec : \(error.localizedDescription). Vérifiez que FreeLLMAPI est lancé."
            print("Error generating maquette: \(error)")
        }
    }

    // Capture carte du quartier via le scraper (screenshot Maps réel, best-effort)
    private func downloadMapShot(lat: Double, lon: Double, dir: URL) async -> String? {
        guard lat != 0 || lon != 0,
              let url = URL(string: "http://127.0.0.1:31416/scrape/mapshot") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["lat": lat, "lon": lon])
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let path = json["path"] as? String, !path.isEmpty,
              let img = try? Data(contentsOf: URL(fileURLWithPath: path)), img.count > 60000 else { return nil }
        try? img.write(to: dir.appendingPathComponent("carte.jpg"))
        try? FileManager.default.removeItem(atPath: path)
        return "carte.jpg"
    }

    // Fenêtres d'aperçu : une vraie NSWindow par site (jamais de .sheet imbriqué
    // dans la fiche — des sheets empilés = freeze SwiftUI déjà constaté sur ce
    // projet). La WKWebView vit hors hiérarchie SwiftUI : aucun re-render ne
    // peut recharger la page en boucle.
    private static var previewWindows: [NSWindow] = []

    private func openMaquetteWindow(fileURL: URL) {
        // Capture hors main-actor (nom seul, pas d'état partagé), création AppKit sur main
        let title = "Aperçu du site — \(liveProspect.name ?? "commerce")"
        DispatchQueue.main.async {
            Self.previewWindows = Self.previewWindows.filter { $0.isVisible }
            let wv = WKWebView()
            wv.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
            let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
                               styleMask: [.titled, .closable, .resizable, .miniaturizable],
                               backing: .buffered, defer: false)
            win.title = title
            win.contentView = wv
            win.isReleasedWhenClosed = false
            win.center()
            win.makeKeyAndOrderFront(nil)
            Self.previewWindows.append(win)
        }
    }

    // Télécharge les photos Google en local (même dossier que index.html)
    // Photos du site web du commerce via le scraper (og:image + <img> réelles,
    // logos et avatars exclus côté serveur). Noms site-1.jpg… — best-effort.
    private func downloadSiteImages(_ website: String?, dir: URL, max: Int) async -> [String] {
        let site = (website ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard max > 0, !site.isEmpty, let url = URL(string: "http://127.0.0.1:31416/scrape/site-images") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["url": site, "limit": max])
        guard let (payload, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let images = json["images"] as? [[String: Any]], !images.isEmpty else { return [] }
        var names: [String] = []
        for img in images.prefix(max) {
            guard let src = img["url"] as? String, let srcURL = URL(string: src) else { continue }
            do {
                var req = URLRequest(url: srcURL)
                req.timeoutInterval = 25
                req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                      data.count > 8000 else { continue }
                let fname = "site-\(names.count + 1).jpg"
                try data.write(to: dir.appendingPathComponent(fname))
                names.append(fname)
            } catch { continue }
        }
        return names
    }

    private func downloadMaquettePhotos(_ urls: [String], dir: URL) async -> [String] {
        // Ceinture + bretelles : le serveur filtre déjà les avatars (=s32/=s64),
        // on refuse ici tout résidu (avatar, initiale, petit fichier).
        var names: [String] = []
        for (i, u) in urls.enumerated() {
            let l = u.lowercased()
            if l.contains("avatar") || l.contains("=s24") || l.contains("=s32") || l.contains("=s64") || l.contains("=w32") || l.contains("=w64") { continue }
            guard let url = URL(string: u) else { continue }
            do {
                let (data, resp) = try await URLSession.shared.data(from: url)
                guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                      data.count > 5000 else { continue }
                let fname = "photo-\(i + 1).jpg"
                try data.write(to: dir.appendingPathComponent(fname))
                names.append(fname)
            } catch { continue }
        }
        return names
    }
}

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var aiService: AIService
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = "__CLE_SUPPRIMEE__"
    @State private var selectedModel = "auto"
    @State private var profileName = ""
    @State private var profilePhone = ""
    @State private var profileEmail = ""
    @State private var testingConnection = false
    @State private var connectionResult: String?

    var body: some View {
        // Pas de NavigationView ici : dans un .sheet macOS ça provoque des freezes/boucles de layout.
        VStack(spacing: 0) {
            HStack {
                Text("Réglages")
                    .font(.headline)
                Spacer()
                Button("Fermer") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
            Divider()
            Form {
                Section(header: Text("FreeLLMAPI Configuration")) {
                    TextField("Clé API", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)

                    if !aiService.availableModels.isEmpty {
                        Picker("Modèle", selection: $selectedModel) {
                            Text("auto").tag("auto")
                            ForEach(aiService.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Button(action: testConnection) {
                        HStack {
                            if testingConnection {
                                ProgressView()
                            }
                            Text(testingConnection ? "Test en cours..." : "Tester la connexion")
                        }
                    }
                    .disabled(testingConnection)

                    if let result = connectionResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("OK") || result.contains("Connecté") ? .green : .red)
                    }
                }

                Section(header: Text("Mon profil (signature des emails)")) {
                    TextField("Nom", text: $profileName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Téléphone", text: $profilePhone)
                        .textFieldStyle(.roundedBorder)
                    TextField("Email", text: $profileEmail)
                        .textFieldStyle(.roundedBorder)
                    Button("Enregistrer le profil") {
                        appState.saveProfile(name: profileName, phone: profilePhone, email: profileEmail)
                    }
                }

                Section(header: Text("Paramètres")) {
                    Stepper("Rayon: \(Int(appState.radius)) km", value: $appState.radius, in: 1...30)
                }

                Section(header: Text("Statut de la connexion")) {
                    HStack {
                        Text("FreeLLMAPI")
                        Spacer()
                        Text("http://127.0.0.1:31415/v1")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("Sauvegarder et tester") {
                        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        apiKey = key
                        appState.apiKey = key
                        aiService.setApiKey(key)
                        Task {
                            let connected = await aiService.checkConnection()
                            if connected {
                                appState.connectionStatus = .connected
                            } else {
                                appState.connectionStatus = .disconnected
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: 500, minHeight: 400)
        .onAppear {
            apiKey = appState.apiKey
            profileName = appState.userProfile.name
            profilePhone = appState.userProfile.phone
            profileEmail = appState.userProfile.email
        }
    }

    private func testConnection() {
        testingConnection = true
        connectionResult = nil
        // La clé du champ doit alimenter l'IA AVANT le test : sinon test avec clé vide = 401
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKey = key

        Task {
            await MainActor.run { aiService.setApiKey(key) }
            let connected = await aiService.checkConnection()
            await MainActor.run {
                testingConnection = false
                if connected {
                    connectionResult = "✓ Connecté à FreeLLMAPI"
                    appState.apiKey = apiKey
                    aiService.setApiKey(apiKey)
                } else {
                    connectionResult = "✗ Impossible de se connecter. Vérifiez la clé API."
                }
            }
        }
    }
}

// MARK: - ProspectMapView
struct ProspectMapView: View {
    @EnvironmentObject var database: DatabaseManager
    @EnvironmentObject var locationManager: LocationManager

    @State private var showMarkers = true
    @State private var mapFilter: ProspectStatus = .all
    @State private var recenterTrigger = UUID()

    private var filteredProspects: [Prospect] {
        switch mapFilter {
        case .all:
            return database.prospects
        case .noSite:
            return database.prospects.filter { !$0.hasWebsite }
        case .siteOutdated:
            return database.prospects.filter { $0.websiteStatus == .outdated }
        case .readyToContact:
            return database.prospects.filter { $0.isReady }
        case .contacted:
            return database.prospects.filter { $0.status == .contacted }
        }
    }

    private var mapCenter: CLLocationCoordinate2D {
        if let loc = locationManager.currentLocation {
            return loc
        }
        if let first = filteredProspects.first(where: { $0.latitude != 0 && $0.longitude != 0 }) {
            return CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
        }
        // Fallback Paris
        return CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
    }

    private var filterLabel: String {
        switch mapFilter {
        case .all: return "Tous"
        case .noSite: return "Sans site"
        case .siteOutdated: return "Obsolètes"
        case .readyToContact: return "À contacter"
        case .contacted: return "Contactés"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Carte des Prospects")
                    .font(.headline)

                Text("(\(filteredProspects.count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { recenterTrigger = UUID() }) {
                    Label("Recentrer", systemImage: "location.fill")
                }
                .help("Recentrer sur ma position (ou Paris par défaut)")

                Toggle("Markers", isOn: $showMarkers)
                    .toggleStyle(.switch)

                Menu {
                    Button("Tous les prospects") { mapFilter = .all }
                    Button("Sans site web") { mapFilter = .noSite }
                    Button("Site obsolète") { mapFilter = .siteOutdated }
                    Button("Prêts à contacter") { mapFilter = .readyToContact }
                    Button("Contactés") { mapFilter = .contacted }
                } label: {
                    Label(filterLabel, systemImage: "line.3.horizontal.decrease.circle")
                }
                .menuStyle(.borderlessButton)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Map Container
            if filteredProspects.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text(database.prospects.isEmpty
                         ? "Lancez un scan dans l'onglet Scanner pour voir les commerces ici."
                         : "Aucun prospect ne correspond à ce filtre.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MapContainerView(
                    prospects: showMarkers ? filteredProspects : [],
                    center: mapCenter,
                    recenterID: recenterTrigger
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - MapContainerView (using MapKit)
struct MapContainerView: NSViewRepresentable {
    var prospects: [Prospect]
    var center: CLLocationCoordinate2D
    var recenterID: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .standard
        mapView.showsUserLocation = true
        mapView.showsTraffic = false
        mapView.autoresizingMask = [.width, .height]
        mapView.delegate = context.coordinator

        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
        mapView.setRegion(region, animated: false)
        context.coordinator.lastCenter = center
        context.coordinator.didSetInitialRegion = true

        return mapView
    }

    func updateNSView(_ nsView: MKMapView, context: Context) {
        // Recenter if user asked (recenterID changed) or center moved far
        if context.coordinator.lastRecenterID != recenterID {
            context.coordinator.lastRecenterID = recenterID
            context.coordinator.lastCenter = center
            nsView.setRegion(MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            ), animated: true)
        } else if let last = context.coordinator.lastCenter {
            let dLat = abs(last.latitude - center.latitude)
            let dLng = abs(last.longitude - center.longitude)
            if dLat > 0.02 || dLng > 0.02 {
                context.coordinator.lastCenter = center
                nsView.setRegion(MKCoordinateRegion(
                    center: center,
                    span: nsView.region.span
                ), animated: true)
            }
        }

        // Update annotations only when IDs change to avoid flicker
        let existing = Set(nsView.annotations.compactMap { ($0 as? MapPointAnnotation)?.prospectID.uuidString })
        let wanted = Set(prospects.map { $0.id.uuidString })
        if existing != wanted {
            nsView.removeAnnotations(nsView.annotations.filter { $0 is MapPointAnnotation })
            for prospect in prospects {
                guard prospect.latitude != 0.0 || prospect.longitude != 0.0 else { continue }
                let coordinate = CLLocationCoordinate2D(latitude: prospect.latitude, longitude: prospect.longitude)
                let annotation = MapPointAnnotation(
                    prospectID: prospect.id,
                    coordinate: coordinate,
                    title: prospect.name,
                    subtitle: prospect.category
                )
                nsView.addAnnotation(annotation)
            }
            // Fit all pins if we have several and user just scanned
            if prospects.count > 1 {
                nsView.showAnnotations(nsView.annotations.filter { $0 is MapPointAnnotation }, animated: true)
            }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var lastCenter: CLLocationCoordinate2D?
        var lastRecenterID: UUID?
        var didSetInitialRegion = false

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            guard let point = annotation as? MapPointAnnotation else { return nil }
            let identifier = "prospectPin"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            if view == nil {
                view = MKMarkerAnnotationView(annotation: point, reuseIdentifier: identifier)
                view?.canShowCallout = true
            } else {
                view?.annotation = point
            }
            return view
        }
    }
}

// MARK: - MapPointAnnotation
class MapPointAnnotation: NSObject, MKAnnotation {
    let prospectID: UUID
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?

    init(prospectID: UUID = UUID(), coordinate: CLLocationCoordinate2D, title: String? = nil, subtitle: String? = nil) {
        self.prospectID = prospectID
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
}