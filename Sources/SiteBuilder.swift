import Foundation

// Générateur de VRAI site multi-pages (Accueil, Prestations, Galerie, Contact).
// Architecture imposée par le skill UI UX Pro Max :
//  - le DESIGN (CSS + structure + navigation + contact) est 100 % local :
//    beau par construction, tokens vérifiés du skill, zéro dépendance réseau ;
//  - l'IA ne fournit que les TEXTES (titres, accroches, prestations), jamais
//    de téléphone, jamais de lien, jamais d'image : l'hallucination est
//    impossible par construction.
//

// Avis client réel (verbatim Google, jamais inventé).
struct SiteReview: Codable {
    var author: String
    var rating: Double?
    var text: String
    var date: String?
}

// Données d'entrée (montées depuis Prospect, ou à la main pour les tests).
struct SiteInput {
    var name: String
    var category: String
    var city: String
    var address: String?
    var phone: String?
    var email: String?
    var website: String?
    var siret: String?
    var director: String?
    var latitude: Double
    var longitude: Double
    var rating: Double?
    var reviewCount: Int?
    var reviews: [SiteReview]
    var hours: [String]
    var photoNames: [String]
    var mapName: String?

    var phoneDigits: String { (phone ?? "").filter { $0.isNumber } }
    var prettyPhone: String { SiteBuilder.prettyFrPhone(phoneDigits) }
    var mapsURL: String {
        let q = [address, city].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "https://www.google.com/maps/search/?api=1&query=\(enc)"
    }
}

enum SitePage: CaseIterable {
    case index, prestations, galerie, contact
    var file: String {
        switch self {
        case .index: return "index.html"
        case .prestations: return "prestations.html"
        case .galerie: return "galerie.html"
        case .contact: return "contact.html"
        }
    }
    var navLabel: String {
        switch self {
        case .index: return "Accueil"
        case .prestations: return "Prestations"
        case .galerie: return "Galerie"
        case .contact: return "Contact"
        }
    }
    /// Pages avec contenu IA (les autres sont 100 % locales, données réelles)
    var needsAI: Bool { self == .index || self == .prestations }
}

func sitePages(photoCount: Int) -> [SitePage] {
    photoCount > 0 ? SitePage.allCases : [.index, .prestations, .contact]
}

enum SiteBuilder {
    // MARK: - Téléphone

    static func prettyFrPhone(_ digits: String) -> String {
        guard digits.count == 10, digits.hasPrefix("0") else { return digits }
        var out = ""
        for (i, c) in digits.enumerated() {
            if i > 0 && i % 2 == 0 { out.append(" ") }
            out.append(c)
        }
        return out
    }

    // MARK: - CSS (tokens vérifiés du skill, 100 % local, responsive + a11y)

