import Foundation

// Moteur de design system : 8 THÈMES complets (palette + typographies +
// posture de hero + rythme de cartes + idée signature), d'où chaque commerce
// reçoit EXACTEMENT UN univers, tiré au sort de façon déterministe
// (même nom = même thème, cf dealTheme).
//
// Règles distillées des skills « Hallmark » et « Impeccable » (voir Skills/) :
//  - un seul message par écran, ~80 mots max, le H1 porte le sens (7-10 mots) ;
//  - INTERDIT : kickers/pastilles au-dessus des titres, numéros 01/02/03,
//    chaînes méta jointes par des middots, flèches collées aux liens,
//    dégradés violet→bleu, cartes identiques partout, emojis comme icônes,
//    chiffres/avis inventés ;
//  - le thème est un matériau (couleur, type, surfaces), jamais un plan ;
//  - la preuve (note Google, verbatim clients, photos réelles) mène le hero.

// Posture du hero : comment la première écran est composé.
enum HeroPosture: String {
    case split       // texte à gauche, photo à droite
    case splitFlip   // photo à gauche, texte à droite
    case photoBelow  // texte centré, grande photo dessous
    case photoBg     // photo plein-bleed + carte de verre
    case editorial   // titre géant pleine largeur + duo de photos
    case band        // texte centré + bandeau de 3 photos
}

// Rythme des cartes de prestations.
enum CardStyle: String {
    case grid  // cartes en grille (monde posé, lisible)
    case rows  // lignes à filets (monde éditorial, prix/liste)
}

struct DesignSystem {
    let slug: String           // identifiant stable (style.css, logs, INFOS)
    let styleName: String
    let primary: String        // couleur de marque (titres, liens, détails)
    let onPrimary: String      // texte posé sur primary
    let cta: String            // fond du bouton d'appel principal
    let onCTA: String          // texte du bouton d'appel (contraste ≥ 4.5:1)
    let accent: String         // couleur secondaire (infos, cartes)
    let dark: String           // texte fort / bandeaux sombres
    let background: String     // fond de page
    let card: String           // fond des cartes
    let muted: String          // fond des sections alternées
    let border: String         // bordures fines
    let fg: String             // texte courant
    let mutedFg: String        // texte secondaire
    let displayStack: String   // pile de polices titres (100 % locale, sans réseau)
    let bodyStack: String      // pile de polices texte
    let radius: Int            // rayon de coins du thème (8 = net, 20 = doux)
    let hero: HeroPosture
    let cards: CardStyle
    let mood: String           // consigne d'ambiance injectée dans le prompt IA
    let signature: String       // idée signature imposée au rédacteur IA
    let antiPatterns: String
}

