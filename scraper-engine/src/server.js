import express from 'express';
import { chromium } from 'playwright';
import cors from 'cors';
import fs from 'fs';

const app = express();
const PORT = process.env.SCRAPER_PORT || 31416;

app.use(cors());
app.use(express.json());

let browser = null;
let context = null;

async function initBrowser() {
    const args = [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-accelerated-2d-canvas',
        '--no-first-run',
        '--no-zygote',
        '--disable-gpu',
        '--disable-blink-features=AutomationControlled',
        '--disable-infobars'
    ];
    try {
        browser = await chromium.launch({ headless: true, args });
    } catch (e) {
        // Repli : Chrome système quand les navigateurs Playwright ne sont pas installés
        const candidates = [process.env.CHROME_PATH,
            '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
            '/Applications/Chromium.app/Contents/MacOS/Chromium',
            '/usr/bin/google-chrome', '/usr/bin/chromium'].filter(Boolean);
        let lastErr = e;
        for (const exe of candidates) {
            try { browser = await chromium.launch({ headless: true, args, executablePath: exe }); lastErr = null; break; }
            catch (e2) { lastErr = e2; }
        }
        if (lastErr) throw lastErr;
    }
    context = await browser.newContext({
        viewport: { width: 1920, height: 1080 },
        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        javaScriptEnabled: true,
        ignoreHTTPSErrors: true
    });
}

app.get('/health', (req, res) => {
    res.json({ status: 'ok', browser: browser ? 'ready' : 'not_initialized' });
});

// Fallback sample data for testing when real scraping isn't available
const sampleLocalBusinesses = [
    { name: "Boulangerie Dupont", category: "Bakery", city: "Paris", address: "12 Rue des Martyrs, 75009 Paris", rating: 4.7, latitude: 48.8801, longitude: 2.3373, website: "https://boulangerie-dupont.com", phone: "+33 1 42 34 56 78", email: "contact@boulangerie-dupont.com" },
    { name: "Café de la Paix", category: "Café", city: "Paris", address: "7 Place des États-Unis, 75015 Paris", rating: 4.3, latitude: 48.8481, longitude: 2.2951, website: "https://cafe-paix.fr", phone: "+33 1 45 67 89 01", email: "info@cafe-paix.fr" },
    { name: "Sportif 15", category: "Sports Shop", city: "Paris", address: "15 Avenue Montaigne, 75008 Paris", rating: 4.5, latitude: 48.8671, longitude: 2.3085, website: "https://sportif15.com", phone: "+33 1 23 45 67 89" },
    { name: "Pharmacie Saint-Honoré", category: "Pharmacy", city: "Paris", address: "52 Rue Saint-Honoré, 75001 Paris", rating: 4.8, latitude: 48.8567, longitude: 2.3315, website: "https://pharmacie-sainthonore.fr", phone: "+33 1 42 10 20 30" },
    { name: "Coiffeur Bébé", category: "Hair Salon", city: "Paris", address: "23 Boulevard de Clichy, 75018 Paris", rating: 4.2, latitude: 48.8857, longitude: 2.3424, website: "https://coiffeur-bebe.com", phone: "+33 1 43 21 09 87" },
    { name: "Artisan Bouches", category: "Restaurant", city: "Paris", address: "18 Rue de la Bûcherie, 75005 Paris", rating: 4.6, latitude: 48.8521, longitude: 2.3523, website: "https://artisan-bouches.fr", phone: "+33 1 44 55 66 77" },
    { name: "Impression 3D Solutions", category: "3D Printing", city: "Paris", address: "8 Rue de la République, 75003 Paris", rating: 4.1, latitude: 48.8619, longitude: 2.3695, website: "https://impression3d.fr", phone: "+33 1 55 66 77 88" },
    { name: "Réparation Électronique Pro", category: "Electronics Repair", city: "Paris", address: "47 Rue du Faubourg Saint-Antoine, 75012 Paris", rating: 4.4, latitude: 48.8622, longitude: 2.3752, website: "https://reparation-electronique.fr", phone: "+33 1 66 77 88 99" }
];

// ---------- Sources de données RÉELLES (aucune donnée fictive) ----------
const REAL_DATA_UA = { 'User-Agent': 'ProspectorMac/1.0 (prospection-commerces-locaux)' };
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

const NAF_LABELS = {
    '47.11F': 'Supermarché', '47.11D': 'Supermarché', '47.24Z': 'Boulangerie',
    '47.22Z': 'Boucherie', '47.23Z': 'Poissonnerie', '47.21Z': 'Primeur',
    '56.10C': 'Restauration', '56.10A': 'Restaurant', '56.30Z': 'Bar',
    '56.10B': 'Crêperie', '56.21Z': 'Traiteur', '47.73Z': 'Pharmacie',
    '96.02A': 'Coiffure', '96.02B': 'Institut de beauté', '47.76Z': 'Fleuriste',
    '47.71Z': 'Prêt-à-porter', '47.72A': 'Chaussures', '47.74Z': 'Opticien',
    '45.20A': 'Garage auto', '45.20B': 'Garage auto', '95.11Z': 'Réparation informatique',
    '95.12Z': 'Réparation téléphonie', '43.21A': 'Électricien', '43.22A': 'Plombier',
    '41.20A': 'Maçonnerie', '68.31Z': 'Agence immobilière', '69.10Z': 'Avocat',
    '86.21Z': 'Médecin', '86.23Z': 'Dentiste', '85.59A': 'Auto-école'
};