    static func css(_ ds: DesignSystem) -> String {
        """
        /* ProspectorMac · theme: \(ds.slug) (\(ds.styleName)) · hero: \(ds.hero.rawValue) · cards: \(ds.cards.rawValue) · Skills: Hallmark + Impeccable */
        :root{
        --primary:\(ds.primary);--cta:\(ds.cta);--on-cta:\(ds.onCTA);
        --accent:\(ds.accent);--dark:\(ds.dark);
        --bg:\(ds.background);--card:\(ds.card);--muted:\(ds.muted);
        --border:\(ds.border);--fg:\(ds.fg);--muted-fg:\(ds.mutedFg);
        --display:\(ds.displayStack);--body:\(ds.bodyStack);
        --radius:\(ds.radius)px;--maxw:1100px;--nav-h:68px;
        }
        *{box-sizing:border-box}
        html{scroll-behavior:smooth;overflow-x:clip}
        body{overflow-x:clip}
        ::selection{background:var(--primary);color:var(--on-primary)}
        body{margin:0;font-family:var(--body);background:var(--bg);color:var(--fg);
        font-size:16px;line-height:1.6;-webkit-font-smoothing:antialiased}
        section{scroll-margin-top:calc(var(--nav-h) + 12px)}
        h1,h2,h3{font-family:var(--display);line-height:1.08;margin:0 0 .5em;color:var(--dark);
        letter-spacing:-.015em;text-wrap:balance}
        p{margin:0 0 1em}
        a{color:var(--primary)}
        :focus-visible{outline:3px solid var(--primary);outline-offset:2px;border-radius:4px}
        .container{max-width:var(--maxw);margin:0 auto;padding:0 24px}
        /* Barre utilitaire */
        .topbar{background:var(--dark);color:#fff;font-size:13px}
        .topbar-in{display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap;
        padding-top:8px;padding-bottom:8px}
        .topbar .stars{color:#FBBF24;letter-spacing:1px}
        /* En-tête + navigation */
        .site-header{position:sticky;top:0;z-index:50;background:color-mix(in srgb,var(--bg) 92%,white);
        backdrop-filter:blur(8px);border-bottom:1px solid var(--border)}
        .header-in{display:flex;align-items:center;gap:20px;min-height:var(--nav-h)}
        .brand{text-decoration:none;color:var(--dark);display:flex;flex-direction:column;line-height:1.2}
        .brand-name{font-family:var(--display);font-weight:700;font-size:22px}
        .brand-city{font-size:12px;color:var(--muted-fg);font-family:var(--body)}
        .nav{display:flex;gap:4px;margin-left:auto;flex-wrap:wrap}
        .nav a{text-decoration:none;color:var(--fg);font-weight:600;font-size:15px;
        padding:10px 14px;min-height:44px;display:inline-flex;align-items:center;border-radius:10px}
        .nav a:hover{background:var(--muted)}
        .nav a.active{color:var(--primary);box-shadow:inset 0 -3px 0 var(--primary);border-radius:0}
        .btn{display:inline-flex;align-items:center;gap:8px;text-decoration:none;font-weight:700;
        font-size:15px;padding:12px 22px;min-height:48px;border-radius:12px;cursor:pointer;
        transition:transform .2s,box-shadow .2s,background .2s}
        .btn-call{background:var(--cta);color:var(--on-cta);box-shadow:0 2px 8px rgba(0,0,0,.12)}
        .btn-call:hover{transform:translateY(-2px);box-shadow:0 6px 16px rgba(0,0,0,.16)}
        .btn-ghost{background:transparent;color:var(--fg);border:2px solid var(--border)}
        .btn-ghost:hover{border-color:var(--primary);color:var(--primary)}
        .btn svg{width:18px;height:18px;flex:none}
        /* Hero */
        .hero{padding:64px 0 56px;background:
        radial-gradient(circle at 85% 15%,var(--muted) 0,transparent 45%),
        linear-gradient(var(--bg),var(--bg))}
        .hero-grid{display:grid;grid-template-columns:1.05fr .95fr;gap:48px;align-items:center}
        .hero h1{font-size:clamp(2.1rem,4.6vw,3.4rem);margin:0 0 16px}
        .lead{font-size:19px;color:var(--muted-fg);margin:0 0 28px;max-width:34em;text-wrap:pretty}
        .cta-row{display:flex;gap:12px;flex-wrap:wrap;margin:0 0 26px}
        .trust{display:flex;gap:18px;flex-wrap:wrap;font-size:14.5px;color:var(--muted-fg);align-items:center}
        .trust .stars{color:#E8930C;font-size:16px;letter-spacing:2px}
        .trust strong{color:var(--fg)}
        .hero-media{margin:0;position:relative}
        .hero-media img{width:100%;height:420px;object-fit:cover;border-radius:18px;
        box-shadow:0 18px 44px rgba(0,0,0,.16);display:block}
        .hero-badge{position:absolute;left:18px;bottom:18px;background:rgba(255,255,255,.94);
        border:1px solid var(--border);border-radius:12px;padding:10px 16px;font-size:14px;
        box-shadow:0 4px 14px rgba(0,0,0,.12)}
        .hero-bg{background-size:cover;background-position:center;padding:72px 0}
        .hero-card{background:rgba(255,255,255,.96);border-radius:18px;padding:44px;max-width:640px;box-shadow:0 18px 44px rgba(0,0,0,.22)}
        .hero-card .lead{color:#3F3A34}
        .hero-center{text-align:center;max-width:780px;margin:0 auto}
        .hero-center .cta-row,.hero-center .trust{justify-content:center}
        .hero-wide{margin:40px 0 0}
        .hero-wide img{width:100%;height:clamp(280px,44vw,480px);object-fit:cover;
        border-radius:calc(var(--radius) + 6px);box-shadow:0 18px 44px rgba(0,0,0,.16);display:block}
        .hero-wide figcaption{padding:10px 4px;font-size:14px;color:var(--muted-fg)}
        .hero-editorial .proofline{display:flex;gap:8px 20px;flex-wrap:wrap;align-items:center;
        font-size:15.5px;color:var(--muted-fg);margin:0 0 26px}
        .hero-editorial .proofline .stars{color:#E8930C;letter-spacing:2px}
        .hero-editorial h1{font-size:clamp(2.6rem,7vw,5rem);max-width:12em}
        .photo-duo{display:grid;grid-template-columns:1.1fr .9fr;gap:16px;margin:36px 0 0;align-items:start}
        .photo-duo img{width:100%;object-fit:cover;border-radius:calc(var(--radius) + 4px);
        display:block;box-shadow:0 14px 34px rgba(0,0,0,.14)}
        .photo-duo img:first-child{height:380px}
        .photo-duo img:last-child{height:300px;margin-top:48px}
        .photo-strip{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin:36px 0 0}
        .photo-strip img{width:100%;height:220px;object-fit:cover;border-radius:var(--radius);display:block}
        .rows{border-top:2px solid var(--dark);margin-top:8px}
        .row-item{display:grid;gap:6px;padding:22px 4px;border-bottom:1px solid var(--border)}
        .row-item h3{margin:0;font-size:20px}
        .row-item p{margin:0;color:var(--muted-fg);font-size:15.5px;max-width:60em}
        .hero-grid.flip{direction:rtl}
        .hero-grid.flip>*{direction:ltr}
        .map-wrap{margin:4px 0 8px}
        .map-wrap h3{font-size:19px}
        .map{margin:0}
        .map img{width:100%;height:auto;max-height:380px;object-fit:cover;border-radius:var(--radius);border:1px solid var(--border);display:block}
        .map figcaption{padding:10px 4px;font-size:14px;color:var(--muted-fg)}
        /* Sections */
        .section{padding:72px 0}
        .section.alt{background:var(--muted)}
        .section h2{font-size:clamp(1.6rem,3vw,2.2rem)}
        .section-sub{color:var(--muted-fg);font-size:17px;margin:0 0 36px;max-width:44em}
        .grid-cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:20px}
        .card{background:var(--card);border:1px solid var(--border);border-radius:var(--radius);
        padding:28px;transition:transform .2s,box-shadow .2s}
        .card:hover{transform:translateY(-4px);box-shadow:0 12px 28px rgba(0,0,0,.10)}
        .card h3{font-size:19px;font-family:var(--body);font-weight:700}
        .card p{margin:0;color:var(--muted-fg);font-size:15px}
        .steps{list-style:none;margin:8px 0 0;padding:0;display:grid;gap:0;
        grid-template-columns:repeat(auto-fit,minmax(220px,1fr))}
        .steps li{padding:20px 22px;border-left:3px solid var(--primary);background:var(--card);
        border-radius:0 12px 12px 0;margin-bottom:12px}
        .steps li strong{display:block;margin-bottom:4px}
        .steps li span{color:var(--muted-fg);font-size:14.5px}
        /* Galerie */
        .gallery-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:16px}
        .gallery-grid figure{margin:0;overflow:hidden;border-radius:var(--radius);
        border:1px solid var(--border);background:var(--card)}
        .gallery-grid img{width:100%;height:230px;object-fit:cover;display:block;
        transition:transform .25s}
        .gallery-grid figure:hover img{transform:scale(1.04)}
        .gallery-grid figcaption{padding:10px 14px;font-size:13.5px;color:var(--muted-fg)}
        .review-head{display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin:0 0 10px}
        .review-head .stars{color:#E8930C;letter-spacing:1px}
        .review-head strong{font-size:15px}
        .review-date{color:var(--muted-fg);font-size:13px}
        .card.review p{margin:0;font-size:15px}
        .discreet{color:var(--muted-fg);font-size:13px}
        /* Contact */
        .contact-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:20px;
        margin-bottom:8px}
        .contact-card{background:var(--card);border:1px solid var(--border);border-radius:var(--radius);
        padding:26px}
        .contact-card h3{font-size:16px;font-family:var(--body);margin:0 0 10px;display:flex;
        align-items:center;gap:10px}
        .contact-card h3 svg{width:20px;height:20px;color:var(--primary);flex:none}
        .contact-card p{margin:0;font-size:16px}
        .contact-card a{font-weight:700;text-decoration:none}
        .contact-card a:hover{text-decoration:underline}
        .hours{list-style:none;margin:0;padding:0}
        .hours li{display:flex;justify-content:space-between;gap:12px;padding:9px 0;
        border-bottom:1px dashed var(--border);font-size:15px}
        .hours li:last-child{border-bottom:none}
        .cta-band{background:var(--dark);color:#fff;border-radius:20px;padding:48px 40px;
        text-align:center;margin-top:56px}
        .cta-band h2{color:#fff}
        .cta-band p{opacity:.85;margin:0 0 26px}
        /* Pied de page */
        footer{background:var(--dark);color:#D6D3D1;padding:36px 0;margin-top:0;font-size:14px}
        .foot-grid{display:flex;justify-content:space-between;gap:24px;flex-wrap:wrap;align-items:start}
        .foot-nav{display:flex;gap:6px 20px;flex-wrap:wrap}
        footer a{color:#fff}
        footer .discreet{opacity:.6;font-size:12.5px;margin:14px 0 0}
        @media (max-width:560px){
        .top-addr{display:none}
        .topbar-in{justify-content:center;font-size:12px}
        }
        @media (max-width:820px){
        .hero-grid{grid-template-columns:1fr;gap:28px}
        .photo-duo{grid-template-columns:1fr}
        .photo-duo img:first-child{height:260px}
        .photo-duo img:last-child{height:240px;margin-top:0}
        .photo-strip{grid-template-columns:1fr 1fr}
        .photo-strip img{height:160px}
        .hero{padding:44px 0 40px}
        .hero-media img{height:260px}
        .section{padding:52px 0}
        .nav{margin-left:0}
        .header-in{flex-wrap:wrap;padding-top:12px;padding-bottom:12px}
        .btn-call{width:100%;justify-content:center}
        }
        @media (prefers-reduced-motion:reduce){
        html{scroll-behavior:auto}
        *,*::before,*::after{transition:none !important;animation:none !important}
        }
        """
    }

