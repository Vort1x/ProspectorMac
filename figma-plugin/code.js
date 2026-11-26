// Figma Plugin: ProspectorMaquetteGenerator
// Reads JSON from ProspectorMac app and generates professional website mockups

let pluginData = null;

const COLORS = {
    primary: { dark: '#1a1a2e', light: '#0f3460' },
    secondary: { dark: '#e94560', light: '#c4374a' },
    background: { dark: '#16213e', light: '#fefefe' },
    surface: { dark: '#1a1a2e', light: '#ffffff' },
    text: { dark: '#f5f5f5', light: '#333333' },
    textSecondary: { dark: '#aaa', light: '#666666' },
    accent: { dark: '#0f3460', light: '#e94560' },
    success: { dark: '#4ade80', light: '#22c55e' },
    border: { dark: '#333', light: '#e0e0e0' }
};

async function importJsonData() {
    const data = await window.parent.postMessage({ pluginMessage: { pluginName: 'get-maquette-data' } }, '*');
    return data;
}

function getThemeColors() {
    const isDark = figma.currentPage.name.toLowerCase().includes('dark') ||
                   window.matchMedia('(prefers-color-scheme: dark)').matches;
    return {
        primary: isDark ? COLORS.primary.dark : COLORS.primary.light,
        secondary: isDark ? COLORS.secondary.dark : COLORS.secondary.light,
        background: isDark ? COLORS.background.dark : COLORS.background.light,
        surface: isDark ? COLORS.surface.dark : COLORS.surface.light,
        text: isDark ? COLORS.text.dark : COLORS.text.light,
        textSecondary: isDark ? COLORS.textSecondary.dark : COLORS.textSecondary.light,
        accent: isDark ? COLORS.accent.dark : COLORS.accent.light,
        success: isDark ? COLORS.success.dark : COLORS.success.light,
        border: isDark ? COLORS.border.dark : COLORS.border.light
    };
}

async function createHeroSection(metrics, colors) {
    const frame = figma.createFrame();
    frame.name = 'Hero';
    frame.resize(metrics.width, 200);
    frame.fills = [figma.makeSolidPaintPaint(colors.background)];
    frame.paddingTop = 40;
    frame.paddingRight = 80;
    frame.paddingBottom = 40;
    frame.paddingLeft = 80;
    frame.itemSpacing = 16;
    frame.primaryAxisSizingMode = 'AUTO';

    const logo = figma.createText();
    logo.characters = metrics.businessName || 'Nom de l\'entreprise';
    logo.fontSize = 28;
    logo fontWeight = 700;
    logo.fills = [figma.makeSolidPaintPaint(colors.text)];
    logo.textAutoResize = 'HEIGHT';

    const subtitle = figma.createText();
    subtitle.characters = metrics.tagline || 'Slogan ou description courte';
    subtitle.fontSize = 16;
    subtitle.fills = [figma.makeSolidPaintPaint(colors.textSecondary)];
    subtitle.textAutoResize = 'HEIGHT';

    frame.appendChild(logo);
    frame.appendChild(subtitle);

    return frame;
}

async function createNavigation(metrics, colors) {
    const frame = figma.createFrame();
    frame.name = 'Navigation';
    frame.resize(metrics.width, 60);
    frame.fills = [figma.makeSolidPaintPaint(colors.surface)];
    frame.strokeWeight = 1;
    frame.strokes = [figma.makeSolidPaintPaint(colors.border)];
    frame.paddingTop = 12;
    frame.paddingRight = 40;
    frame.paddingBottom = 12;
    frame.paddingLeft = 40;
    frame.itemSpacing = 32;

    const navItems = [
        metrics.ctaButton?.text || 'Accueil',
        metrics.services?.length > 0 ? 'Services' : 'Services',
        metrics.features?.length > 0 ? 'Fonctionnalités' : 'Solutions',
        'Avis',
        'Contact'
    ];

    const logos = [];
    for (const item of navItems) {
        const text = figma.createText();
        text.characters = item;
        text.fontSize = 14;
        text.fontName = { family: 'Inter', style: 'Medium' };
        text.fills = [figma.makeSolidPaintPaint(colors.text)];
        text.textAutoResize = 'HEIGHT';
        text.characters = item;
        logos.push(text);
    }

    for (const logo of logos) {
        frame.appendChild(logo);
    }

    return frame;
}

async function createCTAButtons(metrics, colors) {
    const frame = figma.createFrame();
    frame.name = 'CTA Buttons';
    frame.resize(320, 60);
    frame.fills = [figma.makeSolidPaintPaint(colors.accent)];
    frame.cornerRadius = 8;

    const ctaText = metrics.ctaButton?.text || 'Réserver une consultation';
    const text = figma.createText();
    text.characters = ctaText;
    text.fontSize = 16;
    text.fontWeight = 600;
    text.fills = [figma.makeSolidPaintPaint(colors.background)];
    text.textAutoResize = 'HEIGHT';
    frame.appendChild(text);

    return frame;
}

