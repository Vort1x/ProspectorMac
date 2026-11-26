import express from 'express';
import { chromium } from 'playwright';

const app = express();
const PORT = 31417;

app.use(express.json());

let browser;

async function startTestServer() {
    console.log('Starting test scraper server...');

    browser = await chromium.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    app.get('/health', (req, res) => {
        res.json({ status: 'ok', service: 'scraper-test' });
    });

    app.post('/test-connection', async (req, res) => {
        try {
            const page = await browser.newPage();
            await page.goto('https://example.com', { waitUntil: 'networkidle' });
            await page.waitForTimeout(1000);

            const title = await page.title();
            await page.close();

            res.json({ success: true, title, message: 'Playwright connection successful' });
        } catch (error) {
            res.status(500).json({ success: false, error: error.message });
        }
    });

    app.listen(PORT, '127.0.0.1', () => {
        console.log(`Test scraper server running on http://127.0.0.1:${PORT}`);
    });
}

startTestServer().catch(console.error);