    // MARK: - Pictos SVG (le skill interdit les emojis comme icônes)

    static let icoPhone = "<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 1.85.57 2.81.7A2 2 0 0 1 22 16.92z\"/></svg>"
    static let icoPin = "<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z\"/><circle cx=\"12\" cy=\"10\" r=\"3\"/></svg>"
    static let icoMail = "<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><rect x=\"2\" y=\"4\" width=\"20\" height=\"16\" rx=\"2\"/><path d=\"m22 7-10 6L2 7\"/></svg>"
    static let icoClock = "<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><circle cx=\"12\" cy=\"12\" r=\"10\"/><path d=\"M12 6v6l4 2\"/></svg>"
    static let icoGlobe = "<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><circle cx=\"12\" cy=\"12\" r=\"10\"/><path d=\"M2 12h20\"/><path d=\"M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z\"/></svg>"

    // MARK: - Chrome (en-tête, navigation, pied de page — données réelles uniquement)

    static func header(current: SitePage, pages: [SitePage], data: SiteInput) -> String {
        let nav = pages.map { p in
            let cls = p == current ? " class=\"active\"" : ""
            return "<a href=\"\(p.file)\"\(cls)>\(p.navLabel)</a>"
        }.joined()
        let call: String
        if !data.phoneDigits.isEmpty {
            call = "<a class=\"btn btn-call\" href=\"tel:\(data.phoneDigits)\">\(icoPhone)\(data.prettyPhone)</a>"
        } else {
            call = "<a class=\"btn btn-call\" href=\"contact.html\">Demander un devis</a>"
        }
        let addr = data.address.map { "<span class=\"top-addr\">\($0)</span>" } ?? ""
        let rating: String
        if let r = data.rating, r > 0 {
            let stars = String(repeating: "★", count: Int(r.rounded())) + String(repeating: "☆", count: max(0, 5 - Int(r.rounded())))
            rating = "<span><span class=\"stars\">\(stars)</span> <strong>\(String(format: "%.1f", r))</strong> (\(data.reviewCount ?? 0) avis Google)</span>"
        } else { rating = "" }
        return """
        <div class="topbar"><div class="container topbar-in">\(addr)\(rating)</div></div>
        <header class="site-header"><div class="container header-in">
        <a class="brand" href="index.html"><span class="brand-name">\(esc(data.name))</span><span class="brand-city">\(esc(businessLine(data: data)))</span></a>
        <nav class="nav">\(nav)</nav>
        \(call)
        </div></header>
        """
    }

    static func footer(pages: [SitePage], data: SiteInput) -> String {
        let nav = pages.map { "<a href=\"\($0.file)\">\($0.navLabel)</a>" }.joined()
        var line = esc(data.name)
        if let a = data.address, !a.isEmpty { line += " — " + esc(a) }
        if !data.phoneDigits.isEmpty { line += " — <a href=\"tel:\(data.phoneDigits)\">\(data.prettyPhone)</a>" }
        return """
        <footer><div class="container">
        <div class="foot-grid"><div>\(line)</div><nav class="foot-nav">\(nav)</nav></div>
        <p class="discreet">Informations issues de Google — site vitrine de démonstration.</p>
        </div></footer>
        """
    }