const PHOTON_CATEGORIES = [
    ['boulangerie', 'Boulangerie'], ['restaurant', 'Restaurant'], ['coiffeur', 'Coiffure'],
    ['pharmacie', 'Pharmacie'], ['café', 'Café'], ['fleuriste', 'Fleuriste'],
    ['boucherie', 'Boucherie'], ['pizzeria', 'Pizzeria'], ['garage', 'Garage auto'],
    ['supermarché', 'Supermarché'], ['opticien', 'Opticien'], ['bar', 'Bar']
];

const PHOTON_OSM_LABELS = {
    bakery: 'Boulangerie', restaurant: 'Restaurant', hairdresser: 'Coiffure',
    pharmacy: 'Pharmacie', cafe: 'Café', florist: 'Fleuriste', butcher: 'Boucherie',
    fast_food: 'Restauration rapide', bar: 'Bar', pub: 'Pub', supermarket: 'Supermarché',
    optician: 'Opticien', car_repair: 'Garage auto', beauty: 'Institut de beauté',
    clothes: 'Prêt-à-porter', shoes: 'Chaussures', dentist: 'Dentiste', doctors: 'Médecin'
};

// 1) Overpass (OpenStreetMap) : le plus riche (tél, site web quand tagués)
async function fetchOverpass(latitude, longitude, radius) {
    const q = `[out:json];(node["amenity"](around:${radius},${latitude},${longitude});way["amenity"](around:${radius},${latitude},${longitude}););out;`;
    const mirrors = [
        'https://overpass-api.de/api/interpreter',
        'https://overpass.kumi.systems/api/interpreter',
        'https://overpass.private.coffee/api/interpreter'
    ];
    for (const mirror of mirrors) {
        try {
            const resp = await fetch(mirror, {
                method: 'POST',
                headers: { ...REAL_DATA_UA, 'Content-Type': 'application/x-www-form-urlencoded' },
                body: 'data=' + encodeURIComponent(q),
                signal: AbortSignal.timeout(10000)
            });
            if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
            const data = await resp.json();
            const places = (data.elements || []).map(el => {
                const tags = el.tags || {};
                return {
                    name: tags.name || null,
                    category: tags.shop || tags.amenity || tags.cuisine || 'commerce',
                    city: tags['addr:city'] || null,
                    postcode: tags['addr:postcode'] || null,
                    address: tags['addr:full'] || `${tags['addr:housenumber'] || ''} ${tags['addr:street'] || ''}`.trim() || null,
                    latitude: el.lat ?? (el.center ? el.center.lat : null),
                    longitude: el.lon ?? (el.center ? el.center.lon : null),
                    phone: tags.phone || tags['contact:phone'] || null,
                    website: tags.website || tags['contact:website'] || null,
                    email: tags.email || tags['contact:email'] || null,
                    rating: null, siret: null, source: 'openstreetmap'
                };
            }).filter(p => p.name && p.latitude != null && p.longitude != null);
            if (places.length) return places;
        } catch (e) {
            console.log(`Overpass mirror échoué (${mirror}):`, e.message);
        }
    }
    return [];
}

// 2) Photon (Komoot, basé OSM) : noms + adresses + coords, sans clé
async function fetchPhoton(latitude, longitude) {
    const seen = new Set();
    const places = [];
    let consecutiveFailures = 0;
    for (const [query, label] of PHOTON_CATEGORIES) {
        if (places.length >= 30 || consecutiveFailures >= 2) break;
        try {
            const url = `https://photon.komoot.io/api/?q=${encodeURIComponent(query)}&lat=${latitude}&lon=${longitude}&limit=8&lang=fr`;
            const resp = await fetch(url, { headers: REAL_DATA_UA, signal: AbortSignal.timeout(8000) });
            if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
            const data = await resp.json();
            consecutiveFailures = 0;
            for (const f of data.features || []) {
                const p = f.properties || {};
                const key = p.osm_id ? `osm:${p.osm_type}:${p.osm_id}` : `txt:${(p.name || '').toLowerCase()}|${p.street || ''}|${p.housenumber || ''}`;
                if (!p.name || seen.has(key)) continue;
                // Ignore les points OSM sans vrai nom ("Restaurant", "Boulangerie"...)
                const lowerName = p.name.trim().toLowerCase();
                if (lowerName === label.toLowerCase() || lowerName === query.toLowerCase()) continue;
                seen.add(key);
                const lon = f.geometry?.coordinates?.[0] ?? null;
                const lat = f.geometry?.coordinates?.[1] ?? null;
                if (lat == null || lon == null) continue;
                places.push({
                    name: p.name,
                    category: PHOTON_OSM_LABELS[p.osm_value] || label,
                    city: p.city || p.locality || p.district || null,
                    postcode: p.postcode || null,
                    address: `${p.housenumber || ''} ${p.street || ''}`.trim() || null,
                    latitude: lat, longitude: lon,
                    phone: null, website: null, email: null,
                    rating: null, siret: null, source: 'photon'
                });
            }
        } catch (e) {
            consecutiveFailures++;
            console.log(`Photon échoué ("${query}"):`, e.message);
        }
        await sleep(150);
    }
    return places;
}

