<p align="center">
  <img src="icon_app.png" alt="Logo ProspectorMac" width="180" />
</p>

<h1 align="center">ProspectorMac</h1>

<p align="center">
  <strong>Application macOS de prospection commerciale locale.</strong><br/>
  Elle repère les commerces sans site web (ou avec un site obsolète), collecte leurs données réelles<br/>
  (Google Maps + site existant) et génère un <strong>site vitrine multi-pages de démonstration</strong> pour décrocher un rendez-vous.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/dernier%20commit-novembre%202026-green" alt="dernier commit" />
  <img src="https://img.shields.io/badge/version-1.0-blue" alt="version" />
  <img src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple&logoColor=white" alt="compatibilité macOS 14+" />
  <img src="https://img.shields.io/badge/langage-Swift%20%7C%20Node.js-555?logo=swift&logoColor=white" alt="langage principal" />
  <img src="https://img.shields.io/badge/Swift-5.9-orange?logo=swift&logoColor=white" alt="Swift 5.9" />
  <img src="https://img.shields.io/badge/Node.js-18%2B-339933?logo=node.js&logoColor=white" alt="Node.js 18+" />
  <img src="https://img.shields.io/badge/prix-50%E2%82%AC-brightgreen" alt="prix 50€" />
</p>

<p align="center">
  ⭐ <strong>Star ce repo sur GitHub si ProspectorMac t'aide à signer des clients !</strong> 🙏
</p>

---

## 📖 C'est quoi ProspectorMac ?

**ProspectorMac** est un outil de prospection terrain pensé pour les **freelances, agences web et commerciaux** qui vendent des sites vitrines aux commerces de proximité (boulangeries, restaurants, salons, artisans…).

Le constat est simple : des milliers de commerces n'ont **aucun site**, ou un site **obsolète** (non-HTTPS, non-responsive, daté). ProspectorMac te permet d'arriver en rendez-vous **avec déjà une preuve de valeur** : une maquette de site moderne, avec leurs vraies infos et leurs vraies photos.

Concrètement, l'app fait 3 choses :

1. **🔎 Scanner** — trouve les commerces autour de toi (géolocalisation + Google Maps / Google Places), détecte ceux sans site ou avec un site à problème, et fiche chaque prospect (adresse, téléphone, horaires, note Google, avis, SIRET…).
2. **🕵️ Auditer** — passe leur site existant au crible via un scraper local (HTTPS, SEO, images, responsive) et explique pourquoi il leur fait perdre des clients.
3. **✨ Générer** — crée un **site vitrine démo en 4 pages** (Accueil, Prestations, Galerie, Contact) avec textes IA + mise en page 100 % locale, prévisualisé dans l'app. Tu n'as plus qu'à envoyer l'email ou pitcher au téléphone.

> L'IA rédige les textes, mais **ne peut ni inventer un téléphone, ni casser le design** : les données affichées viennent du commerce, le design est assemblé en local.

## ✨ Fonctionnalités

- **Prospection par zone** : scan autour de moi (1 à 30 km), filtre par activité / statut (Tous, Sans site, Site obsolète, Prêts à contacter).
- **Fiche prospect complète** : nom, catégorie, ville, badge d'opportunité (« Aucun site » / « Site obsolète »), note Google, coordonnées trouvées, dirigeant, SIRET…
- **Audit de site existant** via le scraper local (HTTPS, SEO, images, responsive, captures avant/après).
- **Génération de site vitrine** (Accueil, Prestations, Galerie, Contact) :
  - **8 thèmes visuels** (éditorial bistrot, feu-matière, lumière côtière, marché frais, soin apaisé, service net, fiesta gourmande, geste artisanal), attribués de façon **déterministe** — un commerce = un univers, jamais deux sites pareils.
  - **Vraies images** : d'abord celles du site existant du commerce (`/scrape/site-images`), puis les photos Google — avatars et logos exclus.
  - Textes rédigés par IA (FreeLLMAPI), mise en page 100 % locale.
- **Aperçu réel** dans une vraie fenêtre `WKWebView` (jamais de `.sheet` imbriqué).
- **Kit commercial IA** : email prêt à envoyer (`mailto:` pré-rempli avec lien maquette) + script d'appel téléphonique (accroche, argumentaire, objections).
- **Lien Figma** : export JSON + micro-plugin Figma pour dessiner la maquette dans Figma Desktop.

## 🧠 Comment ça marche ? (Pipeline)

```
Géolocalisation (CoreLocation)
  → Recherche commerces (Google Places API New, fallback scraping Google Maps via Playwright)
    → Filtrage sans-site / site obsolète + audit Playwright
      → Enrichissement OSINT (pages /contact, mentions-légales, annuaires publics)
        → Récup photos + avis réels
          → FreeLLMAPI (http://127.0.0.1:31415/v1) génère textes + structure JSON
            → Assemblage local (SiteBuilder + DesignSystem, 8 thèmes)
              → Préview WKWebView + export Figma + email / pitch
```