    static func wrap(title: String, current: SitePage, pages: [SitePage], data: SiteInput, body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="fr">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(esc(title)) — \(esc(data.name))</title>
        <meta name="description" content="\(esc(businessLine(data: data))) : prestations, photos, horaires et contact.">
        <link rel="stylesheet" href="style.css">
        </head>
        <body>
        \(header(current: current, pages: pages, data: data))
        <main>
        \(body)
        </main>
        \(footer(pages: pages, data: data))
        </body>
        </html>
        """
    }

    // MARK: - Corps de page 100 % locaux (Galerie, Contact : que du réel)

    static func galerieBody(data: SiteInput) -> String {
        let figs = data.photoNames.enumerated().map { i, n in
            "<figure><img src=\"\(n)\" alt=\"\(esc(data.name)) — photo \(i + 1)\" loading=\"lazy\"><figcaption>En vrai, chez nous.</figcaption></figure>"
        }.joined(separator: "\n")
        return """
        <section class="hero"><div class="container">
        <h1>Le commerce en vrai</h1>
        <p class="lead">Des photos récentes de \(esc(data.name)) — vitrine, savoir-faire, équipe.</p>
        </div></section>
        <section class="section"><div class="container">
        <div class="gallery-grid">
        \(figs)
        </div>
        </div></section>
        """
    }

    static func contactBody(data: SiteInput) -> String {
        var cards: [String] = []
        if let a = data.address, !a.isEmpty {
            cards.append("<div class=\"contact-card\"><h3>\(icoPin)Adresse</h3><p>\(esc(a))<br><a href=\"\(data.mapsURL)\">Itinéraire</a></p></div>")
        }
        if !data.phoneDigits.isEmpty {
            cards.append("<div class=\"contact-card\"><h3>\(icoPhone)Téléphone</h3><p><a href=\"tel:\(data.phoneDigits)\">\(data.prettyPhone)</a><br>Appelez-nous, on vous répond.</p></div>")
        }
        if let e = data.email, !e.isEmpty {
            cards.append("<div class=\"contact-card\"><h3>\(icoMail)Email</h3><p><a href=\"mailto:\(esc(e))\">\(esc(e))</a></p></div>")
        }
        if let w = data.website, !w.isEmpty {
            cards.append("<div class=\"contact-card\"><h3>\(icoGlobe)Site web</h3><p><a href=\"\(esc(w))\">\(esc(w))</a></p></div>")
        }
        let hours: String
        if data.hours.isEmpty {
            hours = "<li><span>Horaires</span><span>Sur demande — appelez-nous</span></li>"
        } else {
            hours = data.hours.map { h in
                let parts = h.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 { return "<li><span>\(esc(parts[0]))</span><span>\(esc(parts[1]))</span></li>" }
                return "<li><span>\(esc(h))</span><span></span></li>"
            }.joined()
        }
        cards.append("<div class=\"contact-card\"><h3>\(icoClock)Horaires</h3><ul class=\"hours\">\(hours)</ul></div>")
        let callBand: String
        if !data.phoneDigits.isEmpty {
            callBand = "<div class=\"cta-band\"><h2>Un projet, une question ?</h2><p>Un seul appel suffit — on vous répond de vive voix.</p><a class=\"btn btn-call\" href=\"tel:\(data.phoneDigits)\">\(icoPhone)\(data.prettyPhone)</a></div>"
        } else {
            callBand = "<div class=\"cta-band\"><h2>Passez nous voir</h2><p>\(esc(data.address ?? data.city))</p><a class=\"btn btn-call\" href=\"\(data.mapsURL)\">\(icoPin)Itinéraire</a></div>"
        }
        return """
        <section class="hero"><div class="container">
        <h1>Venez, appelez, écrivez</h1>
        <p class="lead">De vraies coordonnées, un vrai interlocuteur — pas un formulaire perdu.</p>
        </div></section>
        <section class="section"><div class="container">
        <div class="contact-grid">
        \(cards.joined(separator: "\n"))
        </div>
        \(mapBlock(data: data))
        \(legalLine(data: data))
        \(callBand)
        </div></section>
        """
    }

    static func mapBlock(data: SiteInput) -> String {
        guard let m = data.mapName, !m.isEmpty else { return "" }
        let place = esc(data.address ?? data.city)
        return """
        <div class="map-wrap">
        <h3>Nous trouver</h3>
        <figure class="map"><img src="\(m)" alt="Carte : \(place)" loading="lazy"><figcaption>\(place) — <a href="\(data.mapsURL)">Ouvrir dans Google Maps</a></figcaption></figure>
        </div>
        """
    }

    static func legalLine(data: SiteInput) -> String {
        var parts: [String] = []
        if let s = data.siret, !s.isEmpty { parts.append("SIRET : \(esc(s))") }
        if let d = data.director, !d.isEmpty { parts.append("Dirigeant : \(esc(d))") }
        guard !parts.isEmpty else { return "" }
        return "<p class=\"discreet\">\(parts.joined(separator: " — "))</p>"
    }

    // MARK: - Fiche récapitulative (toutes les données, lisible par un humain)

    static func infosMarkdown(data: SiteInput, pages: [SitePage], ds: DesignSystem? = nil) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "fr_FR")
        fmt.dateFormat = "d MMMM yyyy 'à' HH:mm"
        var L: [String] = []
        L.append("# \(data.name)")
        L.append("")
        L.append("Fiche récapitulative générée le \(fmt.string(from: Date())) — données issues de Google Maps et du site du commerce. Zéro invention : un champ vide = info non trouvée.")
        L.append("")
        L.append("## Identité")
        L.append("- Métier : \(data.category)")
        L.append("- Ville : \(data.city)")
        if let a = data.address, !a.isEmpty { L.append("- Adresse : \(a)") }
        if data.latitude != 0 || data.longitude != 0 { L.append("- GPS : \(data.latitude), \(data.longitude)") }
        if let w = data.website, !w.isEmpty { L.append("- Site web : \(w)") }
        if let s = data.siret, !s.isEmpty { L.append("- SIRET : \(s)") }
        if let d = data.director, !d.isEmpty { L.append("- Dirigeant : \(d)") }
        L.append("")
        L.append("## Coordonnées")
        if !data.phoneDigits.isEmpty { L.append("- Tél : \(data.prettyPhone)  (lien : tel:\(data.phoneDigits))") }
        if let e = data.email, !e.isEmpty { L.append("- Email : \(e)") }
        L.append("- Itinéraire : \(data.mapsURL)")
        L.append("")
        L.append("## Note Google")
        if let g = data.rating, g > 0 {
            L.append("- \(String(format: "%.1f", g))/5  (\(data.reviewCount ?? 0) avis)")
        } else { L.append("- Pas de note trouvée") }
        L.append("")
        L.append("## Avis clients (verbatim, jamais inventés)")
        if data.reviews.isEmpty {
            L.append("- Aucun avis détaillé récupéré")
        } else {
            for r in data.reviews {
                let note = r.rating.map { String(format: "%.0f/5", $0) } ?? "sans note"
                let date = (r.date ?? "").isEmpty ? "" : " (\(r.date!))"
                L.append("- **\(r.author)** [\(note)]\(date) : \(r.text)")
            }
        }
        L.append("")
        L.append("## Horaires")
        if data.hours.isEmpty { L.append("- Non trouvés") }
        else { for h in data.hours { L.append("- \(h)") } }
        L.append("")
        L.append("## Photos locales (dans ce dossier)")
        if data.photoNames.isEmpty { L.append("- Aucune") }
        else { for n in data.photoNames { L.append("- \(n)") } }
        L.append("")
        if let t = ds {
            L.append("## Thème dealé (jamais deux sites pareils)")
            L.append("- \(t.slug) (\(t.styleName)) — hero : \(t.hero.rawValue), cartes : \(t.cards.rawValue)")
            L.append("")
        }
        L.append("## Pages du site généré (dans ce dossier)")
        for p in pages { L.append("- \(p.file) — \(p.navLabel)") }
        L.append("- style.css — feuille de style commune")
        L.append("")
        return L.joined(separator: "\n") + "\n"
    }

    // MARK: - Replis locaux (si l'IA ne répond pas : beau quand même)

    static func fallbackIndex(data: SiteInput, services: [(String, String)], ds: DesignSystem) -> String {
        let cards = services.prefix(3).map { s in
            "<article class=\"card\"><h3>\(esc(s.0))</h3><p>\(esc(s.1))</p></article>"
        }.joined(separator: "\n")
        return """
        \(heroSection(h1: "\(esc(data.name)), votre adresse de confiance", lead: "Le savoir-faire d'un vrai commerce de proximité, à deux pas de chez vous.", data: data, ds: ds))
        <section class="section"><div class="container">
        <h2>\(servicesTitle(ds: ds))</h2>
        <p class="section-sub">\(servicesSub(ds: ds))</p>
        \(serviceCards(allMatches("(<article class=\"card\">.*?</article>)", in: cards), ds: ds))
        </div></section>
        \(reviewsSection(data: data))
        """
    }

    static func fallbackPrestations(data: SiteInput, services: [(String, String)], ds: DesignSystem) -> String {
        let cards = services.map { s in
            "<article class=\"card\"><h3>\(esc(s.0))</h3><p>\(esc(s.1))</p></article>"
        }.joined(separator: "\n")
        return """
        <section class="hero"><div class="container">
        <h1>Nos prestations, en détail</h1>
        <p class="lead">Chaque prestation est réalisée avec le même soin — demandez-nous, on vous conseille.</p>
        </div></section>
        <section class="section"><div class="container">
        \(serviceCards(allMatches("(<article class=\"card\">.*?</article>)", in: cards), ds: ds))
        </div></section>
        <section class="section alt"><div class="container">
        <h2>Comment ça se passe</h2>
        <p class="section-sub">Simple, direct, sans surprise.</p>
        <ol class="steps">
        <li><strong>1. On en parle</strong><span>Un appel ou une visite pour comprendre votre besoin.</span></li>
        <li><strong>2. On s'en occupe</strong><span>Prestation soignée, dans les délais annoncés.</span></li>
        <li><strong>3. On reste là</strong><span>Joignable après coup si quelque chose cloche.</span></li>
        </ol>
        <div class="cta-band"><h2>Besoin d'un devis ?</h2><p>Décrivez-nous votre projet, on vous répond vite.</p><a class="btn btn-call" href="contact.html">Nous contacter</a></div>
        </div></section>
        """
    }

    /// Prestations par défaut selon le métier (le repli n'invente ni prix ni avis)
    static func defaultServices(category: String) -> [(String, String)] {
        let c = category.lowercased()
        let food = ["boul", "restaurant", "pizz", "caf", "bar", "traiteur", "crêpe", "crepe", "boucher", "fleur", "pâtis", "patis", "primeur", "chocolat", "cuisine", "brasserie"].contains(where: { c.contains($0) })
        if food {
            return [
                ("Fabrication maison", "Des produits frais préparés chaque jour sur place, avec des ingrédients choisis."),
                ("À emporter", "Appelez à l'avance et repartez sans faire la queue."),
                ("Pièces et événements", "Gâteaux, plateaux et commandes spéciales pour vos occasions en famille."),
                ("Accueil et conseil", "Une équipe qui connaît ses produits et ses clients par leur prénom."),
            ]
        }
        return [
            ("Devis gratuit", "Un chiffrage clair et sans engagement avant tout commencement."),
            ("Travail soigné", "Une prestation propre, réalisée dans les délais annoncés."),
            ("Conseil personnalisé", "On étudie votre besoin avant de proposer quoi que ce soit."),
            ("Suivi après prestation", "On reste joignable même une fois le travail terminé."),
        ]
    }

    // MARK: - Prompts IA (textes uniquement : ni lien, ni tél, ni image)

    static func prompt(page: SitePage, data: SiteInput, ds: DesignSystem, photoNote: String? = nil) -> String {
        var facts: [String] = ["Nom : \(data.name)", "Métier : \(data.category)", "Ville : \(data.city)"]
        if let r = data.rating, r > 0 { facts.append("Note Google : \(String(format: "%.1f", r))/5 (\(data.reviewCount ?? 0) avis — tu peux la mentionner, JAMAIS inventer d'avis clients)") }
        if !data.photoNames.isEmpty { facts.append("Photos réelles disponibles (\(data.photoNames.count)) — ne les décris pas, le site les affiche déjà") }
        let factsBlock = facts.joined(separator: "\n")
        let common = """
        Tu es un concepteur-rédacteur qui écrit les TEXTES d'un site vitrine français haut de gamme.
        Style imposé (\(ds.styleName)) : \(ds.mood)
        \(designChecklist)
        INFOS RÉELLES (utilise-les, n'invente rien) :
        \(factsBlock)
        PORTRAIT RÉEL (enquête : avis clients, note, photo) :
        \(identityBrief(data: data, photoNote: photoNote))
        Chaque site doit avoir une âme : accroche centrée sur CE portrait (plat phare, ambiance, ce que les clients adorent — tu peux citer un verbatim).
        ÉLÉMENT SIGNATURE IMPOSÉ : \(ds.signature)
        Interdit : titres génériques interchangeables avec un autre commerce ; superlatifs creux (exceptionnel, unique, meilleur, incroyable) sans preuve ; la phrase « Bienvenue ».
        INTERDIT ABSOLU : liens <a>, tel:, numéros de téléphone, emails, prix, horaires, avis clients inventés, emojis, pastilles/kickers au-dessus des titres, numéros 01/02/03, images, <html>, <head>, <style>, <nav>, <footer>, markdown. Réponds en HTML brut uniquement.
        """
        switch page {
        case .index:
            return """
            \(common)
            Écris le contenu d'accueil, exactement dans cet ordre :
            <h1>Titre avec bénéfice client (10 mots max, jamais le seul nom du commerce, jamais « Bienvenue »)</h1>
            <p class="lead">Phrase d'accroche chaleureuse (25 mots max), ancrée dans le portrait réel</p>
            Puis 3 cartes de prestations RÉELLES du métier : <article class="card"><h3>Prestation</h3><p>Une phrase vendeuse et concrète.</p></article> (SANS numéros, SANS pastille)
            Lis tes trois titres seuls : ils doivent raconter CE commerce et aucun autre.
            Français impeccable. 60 lignes max.
            """
        case .prestations:
            return """
            \(common)
            Écris le contenu de la page Prestations :
            <h1>Titre de la page (8 mots max, jamais « Nos prestations » tout seul)</h1>
            <p class="lead">Phrase d'intro qui donne confiance (25 mots max)</p>
            Puis 4 à 6 cartes de prestations RÉELLES du métier : <article class="card"><h3>Titre</h3><p>Une phrase vendeuse et concrète.</p></article> (SANS numéros, SANS pastille)
            Puis 3 étapes : <ol class="steps"><li><strong>1. Titre</strong><span>Explication courte.</span></li>…</ol>
            Français impeccable. 90 lignes max.
            """
        default:
            return ""
        }
    }

    // MARK: - Avis clients réels (verbatim Google, section masquée si aucun)

    static func reviewsSection(data: SiteInput) -> String {
        guard !data.reviews.isEmpty else { return "" }
        let cards = data.reviews.prefix(4).map { r -> String in
            let stars: String
            if let rating = r.rating, rating > 0 {
                stars = "<span class=\"stars\">\(String(repeating: "★", count: max(1, min(5, Int(rating.rounded())))))</span>"
            } else { stars = "" }
            let date = ((r.date ?? "").isEmpty == false) ? ", \(esc(r.date!))" : ""
            return "<article class=\"card review\"><div class=\"review-head\">\(stars)<strong>\(esc(r.author))</strong><span class=\"review-date\">avis Google\(date)</span></div><p>“\(esc(r.text))”</p></article>"
        }.joined(separator: "\n")
        let agg: String
        if let g = data.rating, g > 0 {
            agg = "Note Google : <strong>\(String(format: "%.1f", g))</strong> (\(data.reviewCount ?? 0) avis) — voici ce qu'en disent vraiment les clients."
        } else {
            agg = "Ce qu'en disent vraiment les clients, mot pour mot."
        }
        return """
        <section class="section alt"><div class="container">
        <h2>Ce que disent nos clients</h2>
        <p class="section-sub">\(agg)</p>
        <div class="grid-cards">
        \(cards)
        </div>
        </div></section>
        """
    }

    // MARK: - Portrait réel (l'âme du site : avis, spécialités, ambiance photo)

    static func identityBrief(data: SiteInput, photoNote: String?) -> String {
        var L: [String] = []
        L.append("Commerce : \(data.name) — \(data.category) à \(data.city).")
        if let a = data.address, !a.isEmpty { L.append("Adresse : \(a).") }
        if let r = data.rating, r > 0 { L.append("Note Google : \(String(format: "%.1f", r))/5 (\(data.reviewCount ?? 0) avis).") }
        if let h = data.hours.first, h.lowercased().contains("actuellement") { L.append("En ce moment : \(h).") }
        let stop: Set<String> = Set("le la les de des du un une et est sont dans pour avec sur plus pas que qui ce cette ces son sa ses leur leurs au aux il elle ils elles nous vous votre vos notre nos mais comme tout toute tous tres aussi bien encore deja fait faire entre chez sans sous vers dont ou quand alors donc car ni or bon bonne bons bonnes grand grande petit petite fois peut ete tres".split(separator: " ").map(String.init))
        var freq: [String: Int] = [:]
        let nameWords = Set(data.name.lowercased().split(separator: " ").map(String.init))
        for r in data.reviews {
            for w in r.text.lowercased().split(whereSeparator: { !$0.isLetter }) {
                let s = String(w)
                if s.count >= 4 && !stop.contains(s) && !nameWords.contains(s) { freq[s, default: 0] += 1 }
            }
        }
        let top = freq.filter { $0.value >= 2 }.sorted { $0.value > $1.value }.prefix(6).map { $0.key }
        if !top.isEmpty { L.append("Les clients parlent surtout de : \(top.joined(separator: ", ")).") }
        let quotes = data.reviews.prefix(2).map { "« \(String($0.text.prefix(150))) » (\($0.author))" }
        if !quotes.isEmpty { L.append("Verbatim clients : " + quotes.joined(separator: " / ")) }
        if let n = photoNote, !n.isEmpty { L.append("Ambiance vue en photo : \(n)") }
        return L.joined(separator: "\n")
    }

    // MARK: - Ligne métier + ville en langage naturel (jamais de middots méta)

    static func prettyCategory(_ raw: String) -> String {
        let key = raw.lowercased().replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespaces)
        let fr: [String: String] = [
            "fast food": "Fast-food", "social facility": "Action sociale",
            "veterinary": "Vétérinaire", "veterinaire": "Vétérinaire",
            "restaurant": "Restaurant", "bakery": "Boulangerie",
            "cafe": "Café", "café": "Café", "bar": "Bar",
            "hair salon": "Salon de coiffure", "beauty salon": "Institut de beauté",
            "grocery store": "Épicerie", "supermarket": "Supermarché",
            "pharmacy": "Pharmacie", "doctor": "Cabinet médical",
            "dentist": "Cabinet dentaire", "hotel": "Hôtel",
            "gas station": "Station-service", "car repair": "Garage",
            "gym": "Salle de sport", "school": "École",
        ]
        if let hit = fr[key] { return hit }
        return key.prefix(1).uppercased() + key.dropFirst()
    }

    static func businessLine(data: SiteInput) -> String {
        let label = prettyCategory(data.category)
        let city = data.city.trimmingCharacters(in: .whitespaces)
        if city.isEmpty || city.lowercased() == "ville inconnue" { return label }
        return "\(label) à \(city)"
    }

    static func knownCity(_ city: String) -> String? {
        let c = city.trimmingCharacters(in: .whitespaces)
        if c.isEmpty || c.lowercased() == "ville inconnue" { return nil }
        return c
    }

    // Titres de sections : une voix par thème, jamais le même générique partout.
    static func servicesTitle(ds: DesignSystem) -> String {
        switch ds.slug {
        case "ardoise": return "À la carte"
        case "fourneau": return "Au feu, chaque jour"
        case "riviera": return "Les essentiels"
        case "verger": return "Du jour"
        case "salon": return "Les rituels"
        case "comptoir": return "Nos prestations"
        case "plaza": return "Les incontournables"
        default: return "Le savoir-faire"
        }
    }

    static func servicesSub(ds: DesignSystem) -> String {
        switch ds.slug {
        case "ardoise": return "L'essentiel, servi sans détour."
        case "fourneau": return "Braises, jus et patience."
        case "riviera": return "Simple, frais, à deux pas."
        case "verger": return "Selon le marché et la saison."
        case "salon": return "En douceur, à votre rythme."
        case "comptoir": return "Clair, chiffré, sans surprise."
        case "plaza": return "Généreux, comme à la maison."
        default: return "Fait main, fait pour durer."
        }
    }

    // MARK: - Hero (la posture vient du thème dealé : jamais deux sites pareils)

    /// Ligne de preuve pour les héros éditoriaux : que des faits, aucun signe de jointure.
    static func proofLine(data: SiteInput) -> String {
        var parts: [String] = []
        if let r = data.rating, r > 0 {
            parts.append("<span><span class=\"stars\">★★★★★</span> <strong>\(String(format: "%.1f", r))</strong> (\(data.reviewCount ?? 0) avis Google)</span>")
        }
        if let h = data.hours.first, !h.isEmpty {
            parts.append("<span>\(esc(h))</span>")
        }
        if let c = knownCity(data.city) {
            parts.append("<span>\(icoPin) \(esc(c))</span>")
        }
        guard !parts.isEmpty else { return "" }
        return "<p class=\"proofline\">\(parts.joined())</p>"
    }

    static func heroFigures(_ names: [String], alt: String, cls: String) -> String {
        let imgs = names.map { "<img src=\"\($0)\" alt=\"\(esc(alt))\" loading=\"eager\">" }.joined()
        return "<div class=\"\(cls)\">\(imgs)</div>"
    }

    static func heroSection(h1: String, lead: String, data: SiteInput, ds: DesignSystem) -> String {
        let photos = data.photoNames
        switch ds.hero {
        case .photoBg:
            if let photo = photos.first {
                return """
                <section class="hero hero-bg" style="background-image:linear-gradient(rgba(20,14,9,.55),rgba(20,14,9,.55)),url('\(photo)')">
                <div class="container"><div class="hero-card">
                <h1>\(h1)</h1>
                <p class="lead">\(lead)</p>
                <div class="cta-row">\(ctaRow(data: data))</div>
                \(trustRow(data: data))
                </div></div></section>
                """
            }
        case .photoBelow:
            if let photo = photos.first {
                return """
                <section class="hero"><div class="container"><div class="hero-center">
                <h1>\(h1)</h1>
                <p class="lead" style="margin-left:auto;margin-right:auto">\(lead)</p>
                <div class="cta-row">\(ctaRow(data: data))</div>
                \(trustRow(data: data))
                <figure class="hero-wide"><img src="\(photo)" alt="\(esc(data.name))"><figcaption>En vrai, chez nous.</figcaption></figure>
                </div></div></section>
                """
            }
        case .editorial:
            let duo: String
            if photos.count >= 2 { duo = heroFigures(Array(photos.prefix(2)), alt: data.name, cls: "photo-duo") }
            else if let p = photos.first { duo = heroFigures([p], alt: data.name, cls: "photo-duo") }
            else { duo = "" }
            return """
            <section class="hero hero-editorial"><div class="container">
            \(proofLine(data: data))
            <h1>\(h1)</h1>
            <p class="lead">\(lead)</p>
            <div class="cta-row">\(ctaRow(data: data))</div>
            \(duo)
            </div></section>
            """
        case .band:
            let strip = photos.isEmpty ? "" : heroFigures(Array(photos.prefix(3)), alt: data.name, cls: "photo-strip")
            return """
            <section class="hero"><div class="container"><div class="hero-center">
            <h1>\(h1)</h1>
            <p class="lead" style="margin-left:auto;margin-right:auto">\(lead)</p>
            <div class="cta-row">\(ctaRow(data: data))</div>
            \(trustRow(data: data))
            </div>\(strip)</div></section>
            """
        case .splitFlip:
            if !photos.isEmpty {
                return """
                <section class="hero"><div class="container hero-grid flip">
                \(heroMedia(data: data))
                <div>
                <h1>\(h1)</h1>
                <p class="lead">\(lead)</p>
                <div class="cta-row">\(ctaRow(data: data))</div>
                \(trustRow(data: data))
                </div>
                </div></section>
                """
            }
        case .split:
            break
        }
        // split par défaut — et repli typographique sans photo : le titre géant
        // et la preuve portent l'écran, jamais un fond vide.
        if photos.isEmpty {
            return """
            <section class="hero hero-editorial"><div class="container">
            \(proofLine(data: data))
            <h1>\(h1)</h1>
            <p class="lead">\(lead)</p>
            <div class="cta-row">\(ctaRow(data: data))</div>
            </div></section>
            """
        }
        return """
        <section class="hero"><div class="container hero-grid">
        <div>
        <h1>\(h1)</h1>
        <p class="lead">\(lead)</p>
        <div class="cta-row">\(ctaRow(data: data))</div>
        \(trustRow(data: data))
        </div>
        \(heroMedia(data: data))
        </div></section>
        """
    }

    // MARK: - Assemblage (l'IA fournit le texte, le local impose la mise en page)

    static func firstMatch(_ pattern: String, in s: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func allMatches(_ pattern: String, in s: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap { m in
            guard m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: s) else { return nil }
            let frag = String(s[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            return frag.isEmpty ? nil : frag
        }
    }

    static func heroMedia(data: SiteInput) -> String {
        guard let n = data.photoNames.first else { return "" }
        let badge: String
        if let r = data.rating, r > 0 {
            badge = "<div class=\"hero-badge\"><span class=\"stars\">★★★★★</span> <strong>\(String(format: "%.1f", r))</strong> (\(data.reviewCount ?? 0) avis)</div>"
        } else { badge = "" }
        return "<figure class=\"hero-media\"><img src=\"\(n)\" alt=\"\(esc(data.name))\"><figcaption style=\"display:none\">Photo du commerce</figcaption>\(badge)</figure>"
    }

    static func ctaRow(data: SiteInput) -> String {
        if !data.phoneDigits.isEmpty {
            return "<a class=\"btn btn-call\" href=\"tel:\(data.phoneDigits)\">\(icoPhone)\(data.prettyPhone)</a><a class=\"btn btn-ghost\" href=\"\(data.mapsURL)\">\(icoPin)Itinéraire</a>"
        }
        return "<a class=\"btn btn-call\" href=\"contact.html\">Demander un devis</a><a class=\"btn btn-ghost\" href=\"\(data.mapsURL)\">\(icoPin)Itinéraire</a>"
    }

    static func trustRow(data: SiteInput) -> String {
        var parts: [String] = []
        if let r = data.rating, r > 0 {
            parts.append("<span><span class=\"stars\">★★★★★</span> <strong>\(String(format: "%.1f", r))</strong> (\(data.reviewCount ?? 0) avis Google)</span>")
        }
        if let c = knownCity(data.city) {
            parts.append("<span>\(icoPin) \(esc(c))</span>")
        }
        return "<div class=\"trust\">\(parts.joined(separator: ""))</div>"
    }

    /// Retire les scories d'un fragment IA (pastilles, numéros) : le local impose le rythme.
    static func stripCardChrome(_ html: String) -> String {
        var out = html
        for pattern in ["<p class=\"kicker\">.*?</p>", "<p class=\"card-num\">.*?</p>"] {
            if let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "")
            }
        }
        return out
    }

    /// Rend les cartes au rythme du thème : grille de cartes, ou lignes à filets.
    static func serviceCards(_ cards: [String], ds: DesignSystem) -> String {
        let clean = cards.map { stripCardChrome($0) }
        if ds.cards == .rows {
            let items = clean.map { c -> String in
                let h = firstMatch("<h3[^>]*>(.*?)</h3>", in: c) ?? ""
                let p = firstMatch("<p[^>]*>(.*?)</p>", in: c) ?? ""
                return "<div class=\"row-item\"><h3>\(h)</h3><p>\(p)</p></div>"
            }.joined(separator: "\n")
            return "<div class=\"rows\">\n\(items)\n</div>"
        }
        return "<div class=\"grid-cards\">\n\(clean.joined(separator: "\n"))\n</div>"
    }

    /// Assemble la page d'accueil depuis le fragment IA (nil si inexploitable)
    static func assembleIndex(ai: String, data: SiteInput, ds: DesignSystem) -> String? {
        guard let h1 = firstMatch("<h1[^>]*>(.*?)</h1>", in: ai) else { return nil }
        let cards = allMatches("(<article class=\"card\">.*?</article>)", in: ai)
        guard cards.count >= 2 else { return nil }
        let lead = firstMatch("<p class=\"lead\">(.*?)</p>", in: ai) ?? ""
        return """
        \(heroSection(h1: h1, lead: lead, data: data, ds: ds))
        <section class="section"><div class="container">
        <h2>\(servicesTitle(ds: ds))</h2>
        <p class="section-sub">\(servicesSub(ds: ds))</p>
        \(serviceCards(cards, ds: ds))
        </div></section>
        \(reviewsSection(data: data))
        """
    }

    /// Assemble la page Prestations depuis le fragment IA (nil si inexploitable)
    static func assemblePrestations(ai: String, data: SiteInput, ds: DesignSystem) -> String? {
        guard let h1 = firstMatch("<h1[^>]*>(.*?)</h1>", in: ai) else { return nil }
        let cards = allMatches("(<article class=\"card\">.*?</article>)", in: ai)
        guard cards.count >= 3 else { return nil }
        let lead = firstMatch("<p class=\"lead\">(.*?)</p>", in: ai) ?? ""
        var steps = allMatches("(<li>.*?</li>)", in: ai)
        if steps.count < 2 {
            steps = [
                "<li><strong>1. On en parle</strong><span>Un appel ou une visite pour comprendre votre besoin.</span></li>",
                "<li><strong>2. On s'en occupe</strong><span>Prestation soignée, dans les délais annoncés.</span></li>",
                "<li><strong>3. On reste là</strong><span>Joignable après coup si quelque chose cloche.</span></li>",
            ]
        }
        return """
        <section class="hero"><div class="container">
        <h1>\(h1)</h1>
        <p class="lead">\(lead)</p>
        </div></section>
        <section class="section"><div class="container">
        \(serviceCards(cards, ds: ds))
        </div></section>
        <section class="section alt"><div class="container">
        <h2>Comment ça se passe</h2>
        <p class="section-sub">Simple, direct, sans surprise.</p>
        <ol class="steps">
        \(steps.joined(separator: "\n"))
        </ol>
        <div class="cta-band"><h2>Besoin d'un devis ?</h2><p>Décrivez-nous votre projet, on vous répond vite.</p><a class="btn btn-call" href="contact.html">Nous contacter</a></div>
        </div></section>
        """
    }

    // MARK: - Validation du contenu IA (léger : la mise en page est locale)

    static func cleanContent(_ raw: String) -> String? {
        var out = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if out.hasPrefix("```") {
            out = out.replacingOccurrences(of: "```html", with: "").replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard out.contains("<h1") else { return nil }
        return stripCardChrome(out)
    }

    /// Vrai si le fragment est utilisable : assez riche, sans lien, sans n° inventé.
    static func contentValid(_ content: String, phoneDigits: String) -> Bool {
        guard content.count > 300, content.contains("<h1"),
              content.range(of: "<article class=\"card\"") != nil else { return false }
        let l = content.lowercased()
        if l.contains("<html") || l.contains("tel:") || l.contains("mailto:") { return false }
        if !phoneDigits.isEmpty {
            let tail = String(phoneDigits.suffix(9))
            let digitsOnly = content.filter { $0.isNumber }
            if !tail.isEmpty && digitsOnly.contains(tail) { return false }
        }
        return true
    }

    // MARK: - Divers

    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