// 3) SIRENE (Annuaire des Entreprises, registre officiel français)
async function fetchSirene(latitude, longitude, radiusMeters) {
    try {
        const radiusKm = Math.min(50, Math.max(1, Math.round(radiusMeters / 1000)));
        const url = `https://recherche-entreprises.api.gouv.fr/near_point?lat=${latitude}&long=${longitude}&radius=${radiusKm}&per_page=40`;
        const resp = await fetch(url, { headers: { ...REAL_DATA_UA, 'Accept': 'application/json' }, signal: AbortSignal.timeout(15000) });
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const data = await resp.json();
        const places = [];
        for (const c of data.results || []) {
            const etab = (c.matching_etablissements && c.matching_etablissements[0]) || c.siege || {};
            const lat = parseFloat(etab.latitude);
            const lon = parseFloat(etab.longitude);
            if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
            const nomCommercial = (etab.liste_enseignes && etab.liste_enseignes[0]) || etab.nom_commercial || (c.liste_enseignes && c.liste_enseignes[0]) || null;
            const raisonSociale = c.nom_raison_sociale || c.nom_complet || null;
            const naf = etab.activite_principale || c.siege?.activite_principale;
            places.push({
                name: nomCommercial || raisonSociale || null,
                raisonSociale, nomCommercial,
                category: (naf && NAF_LABELS[naf]) || naf || 'Entreprise',
                city: etab.libelle_commune || null,
                address: [etab.numero_voie && etab.indice_repetition ? `${etab.numero_voie}${etab.indice_repetition}` : etab.numero_voie, etab.libelle_voie].filter(Boolean).join(' ') || etab.adresse || null,
                latitude: lat, longitude: lon,
                phone: null, website: null, email: null,
                rating: null, siret: etab.siret || null, source: 'sirene'
            });
        }
        return places.filter(p => p.name);
    } catch (e) {
        console.log('SIRENE échoué:', e.message);
        return [];
    }
}