// Les 8 thèmes. Chacun est un monde complet, pas une palette : aucun ne
// partage la même combinaison (fond, encre, accent, CTA, typographies,
// hero, cartes). Tous les couples texte/fond ≥ 4.5:1, polices 100 % macOS.
private let allThemes: [DesignSystem] = [
    DesignSystem(
        slug: "ardoise", styleName: "éditorial-bistrot",
        primary: "#7F2D2E", onPrimary: "#FFFFFF",
        cta: "#7F2D2E", onCTA: "#FFFFFF",
        accent: "#2F5D3A", dark: "#201A15",
        background: "#F6F4EE", card: "#FFFFFF", muted: "#ECE7DB",
        border: "#DED5C2", fg: "#201A15", mutedFg: "#5C554B",
        displayStack: "'Didot', 'Bodoni 72', 'Georgia', 'Times New Roman', serif",
        bodyStack: "'Avenir Next', '-apple-system', 'Helvetica Neue', 'Segoe UI', sans-serif",
        radius: 10, hero: .editorial, cards: .rows,
        mood: "éditorial bistrot : papier #F6F4EE, encre #201A15, oxblood #7F2D2E, Didot en grand. Titres monumentaux, filets fins, critique gastronomique assumée.",
        signature: "Ouvre avec le verdict : un verbatim client en exergue géant sous le titre, comme une citation de presse.",
        antiPatterns: "bannis : pastilles au-dessus des titres, numéros 01/02/03, cartes uniformes, dégradés, emojis, faux avis."
    ),
    DesignSystem(
        slug: "fourneau", styleName: "feu-matière",
        primary: "#F2B25C", onPrimary: "#1A120B",
        cta: "#E8641C", onCTA: "#1A120B",
        accent: "#F2B25C", dark: "#F7EFE3",
        background: "#191410", card: "#241B13", muted: "#211912",
        border: "#3A2D20", fg: "#F7EFE3", mutedFg: "#C9BBA6",
        displayStack: "'Avenir Next Condensed', 'Avenir Next', '-apple-system', 'Helvetica Neue', sans-serif",
        bodyStack: "'Avenir Next', '-apple-system', 'Helvetica Neue', 'Segoe UI', sans-serif",
        radius: 14, hero: .photoBg, cards: .grid,
        mood: "feu et matière : fond braise #191410, ambre #F2B25C, CTA braise #E8641C, condensed massif en capitales douces. Nuit, chaleur, braise.",
        signature: "Le feu est le sujet : ambiance braise/nuit dans l'accroche, et la preuve (note, horaires d'ouverture) en bandeau.",
        antiPatterns: "bannis : fond clair, pastilles, numéros, cartes blanches, dégradés violet/bleu, emojis, faux avis."
    ),
    DesignSystem(
        slug: "riviera", styleName: "lumière-côtière",
        primary: "#0B7A75", onPrimary: "#FFFFFF",
        cta: "#C2410C", onCTA: "#FFFFFF",
        accent: "#0B7A75", dark: "#0C2B2A",
        background: "#EDF5F3", card: "#FFFFFF", muted: "#DCEBE7",
        border: "#C4DCD6", fg: "#0C2B2A", mutedFg: "#3E5C5A",
        displayStack: "'Gill Sans', 'Avenir Next', '-apple-system', 'Helvetica Neue', sans-serif",
        bodyStack: "'Avenir Next', '-apple-system', 'Helvetica Neue', 'Segoe UI', sans-serif",
        radius: 18, hero: .photoBelow, cards: .grid,
        mood: "lumière côtière : fond lagon pâle #EDF5F3, sarcelle #0B7A75, CTA corail cuit #C2410C, Gill Sans aérien. Air, horizon, photo panoramique.",
        signature: "L'horizon d'abord : une phrase d'air et de lieu, et l'itinéraire mis au même niveau que l'appel.",
        antiPatterns: "bannis : pastilles, numéros, cartes serrées, ombres lourdes, dégradés, emojis, faux avis."
    ),
    DesignSystem(
        slug: "verger", styleName: "marché-frais",
        primary: "#3E7A2E", onPrimary: "#FFFFFF",
        cta: "#C2410C", onCTA: "#FFFFFF",
        accent: "#3E7A2E", dark: "#1F2A18",
        background: "#F4F6EA", card: "#FFFFFF", muted: "#E5EAD2",
        border: "#D3DBB8", fg: "#1F2A18", mutedFg: "#4E5C43",
        displayStack: "'Futura', 'Avenir Next', '-apple-system', 'Helvetica Neue', sans-serif",
        bodyStack: "'Avenir Next', '-apple-system', 'Helvetica Neue', 'Segoe UI', sans-serif",
        radius: 16, hero: .splitFlip, cards: .grid,
        mood: "marché frais : fond verger #F4F6EA, feuille #3E7A2E, CTA tomate #C2410C, Futura franche. Produit brut, saison, du jour.",
        signature: "Le produit du moment : cite ce que les clients plébiscitent (plat phare, spécialité) dès l'accroche.",
        antiPatterns: "bannis : pastilles, numéros, jargon, dégradés, emojis, faux avis."
    ),
    DesignSystem(
        slug: "salon", styleName: "soin-apaisé",
        primary: "#6E4A61", onPrimary: "#FFFFFF",
        cta: "#6E4A61", onCTA: "#FFFFFF",
        accent: "#0F766E", dark: "#2A2230",
        background: "#F4EFF6", card: "#FFFFFF", muted: "#E7DFEC",
        border: "#D5C9DC", fg: "#2A2230", mutedFg: "#5D5466",
        displayStack: "'Didot', 'Georgia', 'Times New Roman', serif",
        bodyStack: "'Avenir Next', '-apple-system', 'Helvetica Neue', 'Segoe UI', sans-serif",
        radius: 20, hero: .band, cards: .rows,
        mood: "soin apaisé : fond brume #F4EFF6, prune #6E4A61, sarcelle #0F766E en écho, Didot calme. Rituel, douceur, confiance.",
        signature: "Le rituel : trois temps apaisés (accueil, soin, suivi) racontés comme une évidence, un avis en exergue.",
        antiPatterns: "bannis : couleurs criardes, pastilles, numéros, cartes clinquantes, dégradés, emojis, faux avis."
    ),
    DesignSystem(
        slug: "comptoir", styleName: "service-net",
        primary: "#155EEF", onPrimary: "#FFFFFF",
        cta: "#C2410C", onCTA: "#FFFFFF",
        accent: "#0E7C5A", dark: "#0F1B2D",
        background: "#EFF3F8", card: "#FFFFFF", muted: "#E0E8F2",
        border: "#C9D6E8", fg: "#0F1B2D", mutedFg: "#46586F",
        displayStack: "'Helvetica Neue', '-apple-system', 'Segoe UI', sans-serif",
        bodyStack: "'Helvetica Neue', '-apple-system', 'Segoe UI', sans-serif",
        radius: 8, hero: .split, cards: .grid,
        mood: "service net : fond #EFF3F8, bleu franc #155EEF, CTA paprika #C2410C, Helvetica nette, coins presque droits. Clarté, chiffres, preuves.",
        signature: "La preuve chiffrée : note Google, avis et horaires en première ligne, sans détour.",
        antiPatterns: "bannis : rondeurs, pastilles, numéros, ombres lourdes, dégradés, emojis, faux avis."
    ),
    DesignSystem(
        slug: "plaza", styleName: "fiesta-gourmande",
        primary: "#0F766E", onPrimary: "#FFFFFF",
        cta: "#C2410C", onCTA: "#FFFFFF",
        accent: "#B45309", dark: "#2A1C12",
        background: "#FAF1E3", card: "#FFFDF7", muted: "#F1E2C8",
        border: "#E4D2B0", fg: "#2A1C12", mutedFg: "#6B5A45",
        displayStack: "'Avenir Next', 'Futura', '-apple-system', 'Helvetica Neue', sans-serif",
        bodyStack: "'Avenir Next', '-apple-system', 'Helvetica Neue', 'Segoe UI', sans-serif",
        radius: 18, hero: .split, cards: .grid,
        mood: "fiesta gourmande : fond soleil #FAF1E3, sarcelle #0F766E, paprika #C2410C, Avenir massive et joyeuse. Fête, générosité, maison.",
        signature: "La générosité : pâte maison, portions, accueil — cite les mots exacts des clients.",
        antiPatterns: "bannis : grisaille, pastilles, numéros, cartes froides, dégradés violet/bleu, emojis, faux avis."
    ),
    DesignSystem(
        slug: "atelier", styleName: "geste-artisanal",
        primary: "#2F5D3A", onPrimary: "#FFFFFF",
        cta: "#2F5D3A", onCTA: "#FFFFFF",
        accent: "#B45309", dark: "#23271F",
        background: "#F1EFE9", card: "#FBFAF6", muted: "#E3DFD2",
        border: "#CFC8B4", fg: "#23271F", mutedFg: "#5A5F4E",
        displayStack: "'Hoefler Text', 'Palatino', 'Georgia', 'Times New Roman', serif",
        bodyStack: "'Avenir Next', '-apple-system', 'Helvetica Neue', 'Segoe UI', sans-serif",
        radius: 12, hero: .splitFlip, cards: .rows,
        mood: "geste artisanal : fond lin #F1EFE9, forêt #2F5D3A, ocre #B45309, Hoefler Text d'atelier. Matière, main, temps long.",
        signature: "La main : fabrication, matières, temps de travail — le savoir-faire daté et signé.",
        antiPatterns: "bannis : clinquant, pastilles, numéros, cartes plastiques, dégradés, emojis, faux avis."
    ),
]