async function createImagePlaceholder(width, height, colors) {
    const frame = figma.createFrame();
    frame.name = 'Image Placeholder';
    frame.resize(width, height);
    frame.fills = [figma.makeSolidPaintPaint(colors.surface)];
    frame.strokeWeight = 1;
    frame.strokes = [figma.makeSolidPaintPaint(colors.border)];
    frame.cornerRadius = 4;

    return frame;
}

async function createServiceCard(service, index, total, colors, isDark) {
    const card = figma.createFrame();
    card.name = service.title || `Service ${index + 1}`;
    card.resize(280, 200);
    card.fills = [figma.makeSolidPaintPaint(colors.surface)];
    card.strokeWeight = 1;
    card.strokes = [figma.makeSolidPaintPaint(colors.border)];
    card.cornerRadius = 8;
    card.counterAxisRotate = (index % 4) * 15;

    card.paddingTop = 24;
    card.paddingRight = 20;
    card.paddingBottom = 24;
    card.paddingLeft = 20;
    card.itemSpacing = 12;

    const iconContainer = figma.createEllipse();
    iconContainer.resize(60, 60);
    iconContainer.fills = [figma.makeSolidPaintPaint(colors.background)];
    iconContainer.strokes = [figma.makeSolidPaintPaint(colors.accent)];
    iconContainer.strokeWeight = 2;

    const title = figma.createText();
    title.characters = service.title || 'Service';
    title.fontSize = 18;
    title.fontWeight = 600;
    title.fills = [figma.makeSolidPaintPaint(colors.text)];

    const description = figma.createText();
    description.characters = service.description || 'Description du service';
    description.fontSize = 14;
    description.fills = [figma.makeSolidPaintPaint(colors.textSecondary)];
    description.lineHeight = { value: 20, unit: 'PIXELS' };

    card.appendChild(iconContainer);
    card.appendChild(title);
    card.appendChild(description);

    return card;
}

async function createFeatureCard(feature, index, total, colors) {
    const card = figma.createFrame();
    card.name = feature.title || `Fonctionnalité ${index + 1}`;
    card.resize(280, 180);
    card.fills = [figma.makeSolidPaintPaint(colors.background)];
    card.strokeWeight = 1;
    card.strokes = [figma.makeSolidPaintPaint(colors.border)];
    card.cornerRadius = 8;

    card.paddingTop = 20;
    card.paddingRight = 16;
    card.paddingBottom = 20;
    card.paddingLeft = 16;
    card.itemSpacing = 12;

    const icon = figma.createEllipse();
    icon.resize(48, 48);
    icon.fills = [figma.makeSolidPaintPaint(colors.accent)];

    const title = figma.createText();
    title.characters = feature.title || 'Titre';
    title.fontSize = 16;
    title.fontWeight = 600;
    title.fills = [figma.makeSolidPaintPaint(colors.text)];

    const description = figma.createText();
    description.characters = feature.description || 'Description';
    description.fontSize = 13;
    description.fills = [figma.makeSolidPaintPaint(colors.textSecondary)];
    description.lineHeight = { value: 18, unit: 'PIXELS' };

    card.appendChild(icon);
    card.appendChild(title);
    card.appendChild(description);

    return card;
}

async function createRatingSection(ratings, colors) {
    const frame = figma.createFrame();
    frame.name = 'Client Ratings';
    frame.resize(800, 180);
    frame.fills = [figma.makeSolidPaintPaint(colors.surface)];
    frame.strokeWeight = 1;
    frame.strokes = [figma.makeSolidPaintPaint(colors.border)];
    frame.cornerRadius = 8;
    frame.itemSpacing = 24;

    if (ratings && ratings.length > 0) {
        const avgRating = ratings.reduce((sum, r) => sum + (r.rating || 0), 0) / ratings.length;

        const avgText = figma.createText();
        avgText.characters = `Note moyenne: ${avgRating.toFixed(1)}/5`;
        avgText.fontSize = 24;
        avgText.fontWeight = 700;
        avgText.fills = [figma.makeSolidPaintPaint(colors.text)];

        frame.appendChild(avgText);

        for (const rating of ratings.slice(0, 3)) {
            const ratingFrame = figma.createFrame();
            ratingFrame.resize(200, 100);
            ratingFrame.fills = [figma.makeSolidPaintPaint(colors.background)];
            ratingFrame.layoutMode = 'VERTICAL';
            ratingFrame.itemSpacing = 4;

            const clientName = figma.createText();
            clientName.characters = rating.client || 'Client';
            clientName.fontSize = 14;
            clientName.fontWeight = 600;
            clientName.fills = [figma.makeSolidPaintPaint(colors.text)];

            const review = figma.createText();
            review.characters = rating.review || 'Avis client';
            review.fontSize = 12;
            review.fills = [figma.makeSolidPaintPaint(colors.textSecondary)];
            review.lineHeight = { value: 14, unit: 'PIXELS' };

            ratingFrame.appendChild(clientName);
            ratingFrame.appendChild(review);
            frame.appendChild(ratingFrame);
        }
    } else {
        const noRatings = figma.createText();
        noRatings.characters = 'Aucun avis client disponible';
        noRatings.fontSize = 14;
        noRatings.fills = [figma.makeSolidPaintPaint(colors.textSecondary)];
        frame.appendChild(noRatings);
    }

    return frame;
}