- **Moteur IA (FreeLLMAPI)** : instance locale sur `http://127.0.0.1:31415/v1` (endpoint `/v1/chat/completions`, compatible SDK OpenAI). Clé `freellmapi-...` à saisir dans les **Réglages** de l'app (stockée en `UserDefaults`, jamais dans le code).
- **Scraper** : micro-service Node.js + Playwright sur le port `31416` (Google Maps, images du site, mapshot, rate-limiting).

## 🖥️ Compatibilité

| Composant | Requis |
| --------- | ------ |
| OS | **macOS 14+** |
| Langages | **Swift 5.9+ / SwiftUI** (app) + **Node.js 18+** (scraper) |
| IDE | Xcode 15+ recommandé |
| IA | FreeLLMAPI en local sur le port `31415` |
| Base locale | SQLite |

## 🚀 Installation

```bash
./setup.sh        # installe les dépendances + Chromium Playwright (sans sudo, espace utilisateur uniquement)
```

Le script :
- vérifie Node.js,
- fait `npm install` dans `scraper-engine/`,
- installe Chromium Playwright,
- teste la connexion à `http://127.0.0.1:31415/v1`.

## ▶️ Lancement

```bash
# 1. Scraper (port 31416)
cd scraper-engine && node src/server.js

# 2. App (dans un autre terminal)
swift run
```

Ou ouvrez `ProspectorMac.app` (binaire release dans `ProspectorMac.app/Contents/MacOS/`).

Au premier lancement : ouvre les **Réglages**, colle ta clé `freellmapi-...`, clique **« Scanner autour de moi »**, choisis ton rayon, clique sur une carte prospect pour voir audit + maquette + email + pitch.

## 🗂️ Architecture

```
Sources/
  ProspectorMac.swift   # UI SwiftUI + pipeline de génération
  SiteBuilder.swift      # CSS, héros, assemblage des pages (design local)
  DesignSystem.swift     # 8 thèmes + attribution déterministe par commerce
scraper-engine/
  src/server.js          # scraping Google Maps, images du site, mapshot
figma-plugin/
  manifest.json + code.js # dessine la maquette dans Figma depuis le JSON exporté
Skills/
  hallmark/              # skill direction artistique (composition, thèmes)
  impeccable/            # skill craft UI (typographie, layout, polish)
Sites/                   # sites générés (non versionné, voir .gitignore)
```

## 🎨 Règles de design (issues des skills)

- Un seul message par écran, H1 porteur de sens (≤ 10 mots).
- Interdits : kickers/pastilles, numéros 01/02/03, flèches, emojis en icônes, dégradés violet→bleu, cartes identiques partout, avis inventés.
- Contraste texte/fond ≥ 4.5:1, focus clavier visible, responsive + `prefers-reduced-motion`.
- Preuve d'abord : note Google, verbatims clients réels, photos réelles.

## 🔒 Sécurité

⚠️ La clé API FreeLLMAPI se saisit dans les **Réglages** de l'app (conservée localement dans `UserDefaults`, jamais dans le code). Gardez ce dépôt **privé** par précaution.

## 👥 Créateurs / Contributeurs

ProspectorMac a été créé par **Marin Babinger** et **Nolan Vauthier**.

| Nom | GitHub | LinkedIn |
| --- | ------ | -------- |
| **Marin Babinger** | [@Vort1x](https://github.com/Vort1x) | [marin-babinger](https://www.linkedin.com/in/marin-babinger/) |
| **Nolan Vauthier** | [@vauthiernolan0-lang](https://github.com/vauthiernolan0-lang) | [nolan-vauthier-314b553ab](https://www.linkedin.com/in/nolan-vauthier-314b553ab/) |

<p>
  <a href="https://github.com/Vort1x"><img src="https://img.shields.io/badge/GitHub-Vort1x-181717?logo=github&logoColor=white" alt="GitHub Marin" /></a>
  <a href="https://www.linkedin.com/in/marin-babinger/"><img src="https://img.shields.io/badge/LinkedIn-Marin%20Babinger-0A66C2?logo=linkedin&logoColor=white" alt="LinkedIn Marin" /></a>
  <a href="https://github.com/vauthiernolan0-lang"><img src="https://img.shields.io/badge/GitHub-vauthiernolan0--lang-181717?logo=github&logoColor=white" alt="GitHub Nolan" /></a>
  <a href="https://www.linkedin.com/in/nolan-vauthier-314b553ab/"><img src="https://img.shields.io/badge/LinkedIn-Nolan%20Vauthier-0A66C2?logo=linkedin&logoColor=white" alt="LinkedIn Nolan" /></a>
</p>

## 💰 Prix

**50 €** — licence d'utilisation de ProspectorMac.

## 📄 Licence

Projet privé — tous droits réservés aux créateurs (voir section ci-dessus). Contactez-nous via LinkedIn pour toute utilisation commerciale.