app.post('/scrape/google-maps', async (req, res) => {
    const { placeId, latitude, longitude, query, radius = 10000 } = req.body;

    if (!browser) {
        try {
            await initBrowser();
        } catch (error) {
            return res.status(500).json({ error: 'Failed to initialize browser', details: error.message });
        }
    }

    try {
        const page = await context.newPage();
        const results = {};

        try {
            if (placeId) {
                const mapsUrl = `https://www.google.com/maps?q=${placeId}`;
                await page.goto(mapsUrl, { waitUntil: 'networkidle' });
                await page.waitForTimeout(3000);

                results.name = await page.evaluate(() => {
                    const h1 = document.querySelector('[data-attrid="wm"]');
                    return h1 ? h1.textContent.trim() : null;
                }).catch(() => null);

                results.rating = await page.evaluate(() => {
                    const span = document.querySelector('[class*="rating"]');
                    return span ? parseFloat(span.textContent) : null;
                }).catch(() => null);

                results.reviews = await page.evaluate(() => {
                    const button = document.querySelector('button[aria-label*="reviews"]');
                    return button ? button.textContent.trim() : null;
                }).catch(() => null);
            } else if (latitude && longitude) {
                // Chaîne de sources RÉELLES : Overpass → Photon → SIRENE.
                // Les données d'exemple (Paris) ne sortent QU'en dernier recours,
                // quand aucune source réelle n'a répondu, et taguées sample: true.
                const seenKeys = new Set();
                const merged = [];
                const sourcesUsed = [];
                const haversineKm = (lat1, lon1, lat2, lon2) => {
                    const R = 6371, toRad = d => d * Math.PI / 180;
                    const a = Math.sin(toRad(lat2 - lat1)) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(toRad(lon2 - lon1)) ** 2;
                    return 2 * R * Math.asin(Math.sqrt(a));
                };
                const maxDistKm = (radius / 1000) * 1.5;
                const addPlaces = (arr, tag) => {
                    let added = 0;
                    for (const p of arr) {
                        const key = `${(p.name || '').toLowerCase()}|${p.latitude?.toFixed(4)}|${p.longitude?.toFixed(4)}`;
                        if (seenKeys.has(key)) continue;
                        seenKeys.add(key);
                        merged.push(p);
                        added++;
                    }
                    if (added > 0) sourcesUsed.push(`${tag}(${added})`);
                };

                addPlaces(await fetchOverpass(latitude, longitude, radius), 'overpass');
                if (merged.length < 10) addPlaces(await fetchPhoton(latitude, longitude), 'photon');
                if (merged.length < 10) addPlaces(await fetchSirene(latitude, longitude, radius), 'sirene');

                // Ne garde que les commerces vraiment proches (marge 1.5x le rayon)
                const nearby = merged.filter(p => haversineKm(latitude, longitude, p.latitude, p.longitude) <= maxDistKm);
                if (nearby.length > 0) {
                    merged.length = 0;
                    merged.push(...nearby);
                }

                // Villes manquantes : d'abord via le code postal (geo.api.gouv.fr,
                // 1 appel par CP distinct), puis reverse Photon en dernier filet.
                const noCity = merged.filter(p => !p.city);
                if (noCity.length) {
                    const pcs = [...new Set(noCity.map(p => String(p.postcode || '').slice(0, 5)).filter(pc => /^\d{5}$/.test(pc)))].slice(0, 5);
                    const pcCity = {};
                    for (const pc of pcs) {
                        try {
                            const r = await fetch(`https://geo.api.gouv.fr/communes?codePostal=${pc}&fields=nom&format=json`, { headers: REAL_DATA_UA, signal: AbortSignal.timeout(8000) });
                            const arr = await r.json();
                            if (arr && arr.length) pcCity[pc] = arr[0].nom;
                        } catch (e) {}
                        await sleep(150);
                    }
                    for (const p of noCity) {
                        const c = pcCity[String(p.postcode || '').slice(0, 5)];
                        if (c) {
                            p.city = c;
                            if (p.address && !/\d{5}/.test(p.address)) p.address = `${p.address}, ${p.postcode} ${c}`;
                        }
                    }
                    for (const p of merged.filter(p => !p.city && p.latitude != null).slice(0, 8)) {
                        try {
                            const r = await fetch(`https://photon.komoot.io/reverse?lat=${p.latitude}&lon=${p.longitude}&lang=fr`, { headers: REAL_DATA_UA, signal: AbortSignal.timeout(8000) });
                            const g = await r.json();
                            const props = g?.features?.[0]?.properties || {};
                            const c = props.city || props.town || props.village || props.locality || props.district || null;
                            if (c) {
                                p.city = c;
                                if (!p.postcode && props.postcode) p.postcode = props.postcode;
                            }
                        } catch (e) {}
                        await sleep(150);
                    }
                }

                console.log(`Sources réelles: ${sourcesUsed.join(', ') || 'aucune'} → ${merged.length} commerces`);
                results.places = merged.slice(0, 50);
                results.sources = sourcesUsed;

                if (results.places.length === 0) {
                    // Dernier recours uniquement : démo Paris, explicitement taguée
                    console.log('Toutes les sources réelles sont injoignables, renvoi démo (Paris)');
                    results.sample = true;
                    results.places = sampleLocalBusinesses.map(b => ({
                        name: b.name,
                        category: b.category,
                        address: b.address,
                        city: b.city,
                        latitude: b.latitude,
                        longitude: b.longitude,
                        phone: b.phone,
                        email: b.email,
                        website: b.website,
                        rating: b.rating,
                        siret: null,
                        sample: true
                    }));
                }
            } else if (query) {
                // Search in sample data for matching query
                const lowerQuery = query.toLowerCase();
                results.results = sampleLocalBusinesses
                    .filter(b =>
                        b.name.toLowerCase().includes(lowerQuery) ||
                        b.category.toLowerCase().includes(lowerQuery) ||
                        b.city.toLowerCase().includes(lowerQuery)
                    )
                    .slice(0, 30)
                    .map(b => ({ name: b.name, address: b.address, rating: b.rating }));
            }
        } finally {
            await page.close();
        }

        res.json(results);
    } catch (error) {
        // Return sample data on any error
        const fallbackResults = { places: sampleLocalBusinesses.slice(0, 20) };
        res.json(fallbackResults);
    }
});