async function createContactSection(businessInfo, colors) {
    const frame = figma.createFrame();
    frame.name = 'Contact';
    frame.resize(800, 200);
    frame.fills = [figma.makeSolidPaintPaint(colors.surface)];
    frame.cornerRadius = 8;
    frame.strokeWeight = 1;
    frame.strokes = [figma.makeSolidPaintPaint(colors.border)];
    frame.paddingTop = 24;
    frame.paddingRight = 32;
    frame.paddingBottom = 24;
    frame.paddingLeft = 32;

    const title = figma.createText();
    title.characters = 'Contactez-nous';
    title.fontSize = 24;
    title.fontWeight = 700;
    title.fills = [figma.makeSolidPaintPaint(colors.text)];

    const contactInfo = figma.createText();
    contactInfo.characters = `${businessInfo.address || 'Adresse non renseignée'}\n${businessInfo.phone || ''} | ${businessInfo.email || ''}`;
    contactInfo.fontSize = 14;
    contactInfo.fills = [figma.makeSolidPaintPaint(colors.textSecondary)];
    contactInfo.lineHeight = { value: 20, unit: 'PIXELS' };

    frame.appendChild(title);
    frame.appendChild(contactInfo);

    return frame;
}

async function createFooter(colors) {
    const frame = figma.createFrame();
    frame.name = 'Footer';
    frame.resize(800, 80);
    frame.fills = [figma.makeSolidPaintPaint(colors.background)];
    frame.strokeWeight = 1;
    frame.strokes = [figma.makeSolidPaintPaint(colors.border)];
    frame.paddingTop = 16;
    frame.paddingRight = 40;
    frame.paddingBottom = 16;
    frame.paddingLeft = 40;

    const copyright = figma.createText();
    copyright.characters = `© ${new Date().getFullYear()} ProspectorMac - Tous droits réservés`;
    copyright.fontSize = 12;
    copyright.fills = [figma.makeSolidPaintPaint(colors.textSecondary)];

    frame.appendChild(copyright);

    return frame;
}

