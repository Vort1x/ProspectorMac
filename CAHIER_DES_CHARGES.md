# Cahier des charges — Application macOS de prospection locale automatisée

## 1. Stack technique et contraintes d'environnement
- **Application native :** Swift / SwiftUI (macOS 14+), architecture MVVM propre.
- **Moteur d'automatisation & scraping :** Micro-service local en Node.js (Playwright) piloté par l'application Swift via `Process` (ou serveur local HTTP léger), installable **strictement en espace utilisateur (`~/.npm-global` ou dossier local) sans nécessiter de privilèges `sudo` ni Homebrew global**.
- **Base de données locale :** SQLite (via GRDB ou SwiftData) pour stocker les prospects, leur statut, les captures d'écran, les liens Figma et les textes générés.
- **Moteur IA (FreeLLMAPI) :**
  - Connexion par défaut à l'instance locale **FreeLLMAPI** tournant sur `http://127.0.0.1:31415/v1` (endpoint `/v1/chat/completions`, compatible SDK OpenAI).
  - Authentification via header `Authorization: Bearer <clé_api>` (clé unifiée au format `freellmapi-...` configurable dans les Réglages de l'application).
  - Modèle configurable dans les réglages (par défaut `auto` ou le modèle sélectionné via `/v1/models`).
- **APIs externes & Liens :**
  - CoreLocation (macOS) pour récupérer la position GPS exacte de l'utilisateur (avec fallback par saisie manuelle de ville/code postal).
  - Google Places API (New) + fallback scraping Google Maps via Playwright si aucune clé API n'est renseignée.
  - Figma Plugin API locale (`manifest.json` + `code.js`) + lien direct `figma://` / HTTPS vers le fichier Figma du prospect.

## 2. Architecture de l'interface macOS (Expérience utilisateur)
- **Vue d'accueil principale (Dès l'ouverture de l'app) :**
  - L'écran principal affiche immédiatement **tous les clients potentiels trouvés**, sous forme de **grille de cartes moderne et lisible** occupant l'espace principal (sans écran d'accueil vide ou menu complexe qui bloque la vue).
  - En haut de cette vue : une barre d'action compacte avec le bouton **« Scanner autour de moi »** (utilisant la géolocalisation), un sélecteur de rayon (1 à 30 km), un champ de filtre par activité/statut (Tous, Sans site, Site obsolète, Prêts à contacter), un bouton Réglages (pour saisir la clé `freellmapi-...`) et un indicateur de statut de connexion à `http://127.0.0.1:31415/v1`.
  - Chaque carte prospect affiche en un coup d'œil : le nom de l'entreprise, sa catégorie, sa ville, son badge d'opportunité (« Aucun site » ou « Site obsolète »), sa note Google, et des pastilles indiquant ce qui est prêt (Coordonnées trouvées, Maquette Figma générée, Email & Pitch prêts).
- **Vue de détail au clic sur un prospect (Sheet / NavigationPush ou panneau large) :**
  - Cliquer sur n'importe quel prospect ouvre sa fiche complète présentant tout le travail généré automatiquement par l'IA et le scraper, avec des **liens cliquables directs** vers chaque ressource :
    1. **Liens externes rapides en en-tête :** Lien vers sa fiche Google Maps, lien vers son ancien site web (s'il existe), lien direct pour ouvrir sa **maquette dans Figma**, et bouton d'action principal **« Envoyer l'email »** (lien `mailto:` prérempli).
    2. **Section Audit & Coordonnées :** Adresse, téléphone, email(s) trouvés sur le web, nom du dirigeant si trouvé, et diagnostic IA expliquant pourquoi son site actuel lui fait perdre des clients (avec captures d'écran avant/après).
    3. **Section Maquette Figma :** Aperçu visuel de la maquette générée + bouton d'export/ouverture dans Figma.
    4. **Section Prospection IA (Éditable) :**
       - **Email prêt à envoyer :** Objet + corps personnalisés par FreeLLMAPI intégrant le lien vers la maquette Figma, accompagné d'un bouton qui déclenche le lien `mailto:email@prospect.fr?subject=...&body=...`.
       - **Pitch téléphonique :** Script structuré (accroche, argumentaire, réponse aux objections) prêt à être lu pendant l'appel.

## 3. Pipeline d'automatisation en arrière-plan
1. **Géolocalisation & Extraction :** `CLLocationManager` récupère la position -> recherche des commerces alentour -> filtrage des établissements sans site web (ou avec simple lien Facebook/Instagram) et audit technique via Playwright des sites existants (absence de HTTPS, non-responsive mobile, design/code daté).
2. **Enrichissement OSINT :** Si l'email ou le téléphone manque sur Google Maps, scraping des pages `/contact` et `/mentions-legales` du site (s'il existe) et recherche web automatisée (annuaires publics, PagesJaunes, Societe.com/Pappers) pour récupérer l'email, le téléphone et le nom du gérant.
3. **Génération de la maquette Figma :**
   - Récupération des photos Google Maps, avis clients et informations réelles du commerce.
   - Génération via **FreeLLMAPI** (`http://127.0.0.1:31415/v1/chat/completions`) d'une structure JSON de page web complète (textes réels adaptés au commerce, palette de couleurs cohérente, sections Hero, Services/Carte, Avis Google, Horaires, Contact).
   - **Direction artistique stricte :** Design sobre, éditorial et professionnel. **Interdiction des clichés "AI-slop"** (pas de dégradés violets génériques, pas de boutons pilules trop arrondis, pas de cartes uniformes sans hiérarchie). Privilégier des angles nets, une typographie marquée et des espaces blancs maîtrisés.
   - Création d'un micro-plugin Figma (`figma-plugin/manifest.json` + `code.js`) fourni dans le projet qui lit le JSON exporté par l'app Mac et dessine automatiquement la maquette complète dans Figma Desktop, en enregistrant l'URL du fichier Figma dans la fiche du prospect.
4. **Rédaction commerciale via FreeLLMAPI :** Génération automatique de l'email personnalisé (avec insertion dynamique du lien de la maquette) et du script d'appel téléphonique.

## 4. Livrables attendus
1. Arborescence complète dans le dossier courant :
   - `ProspectorMac/` (code source complet Swift/SwiftUI compilable).
   - `scraper-engine/` (moteur Node.js/Playwright avec gestion des erreurs et rate-limiting).
   - `figma-plugin/` (plugin Figma prêt à importer pour générer les maquettes à partir du JSON).
2. Code source intégral sans placeholders (`// TODO`), avec gestion asynchrone (`async/await`) et mise à jour en temps réel de l'interface au fur et à mesure que les prospects sont trouvés et traités par FreeLLMAPI.
3. Script `setup.sh` exécutable sans `sudo` qui installe les dépendances locales Node.js/Playwright et teste la connexion à `http://127.0.0.1:31415/v1`.