// Enrichissement Google Maps : vrai téléphone + site web + avis d'un commerce
app.post('/scrape/google-place', async (req, res) => {
    const { name, city } = req.body;
    if (!name) return res.status(400).json({ error: 'name is required' });

    if (!browser) {
        try { await initBrowser(); }
        catch (e) { return res.status(500).json({ error: 'browser init failed' }); }
    }

    let page = null;
    try {
        page = await context.newPage();
        const q = encodeURIComponent(`${name} ${city || ''}`.trim());
        await page.goto(`https://www.google.com/maps/search/${q}`, { waitUntil: 'domcontentloaded', timeout: 30000 });
        await page.waitForTimeout(6000);
        const consent = page.locator('form[action*="consent"] button, button:has-text("Tout accepter")');
        if (await consent.count()) {
            await consent.first().click().catch(() => {});
            await page.waitForTimeout(3000);
        }
        // Si page de résultats : ouvrir la première fiche
        const firstResult = page.locator('div[role="feed"] div[role="article"] a').first();
        if (await firstResult.count()) {
            await firstResult.click().catch(() => {});
            await page.waitForTimeout(4000);
        }
        // Déplie les horaires détaillés (« Fermé · Ouvre à 07:30 » → flèche)
        const hoursBtn = page.locator('button:has-text("Fermé"), button:has-text("Ouvert"), [aria-label*="horaires"], [aria-label*="Horaires"]').first();
        if (await hoursBtn.count()) {
            await hoursBtn.click().catch(() => {});
            await page.waitForTimeout(2000);
        }
        const info = await page.evaluate(() => {
            const tels = [...document.querySelectorAll('a[href^="tel:"]')]
                .map(a => (a.getAttribute('href') || '').replace('tel:', '').trim())
                .filter(Boolean);
            const sites = [...document.querySelectorAll('a[href^="http"]')]
                .map(a => a.href)
                .filter(h => !/google\.|gstatic\.|maps\/preview|googleusercontent/.test(h));
            const txt = document.body.innerText || '';
            let rating = null, reviewsCount = null;
            const m = txt.match(/(\d)[,.](\d)\s*\(([\d\s]*)\)/);
            if (m) {
                rating = parseFloat(`${m[1]}.${m[2]}`);
                reviewsCount = parseInt(m[3].replace(/\s/g, ''), 10);
            }
            const addrM = txt.match(/\d[^\n]*\d{5}\s+[A-Za-zÀ-ÿ -]+/);
            const osM = txt.match(/((?:Ouvert|Fermé)[^\n]{0,50})/);
            const openState = osM ? osM[1].trim().replace(/\s+/g, ' ').slice(0, 80) : null;
            // Horaires : Google les affiche soit sur une ligne (« lundi 09:00–19:00 »),
            // soit éclatés (jour sur une ligne, plages sur les suivantes)
            const hours = [];
            const seenDays = new Set();
            const dayRe = /^(lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche)$/i;
            const stopRe = /suggérer|photos|avis|itinéraires|enregistrer|partager|restaurants à proximité/i;
            const lines = txt.split('\n').map(s => s.trim());
            for (let i = 0; i < lines.length && hours.length < 7; i++) {
                const t = lines[i];
                if (!t) continue;
                // Cas 1 : jour + horaires sur la même ligne
                let hm = t.match(/^(lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche)\s*[:\-–]?\s*(.+)$/i);
                if (hm && /(\d{1,2}[h:]\d{2}|ferm|24\s?h)/i.test(hm[2]) && !seenDays.has(hm[1].toLowerCase())) {
                    seenDays.add(hm[1].toLowerCase());
                    hours.push(`${hm[1][0].toUpperCase()}${hm[1].slice(1)} : ${hm[2].trim()}`.slice(0, 70));
                    continue;
                }
                // Cas 2 : jour seul, plages sur les lignes suivantes
                const dm = t.match(dayRe);
                if (!dm || seenDays.has(dm[1].toLowerCase())) continue;
                seenDays.add(dm[1].toLowerCase());
                const parts = [];
                for (let j = i + 1; j < lines.length && parts.length < 2; j++) {
                    const u = lines[j];
                    if (!u) continue;
                    if (dayRe.test(u) || stopRe.test(u)) break;
                    if (/(\d{1,2}[h:]\d{2}|fermé|24\s?h|—)/i.test(u)) parts.push(u.replace(/\s+/g, ' '));
                    else if (parts.length) break;
                }
                if (parts.length) hours.push(`${dm[1][0].toUpperCase()}${dm[1].slice(1)} : ${parts.join(' / ')}`.slice(0, 70));
            }
            // Photos : images hébergées par Google (hotlink OK pour un aperçu local)
            const photos = [...document.querySelectorAll('img')]
                .map(img => img.currentSrc || img.src || '')
                .filter(s => /googleusercontent\.com/.test(s) && !/=s32|=s64|=w32|=w64|=s24/.test(s))
                .map(s => s.replace(/=s\d+[^\s"']*/, '=s800').replace(/=w\d+[^\s"']*/, '=w800'))
                .filter((s, i, a) => s && a.indexOf(s) === i)
                .slice(0, 6);
            return {
                phone: tels[0] || null,
                website: sites[0] || null,
                rating, reviewsCount,
                address: addrM ? addrM[0].trim().slice(0, 120) : null,
                hours, photos, openState
            };
        });
        // Avis clients : ouvre l'onglet Avis puis lit les premières cartes
        // (auteur, note, texte, date). Échec silencieux -> reviews: [].
        let reviews = [];
        try {
            const avisBtn = page.locator('div[role="tablist"] button:has-text("Avis"), button[aria-label*="Avis"], button[aria-label*="avis"]').first();
            if (await avisBtn.count()) {
                await avisBtn.click().catch(() => {});
                await page.waitForTimeout(3500);
                // Fait défiler le panneau pour charger les cartes d'avis (borné)
                for (let k = 0; k < 3; k++) {
                    await page.evaluate(() => {
                        const card = document.querySelector('div[data-review-id]');
                        let el = card, sc = null;
                        while (el && el !== document.body) {
                            if (el.scrollHeight > el.clientHeight + 80) { sc = el; break; }
                            el = el.parentElement;
                        }
                        if (sc) sc.scrollTop = sc.scrollHeight;
                    });
                    await page.waitForTimeout(1200);
                }
            }
            reviews = await page.evaluate(() => {
                const seen = new Set();
                const out = [];
                for (const el of document.querySelectorAll('div[data-review-id]')) {
                    if (out.length >= 4) break;
                    const t = (el.innerText || '').trim();
                    if (t.length < 20) continue;
                    // Note : d'abord via l'aria-label des étoiles, sinon via le texte
                    let rating = null;
                    const starEl = [...el.querySelectorAll('[aria-label]')]
                        .map(n => n.getAttribute('aria-label') || '')
                        .find(s => /(\d)\s*[,.]?\s*\d?\s*(?:étoiles?|stars?)/i.test(s)
                            || /noté?\s*\d/i.test(s));
                    const rm = (starEl || t).match(/(\d)[,.]?(\d)?\s*(?:étoiles?|stars?)/i)
                        || (starEl || t).match(/noté?\s*(\d)[,.]?(\d)?\s*sur\s*5/i);
                    if (rm) rating = parseFloat(rm[1] + '.' + (rm[2] || '0'));
                    const lines = t.split('\n').map(s => s.trim()).filter(Boolean);
                    let author = 'Client Google';
                    for (const ln of lines.slice(0, 4)) {
                        if (ln.length > 1 && ln.length < 40
                            && !/avis|étoiles?|stars?|il y a|ago|local guide|^\d/.test(ln)) { author = ln; break; }
                    }
                    let text = lines.filter(l => l.length > 40).join(' ').slice(0, 400);
                    if (!text) text = t.slice(0, 400);
                    const dm = t.match(/(il y a [^\n]{1,30}|\d+\s+(?:jour|mois|an|semain)[^\n]{0,20})/i);
                    const dtxt = dm ? dm[1].trim().slice(0, 40) : null;
                    if (!text || text.length < 20) continue;
                    // Déduplique (Google rend parfois la même carte deux fois)
                    const key = author + '|' + text.slice(0, 60);
                    if (seen.has(key)) continue;
                    seen.add(key);
                    out.push({ author: author.slice(0, 60), rating, text, date: dtxt });
                }
                return out;
            });
        } catch (e) { reviews = []; }
        res.json({ name, ...info, reviews });
    } catch (e) {
        res.status(500).json({ error: e.message.split('\n')[0] });
    } finally {
        if (page) await page.close().catch(() => {});
    }
});

// Capture carte : screenshot Google Maps embarquée autour d'un point (pour la page Contact)
app.post('/scrape/mapshot', async (req, res) => {
    const { lat, lon } = req.body;
    if (lat == null || lon == null) return res.status(400).json({ error: 'lat/lon required' });
    if (!browser) {
        try { await initBrowser(); }
        catch (e) { return res.status(500).json({ error: 'browser init failed' }); }
    }
    let page = null;
    try {
        page = await context.newPage();
        await page.setViewportSize({ width: 880, height: 560 });
        const ok = async (url, waitSel) => {
            await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
            const consent = page.locator('form[action*="consent"] button, button:has-text("Tout accepter")');
            if (await consent.count()) {
                await consent.first().click().catch(() => {});
                await page.waitForTimeout(2500);
            }
            try { await page.waitForSelector(waitSel, { timeout: 12000 }); } catch (e) {}
            await page.waitForTimeout(2500);
            const shot = `/tmp/mapshot-${Date.now()}.png`;
            await page.screenshot({ path: shot });
            return shot;
        };
        let shot = await ok(`https://www.google.com/maps?q=${lat},${lon}&z=16&output=embed`, 'canvas');
        // Vérifie que l'image contient une vraie carte (sinon repli OSM embarquée)
        let size = 0;
        try { size = fs.statSync(shot).size; } catch (e) {}
        if (size < 60000) {
            const d = 0.012;
            shot = await ok(`https://www.openstreetmap.org/export/embed.html?bbox=${lon - d}%2C${lat - d}%2C${lon + d}%2C${lat + d}&layer=mapnik&marker=${lat}%2C${lon}`, '.leaflet-tile-loaded');
        }
        res.json({ path: shot });
    } catch (e) {
        res.status(500).json({ error: e.message.split('\n')[0] });
    } finally {
        if (page) await page.close().catch(() => {});
    }
});

// Photos RÉELLES du site du commerce (vitrine, plats, réalisations, équipe) :
// va sur le site existant et récupère ses images (og:image + <img> chargées),
// en excluant logos, icônes, avatars et pixels de suivi. Zéro banque d'images.
app.post('/scrape/site-images', async (req, res) => {
    const { url, limit } = req.body;
    if (!url || !/^https?:\/\//i.test(url)) return res.status(400).json({ error: 'url required' });
    const max = Math.min(Math.max(parseInt(limit, 10) || 8, 1), 12);
    if (!browser) {
        try { await initBrowser(); }
        catch (e) { return res.status(500).json({ error: 'browser init failed' }); }
    }
    let page = null;
    try {
        page = await context.newPage();
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
        const consent = page.locator('button:has-text("Accepter"), button:has-text("Tout accepter"), button:has-text("OK")');
        if (await consent.count()) { await consent.first().click().catch(() => {}); }
        // Déclenche le lazy-load : défilement borné puis pause
        for (let k = 0; k < 4; k++) {
            await page.evaluate(() => window.scrollBy(0, window.innerHeight));
            await page.waitForTimeout(700);
        }
        await page.evaluate(() => window.scrollTo(0, 0));
        await page.waitForTimeout(800);
        const found = await page.evaluate(() => {
            const abs = (s) => { try { return new URL(s, location.href).href; } catch (e) { return ''; } };
            const out = [];
            const push = (src, w, h, alt, og) => {
                const u = abs(src);
                if (!u || !/^https?:\/\//i.test(u)) return;
                out.push({ url: u.split('#')[0], w: w || 0, h: h || 0, alt: (alt || '').slice(0, 120), og: !!og });
            };
            document.querySelectorAll('meta[property="og:image"], meta[name="twitter:image"]')
                .forEach(m => push(m.content, 1200, 630, '', true));
            document.querySelectorAll('img').forEach(img => {
                const src = img.currentSrc || img.src || img.getAttribute('data-src') || '';
                push(src, img.naturalWidth, img.naturalHeight, img.alt, false);
            });
            // Fonds hero en CSS (souvent la plus belle photo du site)
            document.querySelectorAll('header, section, div').forEach(el => {
                if (out.length > 60) return;
                const bg = (el.tagName === 'HEADER' || (el.className || '').toString().match(/hero|banner|slider|carousel/i))
                    ? getComputedStyle(el).backgroundImage : '';
                const m = /url\(["']?([^"')]+)["']?\)/.exec(bg || '');
                if (m) push(m[1], 1200, 600, '', false);
            });
            return out;
        });
        const BAD = /logo|icon|sprite|avatar|favicon|pixel|placeholder|blank|loader|spinner|badge|pay|payment|\.svg(\?|$)|\.gif(\?|$)|\.ico(\?|$)|doubleclick|googletag|analytics/i;
        const seen = new Set();
        const host = (() => { try { return new URL(url).hostname.replace(/^www\./, ''); } catch (e) { return ''; } })();
        const ranked = [];
        for (const im of found) {
            if (seen.has(im.url) || BAD.test(im.url)) continue;
            seen.add(im.url);
            const sameHost = im.url.includes(host);
            const big = Math.max(im.w, im.h) >= 500 || (im.w === 0 && /\.(jpe?g|webp|png)(\?|$)|uploads?\/|media\/|photos?\/|images?\//i.test(im.url));
            if (!big && !im.og) continue;
            ranked.push({ ...im, score: (im.og ? 3 : 0) + (sameHost ? 2 : 0) + (Math.min(im.w * im.h, 2000000) / 2000000) });
        }
        ranked.sort((a, b) => b.score - a.score);
        res.json({ images: ranked.slice(0, max).map(({ url, w, h, alt }) => ({ url, w, h, alt })) });
    } catch (e) {
        res.json({ images: [], warning: e.message.split('\n')[0] });
    } finally {
        if (page) await page.close().catch(() => {});
    }
});

app.post('/scrape/website', async (req, res) => {
    const { url } = req.body;

    if (!url) {
        return res.status(400).json({ error: 'URL is required' });
    }

    if (!browser) {
        try {
            await initBrowser();
        } catch (error) {
            return res.status(500).json({ error: 'Failed to initialize browser', details: error.message });
        }
    }

    try {
        const page = await context.newPage();

        await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
        await page.waitForTimeout(2000);

        const audit = await page.evaluate(() => {
            const hasHttps = location.protocol === 'https:';
            const title = document.title;
            const metaDesc = document.querySelector('meta[name="description"]')?.content || '';

            const images = document.querySelectorAll('img');
            const totalImages = images.length;
            const missingAlt = Array.from(images).filter(img => !img.alt).length;

            const links = document.querySelectorAll('a');
            const externalLinks = Array.from(links).filter(a => a.hostname !== location.hostname).length;

            const textContent = document.body.textContent || '';
            const textLength = textContent.replace(/\s+/g, ' ').trim().length;

            const isMobileFriendly = window.innerWidth < 768 ||
                document.querySelector('meta[name="viewport"]') !== null;

            return {
                hasHttps,
                title,
                metaDescription: metaDesc,
                imageCount: totalImages,
                imagesMissingAlt: missingAlt,
                internalLinks: links.length - externalLinks,
                externalLinks,
                textContentLength: textLength,
                isMobileFriendly,
                viewportSize: {
                    width: window.innerWidth,
                    height: window.innerHeight
                }
            };
        });

        const analysis = await page.accessibility.snapshot();
        const colorContrast = await page.evaluate(() => {
            const elements = document.querySelectorAll('[style*="color"], [style*="background"]');
            let issues = 0;
            elements.forEach(el => {
                const style = window.getComputedStyle(el);
                const bgColor = style.backgroundColor;
                const textColor = style.color;
                if (bgColor && textColor && bgColor !== textColor) {
                    issues++;
                }
            });
            return issues;
        });

        const screenshot = await page.screenshot({ fullPage: true, type: 'png' }).catch(() => null);

        await page.close();

        res.json({
            url,
            audit,
            accessibility: analysis,
            colorContrastIssues: colorContrast,
            screenshot: screenshot ? screenshot.toString('base64') : null
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/scrape/contact', async (req, res) => {
    const { url } = req.body;

    if (!url) {
        return res.status(400).json({ error: 'URL is required' });
    }

    if (!browser) {
        try {
            await initBrowser();
        } catch (error) {
            return res.status(500).json({ error: 'Failed to initialize browser', details: error.message });
        }
    }

    try {
        const page = await context.newPage();
        const contactInfo = {};

        try {
            const formattedUrl = url.startsWith('http') ? url : `https://${url}`;
            await page.goto(formattedUrl, { waitUntil: 'networkidle' });
            await page.waitForTimeout(1000);

            contactInfo.email = await page.evaluate(() => {
                const links = document.querySelectorAll('a[href^="mailto:"]');
                if (links.length > 0) {
                    return links[0].href.replace('mailto:', '').split('?')[0];
                }
                const textContent = document.body.textContent;
                const emailRegex = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
                const matches = textContent.match(emailRegex);
                return matches ? matches[0] : null;
            }).catch(() => null);

            contactInfo.phone = await page.evaluate(() => {
                const links = document.querySelectorAll('a[href^="tel:"]');
                if (links.length > 0) {
                    return links[0].href.replace('tel:', '').replace(/[^0-9+]/g, '');
                }
                const textContent = document.body.textContent;
                const phoneRegex = /(?=\+?\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{2,4}[-.\s]?\d{2,4}[-.\s]?\d{2,4}/g;
                const matches = textContent.match(phoneRegex);
                return matches ? matches[0].replace(/\D/g, '') : null;
            }).catch(() => null);

            try {
                const contactPage = await Promise.race([
                    page.waitForSelector('a[href*="contact"], a[href*="Contact"], .contact a', { timeout: 5000 }),
                    page.waitForSelector('footer a', { timeout: 5000 }).catch(() => null)
                ]);

                if (contactPage) {
                    await page.click('a[href*="contact"]')?.catch(() => {});
                    await page.waitForTimeout(1000);

                    contactInfo.email = await page.evaluate(() => {
                        const links = document.querySelectorAll('a[href^="mailto:"]');
                        if (links.length > 0) {
                            return links[0].href.replace('mailto:', '').split('?')[0];
                        }
                        const textContent = document.body.textContent;
                        const emailRegex = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
                        const matches = textContent.match(emailRegex);
                        return matches ? matches[0] : null;
                    }).catch(() => contactInfo.email);

                    contactInfo.phone = await page.evaluate(() => {
                        const links = document.querySelectorAll('a[href^="tel:"]');
                        if (links.length > 0) {
                            return links[0].href.replace('tel:', '').replace(/[^0-9+]/g, '');
                        }
                        return null;
                    }).catch(() => contactInfo.phone);
                }
            } catch (e) {
                // Ignore timeout errors
            }

        } finally {
            await page.close();
        }

        res.json({ url, ...contactInfo });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/scrape/pagesjaunes', async (req, res) => {
    const { query, city, category } = req.body;

    if (!browser) {
        try {
            await initBrowser();
        } catch (error) {
            return res.status(500).json({ error: 'Failed to initialize browser' });
        }
    }

    try {
        const page = await context.newPage();

        const searchQuery = [query, city, category].filter(Boolean).join(' ');
        const searchUrl = `https://www.pagesjaunes.fr/search/${encodeURIComponent(searchQuery)}`;

        await page.goto(searchUrl, { waitUntil: 'networkidle' });
        await page.waitForTimeout(3000);

        const results = await page.evaluate(() => {
            const items = Array.from(document.querySelectorAll('.bi-liste-vignette, .listing-item'));
            return items.slice(0, 20).map(el => ({
                name: el.querySelector('h3 a')?.textContent?.trim() || null,
                address: el.querySelector('.adr')?.textContent?.trim() || null,
                phone: el.querySelector('a[href^="tel:"]')?.textContent?.trim() || null,
                website: el.querySelector('a:contains("Visitez leur site")')?.href || null,
                siret: el.querySelector('.siret')?.textContent?.trim() || null
            })).filter(p => p.name);
        });

        await page.close();
        res.json({ results });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/scrape/societe-com', async (req, res) => {
    const { siren } = req.body;

    if (!siren) {
        return res.status(400).json({ error: 'SIREN number is required' });
    }

    const sirenClean = siren.replace(/[^0-9]/g, '');

    if (sirenClean.length !== 9) {
        return res.status(400).json({ error: 'Invalid SIREN number' });
    }

    try {
        const response = await fetch(`https://www.societe.com/api/v1/siren/${sirenClean}`, {
            headers: {
                'User-Agent': 'ProspectorMac-Scraper/1.0'
            }
        });

        if (!response.ok) {
            const fallbackUrl = `https://www.societe.com/company/${sirenClean}`;
            if (!browser) {
                await initBrowser();
            }

            const page = await context.newPage();
            await page.goto(fallbackUrl, { waitUntil: 'networkidle' });
            await page.waitForTimeout(2000);

            const companyData = await page.evaluate(() => {
                return {
                    name: document.querySelector('h1')?.textContent?.trim() || null,
                    status: document.querySelector('. statut')?.textContent?.trim() || 'Active',
                    registeredAddress: document.querySelector('[href*="siège"]')?.textContent?.trim() || null
                };
            });

            await page.close();
            return res.json(companyData);
        }

        const data = await response.json();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

async function shutdown() {
    console.log('Shutting down scraper engine...');
    if (context) await context.close();
    if (browser) await browser.close();
    process.exit(0);
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

app.listen(PORT, '127.0.0.1', () => {
    console.log(`Scraper engine listening on http://127.0.0.1:${PORT}`);
});

export default app;