// Familles de commerces → viviers de thèmes qui portent leur univers.
// Le deal reste déterministe : même commerce = même thème, à vie.
private let foodPool = ["plaza", "fourneau", "verger", "ardoise"]
private let carePool = ["salon", "riviera", "atelier", "ardoise"]
private let defaultPool = ["comptoir", "atelier", "riviera", "ardoise"]

private func themePool(for category: String?) -> [String] {
    let c = (category ?? "").lowercased()
    let food = ["boulanger", "patisser", "pâtisser", "restaurant", "boucher",
                "fromager", "traiteur", "chocolat", "café", "cafe", "brasserie",
                "pizzeria", "cuisine", "alimentaire", "fleur", "supérette",
                "fast", "food", "pizza", "kebab", "burger", "empanada",
                "primeur", "poisson", "caviste", "bar", "crêpe", "crepe",
                "glacier", "sandwich", "bistrot", "auberge", "grill"]
    let care = ["institut", "salon", "coiffure", "spa", "esthét", "esthet",
                "beauté", "beaute", "ongle", "massage", "bien-être", "tatouage",
                "barbier", "yoga", "sophro", "vet", "vétérinaire", "santé",
                "medical", "physio", "ostéo", "social", "foyer", "clinique"]
    if food.contains(where: { c.contains($0) }) { return foodPool }
    if care.contains(where: { c.contains($0) }) { return carePool }
    return defaultPool
}

