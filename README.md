# ProspectorMac

Application macOS de **prospection commerciale locale** : elle repère les commerces
sans site web (ou avec un site obsolète), collecte leurs données réelles
(Google Maps + site existant) et génère un **site vitrine multi-pages de démonstration**
pour décrocher un rendez-vous.

## Fonctionnalités

- **Prospection** : recherche de commerces par zone, fiche prospect complète
  (adresse, téléphone, horaires, note Google, avis, SIRET…).
- **Audit de site existant** via le scraper local (HTTPS, SEO, images, responsive).
- **Génération de site vitrine** (Accueil, Prestations, Galerie, Contact) :
  - **8 thèmes visuels** (éditorial bistrot, feu-matière, lumière côtière,
    marché frais, soin apaisé, service net, fiesta gourmande, geste artisanal),
    dealé de façon **déterministe** — un commerce = un univers, jamais deux sites pareils.
  - **Vraies images** : d'abord celles du site existant du commerce
    (`/scrape/site-images`), puis les photos Google — avatars et logos exclus.
  - Textes rédigés par IA (FreeLLMAPI), mise en page 100 % locale :
    l'IA ne peut ni inventer un téléphone, ni casser le design.
- **Aperçu** dans une vraie fenêtre `WKWebView` (jamais de `.sheet` imbriqué).

## Prérequis

- macOS 14+, Xcode / Swift 5.9+
- Node.js 18+ (scraper)
- [FreeLLMAPI](http://127.0.0.1:31415) en local sur le port `31415`

## Installation

```bash
./setup.sh        # installe les dépendances + Chromium Playwright
```

## Lancement

```bash
# 1. Scraper (port 31416)
cd scraper-engine && node src/server.js

# 2. App (dans un autre terminal)
swift run
```

Ou ouvrez `ProspectorMac.app` (binaire release signé dans
`ProspectorMac.app/Contents/MacOS/`).

## Architecture

```
Sources/
  ProspectorMac.swift   # UI SwiftUI + pipeline de génération
  SiteBuilder.swift      # CSS, héros, assemblage des pages (design local)
  DesignSystem.swift     # 8 thèmes + deal déterministe par commerce
scraper-engine/
  src/server.js          # scraping Google Maps, images du site, mapshot
Skills/
  hallmark/              # skill direction artistique (composition, thèmes)
  impeccable/            # skill craft UI (typographie, layout, polish)
Sites/                   # sites générés (non versionné, voir .gitignore)
```

## Règles de design (issues des skills)

- Un seul message par écran, H1 porteur de sens (≤ 10 mots).
- Interdits : kickers/pastilles, numéros 01/02/03, flèches, emojis en icônes,
  dégradés violet→bleu, cartes identiques partout, avis inventés.
- Contraste texte/fond ≥ 4.5:1, focus clavier visible, responsive + `prefers-reduced-motion`.
- Preuve d'abord : note Google, verbatims clients réels, photos réelles.

## Sécurité

⚠️ La clé API FreeLLMAPI se saisit dans les **Réglages** de l'app
(elle est conservée localement dans `UserDefaults`, jamais dans le code).
Gardez ce dépôt **privé** par précaution.