async function generateMockup(maquetteData) {
    const colors = getThemeColors();
    const isDark = !window.matchMedia('(prefers-color-scheme: light)').matches;

    const pageWidth = 800;
    const mainFrame = figma.createFrame();
    mainFrame.name = 'ProspectorMockup';
    mainFrame.resize(pageWidth, 1000);
    mainFrame.fills = [figma.makeSolidPaintPaint(colors.background)];
    mainFrame.layoutMode = 'VERTICAL';
    mainFrame.paddingTop = 0;
    mainFrame.paddingRight = 0;
    main.frame.paddingBottom = 0;
    mainFrame.paddingLeft = 0;
    mainFrame.itemSpacing = 0;

    const businessInfo = maquetteData.businessInfo || {};
    businessInfo.businessName = businessInfo.name || 'Entreprise';

    if (maquetteData.hero) {
        const hero = await createHeroSection(maquetteData.hero, colors);
        hero.resize(pageWidth, 200);
        mainFrame.appendChild(hero);
    }

    if (maquetteData.navigation !== false) {
        const nav = await createNavigation({ ctaButton: maquetteData.ctaButton }, colors);
        nav.resize(pageWidth, 60);
        mainFrame.appendChild(nav);
    }

    if (maquetteData.sections?.hero) {
        const cta = await createCTAButtons(maquetteData.hero || {}, colors);
        cta.resize(320, 60);
        cta.x = 240;
        cta.y = 280;
        mainFrame.appendChild(cta);
    }

    if (maquetteData.sections?.services && maquetteData.sections.services.length > 0) {
        const servicesFrame = figma.createFrame();
        servicesFrame.name = 'Services Section';
        servicesFrame.resize(pageWidth, 300);
        servicesFrame.fills = [figma.makeSolidPaintPaint(colors.background)];
        servicesFrame.paddingTop = 40;
        servicesFrame.paddingRight = 40;
        servicesFrame.paddingBottom = 40;
        servicesFrame.paddingLeft = 40;
        servicesFrame.layoutMode = 'HORIZONTAL';
        servicesFrame.itemSpacing = 24;
        servicesFrame.primaryAxisSizingMode = 'AUTO';

        for (let i = 0; i < Math.min(maquetteData.sections.services.length, 4); i++) {
            const serviceCard = await createServiceCard(
                maquetteData.sections.services[i],
                i,
                maquetteData.sections.services.length,
                colors,
                isDark
            );
            servicesFrame.appendChild(serviceCard);
        }

        mainFrame.appendChild(servicesFrame);
    }

    if (maquetteData.sections?.features && maquetteData.sections.features.length > 0) {
        const featuresFrame = figma.createFrame();
        featuresFrame.name = 'Features Section';
        featuresFrame.resize(pageWidth, 400);
        featuresFrame.fills = [figma.makeSolidPaintPaint(colors.surface)];
        featuresFrame.paddingTop = 60;
        featuresFrame.paddingRight = 40;
        featuresFrame.paddingBottom = 60;
        featuresFrame.paddingLeft = 40;
        featuresFrame.layoutMode = 'HORIZONTAL';
        featuresFrame.itemSpacing = 32;
        featuresFrame.primaryAxisSizingMode = 'AUTO';

        for (let i = 0; i < Math.min(maquetteData.sections.features.length, 3); i++) {
            const featureCard = await createFeatureCard(
                maquetteData.sections.features[i],
                i,
                maquetteData.sections.features.length,
                colors
            );
            featuresFrame.appendChild(featureCard);
        }

        mainFrame.appendChild(featuresFrame);
    }

    if (maquetteData.sections?.googleReviews) {
        const reviews = await createRatingSection(maquetteData.sections.googleReviews.reviews, colors);
        reviews.resize(pageWidth - 80, 180);
        mainFrame.appendChild(reviews);
    }

    if (maquetteData.sections?.hours) {
        const hoursFrame = figma.createFrame();
        hoursFrame.name = 'Hours Section';
        hoursFrame.resize(pageWidth, 120);
        hoursFrame.fills = [figma.makeSolidPaintPaint(colors.background)];
        hoursFrame.paddingTop = 24;
        hoursFrame.paddingRight = 40;
        hoursFrame.paddingBottom = 24;
        hoursFrame.paddingLeft = 40;
        hoursFrame.itemSpacing = 40;

        const hoursTitle = figma.createText();
        hoursTitle.characters = 'Horaires d\'ouverture';
        hoursTitle.fontSize = 18;
        hoursTitle.fontWeight = 600;
        hoursTitle.fills = [figma.makeSolidPaintPaint(colors.text)];

        const hoursText = figma.createText();
        const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
        const hoursLines = days.map(day => {
            const schedule = maquetteData.sections.hours[day.toLowerCase()] || 'Fermé';
            return `${day} : ${schedule}`;
        }).join('\n');

        hoursText.characters = hoursLines;
        hoursText.fontSize = 14;
        hoursText.fills = [figma.makeSolidPaintPaint(colors.textSecondary)];
        hoursText.lineHeight = { value: 20, unit: 'PIXELS' };

        hoursFrame.appendChild(hoursTitle);
        hoursFrame.appendChild(hoursText);
        mainFrame.appendChild(hoursFrame);
    }

    if (maquetteData.sections?.contact) {
        const contact = await createContactSection(businessInfo, colors);
        contact.resize(pageWidth - 80, 120);
        mainFrame.appendChild(contact);
    }

    const footer = await createFooter(colors);
    footer.resize(pageWidth - 80, 80);
    mainFrame.appendChild(footer);

    mainFrame.x = -pageWidth / 2;
    mainFrame.y = -1000 / 2;

    figma.viewport.resize(pageWidth, 1000);

    return mainFrame;
}

async function main() {
    figma.showUI(__html__, { width: 320, height: 400 });

    try {
        const maquetteData = await figma.clientStorage.getAsync('maquetteData') ||
                             plugin.pluginData ||
                             JSON.parse(localStorage.getItem('prospector-maquette-data') || '{}');

        if (!maquetteData || Object.keys(maquetteData).length === 0) {
            figma.notify('Aucune donnée de maquette disponible. Importez d\'abord depuis ProspectorMac.', { timeout: 5000 });
            return;
        }

        figma.notify('Génération de la maquette en cours...', { timeout: 3000 });

        const mockup = await generateMockup(maquetteData);
        figma.currentPage.appendChild(mockup);

        figma.notify('Maquette générée avec succès!', { timeout: 3000 });

        figma.viewport.postAnnotation('zoomTo', {
            node: mockup,
            zoomLevel: 'fit'
        });

    } catch (error) {
        console.error('Error generating mockup:', error);
        figma.notify(`Erreur: ${error.message}`, { timeout: 5000 });
    }
}

main();