private func stableHash(_ s: String) -> Int {
    var h = 0
    for scalar in s.unicodeScalars { h = (h &* 31) &+ Int(scalar.value) }
    return abs(h)
}

/// Deal : exactement UN thème par commerce, stable dans le temps.
/// Le nom + le métier déterminent le vivier puis le tirage.
func dealTheme(name: String, category: String?) -> DesignSystem {
    let pool = themePool(for: category)
    let idx = stableHash(name.lowercased() + "|" + (category ?? "").lowercased()) % pool.count
    let slug = pool[idx]
    return allThemes.first(where: { $0.slug == slug }) ?? allThemes[0]
}

// Compatibilité : ancien point d'entrée (un thème = un métier).
func designSystem(for category: String?) -> DesignSystem {
    dealTheme(name: category ?? "", category: category)
}

// Checklist pré-livraison, injectée dans le prompt.
let designChecklist = """
CHECKLIST AVANT DE RÉPONDRE (le skill l'exige) :
1. Hiérarchie : un seul H1 (10 mots max, bénéfice client), sections espacées, un seul message par section.
2. AUCUN badge/pastille/eyebrow au-dessus des titres ; AUCUN numéro 01/02/03 ; AUCUNE flèche → ; AUCUN middot méta.
3. Contraste : texte/fond ≥ 4.5:1, CTA bien visible, focus clavier visible.
4. Cohérence : 2 familles de polices max, palette restreinte aux couleurs imposées.
5. Preuve : note Google affichée si fournie, JAMAIS de faux avis inventés.
6. Contact : AUCUN numéro ni email dans ton contenu (le site les affiche déjà) ; jamais de tel:.
7. Icônes : aucune (le site utilise ses propres pictos SVG), JAMAIS d'emojis. Bannis les superlatifs creux (exceptionnel, unique, meilleur) sans preuve.
"""
