const CONNECTOR_WORDS = new Set([
    'dan', 'yang', 'untuk', 'dengan', 'adalah', 'dapat', 'pada', 'atau',
    'ini', 'dari', 'akan', 'tidak', 'dalam', 'sebagai', 'juga', 'oleh',
    'karena', 'sehingga', 'serta', 'bila', 'jika', 'maka', 'setelah',
    'sebelum', 'baik', 'seperti', 'yaitu',
]);

const CLINICAL_UNITS = /\b(mmHg|mg\/dL|g\/dL|kg\/m2|mmol\/L|mEq\/L|mL|IU|kkal|kal|mg|kg)\b/i;

const WINDOW_SIZE = 12;
// fix (kalibrasi): 0.3 dipilih dari analisis distribusi coverage di seluruh
// knowledge base -- chunk prosa normal yang cuma sesekali menyebut nilai
// klinis biasanya coverage-nya <0.05 (window individual, bukan blok besar);
// tabel yang genuinely jumble biasanya coverage-nya >0.5. 0.3 adalah titik
// potong aman di antara keduanya.
const JUMBLE_COVERAGE_THRESHOLD = 0.3;

function looksLikeClinicalShorthand(word) {
    const w = word.replace(/[.,;:()<>]/g, '');
    if (!w) return false;
    return /^[A-Z][a-z]+$/.test(w) ||   // Title Case: Labetalol, Nitrogliserin
        /^[A-Z]{2,6}$/.test(w) ||     // ALL CAPS singkatan: SKA, TDS, MAP
        /^\d/.test(w);                // mulai dengan angka: 140, 20-25%
}

/**
 * Deteksi window-window yang "jumble" (bukan prosa) dalam sebuah teks.
 * Return array of word-index (posisi awal window) yang ter-flag.
 */
function findJumbleWindows(words, windowSize = WINDOW_SIZE) {
    const hits = [];
    for (let i = 0; i <= words.length - windowSize; i++) {
        const window = words.slice(i, i + windowSize);
        const windowText = window.join(' ');
        const nConnectors = window.filter(w =>
            CONNECTOR_WORDS.has(w.toLowerCase().replace(/[.,;:()]/g, ''))
        ).length;
        const nShorthand = window.filter(looksLikeClinicalShorthand).length;
        const shorthandRatio = nShorthand / windowSize;
        const hasUnit = CLINICAL_UNITS.test(windowText);
        const hasComparison = /[<>≤≥]\s*\d/.test(windowText) || /\d+\s*-\s*\d+\s*%/.test(windowText);

        const isExtremeDensity = nConnectors === 0 && shorthandRatio >= 0.75;
        const isModerateDensityWithSignal = nConnectors === 0 && shorthandRatio >= 0.5 && (hasUnit || hasComparison);

        if (isExtremeDensity || isModerateDensityWithSignal) {
            hits.push(i);
        }
    }
    return hits;
}

/**
 * Gabungkan window-window yang ter-flag jadi blok kontinu (dengan sedikit
 * toleransi jarak), lalu hitung coverage tiap blok. Return array of
 * {startWord, endWord, coverage}.
 */
function groupIntoBlocks(hits, totalWords, windowSize = WINDOW_SIZE, gapTolerance = 6) {
    if (hits.length === 0) return [];
    const blocks = [];
    let blockStart = hits[0];
    let blockEnd = hits[0] + windowSize;
    let hitCountInBlock = 1;

    for (let i = 1; i < hits.length; i++) {
        if (hits[i] - blockEnd <= gapTolerance) {
            blockEnd = hits[i] + windowSize;
            hitCountInBlock++;
        } else {
            blocks.push({ startWord: blockStart, endWord: blockEnd, hitCount: hitCountInBlock });
            blockStart = hits[i];
            blockEnd = hits[i] + windowSize;
            hitCountInBlock = 1;
        }
    }
    blocks.push({ startWord: blockStart, endWord: blockEnd, hitCount: hitCountInBlock });

    return blocks.map(b => ({
        ...b,
        coverage: b.hitCount / Math.max(1, (b.endWord - b.startWord) - windowSize + 1),
    }));
}

/**
 * Minta Gemini menulis ulang satu blok teks jumble jadi kalimat naratif,
 * TANPA menambah/menghilangkan informasi faktual.
 */
async function narrateJumbleWithLLM(jumbleText, getKeyFn, model = 'gemini-3-flash-preview', maxRetries = 5) {
    const prompt = `Teks berikut adalah data tabel klinis yang kehilangan struktur kolomnya saat diekstrak dari PDF (kolom-kolomnya sudah tergabung jadi satu baris tanpa pemisah). Tulis ulang jadi kalimat naratif Bahasa Indonesia yang jelas dan mudah dibaca.

ATURAN WAJIB:
1. JANGAN tambahkan informasi/angka/nama obat yang tidak ada di teks asli.
2. JANGAN hilangkan satupun angka, nama obat, atau target klinis yang ada.
3. Kelompokkan berdasarkan konteks logis (misal: kondisi klinis dengan target dan obat yang sesuai) semampu yang bisa disimpulkan dari urutan teks.
4. Kalau tidak yakin bagaimana mengelompokkan sebagian data, tetap sertakan semua istilahnya secara berurutan dalam kalimat, jangan dihilangkan.
5. Output HANYA teks naratif hasil tulis ulang, tanpa komentar/penjelasan tambahan.

Teks asli:
"""
${jumbleText}
"""

Hasil tulis ulang:`;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        const apiKey = typeof getKeyFn === 'function' ? getKeyFn() : getKeyFn;
        try {
            const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
            const response = await fetch(url, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contents: [{ parts: [{ text: prompt }] }],
                    generationConfig: { temperature: 0, maxOutputTokens: 1024 },
                }),
            });

            if (response.ok) {
                const result = await response.json();
                const rewritten = result?.candidates?.[0]?.content?.parts?.[0]?.text;
                if (rewritten && rewritten.trim().length > jumbleText.length * 0.5) {
                    return rewritten.trim();
                }
                return jumbleText;
            }

            if (response.status === 429) {
                await new Promise(r => setTimeout(r, 1000 * attempt));
                continue;
            }

            console.warn(`   ⚠️ narrateJumbleWithLLM: API error ${response.status}, pakai teks asli`);
            return jumbleText;
        } catch (e) {
            if (attempt === maxRetries) {
                console.warn(`   ⚠️ narrateJumbleWithLLM: exception (${e.message}), pakai teks asli`);
                return jumbleText;
            }
            await new Promise(r => setTimeout(r, 1000 * attempt));
        }
    }
    return jumbleText;
}

/**
 * Fungsi utama: scan teks penuh (SEBELUM chunking), temukan blok jumble
 * dengan coverage tinggi, kirim ke LLM buat ditulis ulang, lalu susun
 * ulang teksnya. Blok dengan coverage rendah (kemungkinan besar cuma
 * prosa yang sesekali menyebut nilai klinis) DIBIARKAN APA ADANYA.
 *
 * @param {string} text - Teks penuh dokumen (setelah preprocessText + narrateTablesInText)
 * @param {string} apiKey - Gemini API key
 * @returns {Promise<string>} Teks dengan blok jumble sudah dinarasikan
 */
async function detectAndNarrateJumble(text, apiKey) {
    const words = text.split(/\s+/);
    const hits = findJumbleWindows(words);
    const blocks = groupIntoBlocks(hits, words.length)
        .filter(b => b.coverage >= JUMBLE_COVERAGE_THRESHOLD);

    if (blocks.length === 0) return text;

    console.log(`   🔍 Ditemukan ${blocks.length} blok 'clinical jumble' (coverage>=${JUMBLE_COVERAGE_THRESHOLD}), menulis ulang via LLM...`);

    // Proses dari BELAKANG ke DEPAN supaya index kata blok berikutnya
    // (yang lebih awal) tidak berubah akibat penggantian panjang teks.
    let resultWords = [...words];
    for (let i = blocks.length - 1; i >= 0; i--) {
        const block = blocks[i];
        const originalSpan = words.slice(block.startWord, block.endWord).join(' ');
        const currentKey = typeof apiKey === 'function' ? apiKey() : apiKey;
        const narrated = await narrateJumbleWithLLM(originalSpan, currentKey);
        console.log(`      Blok ${i + 1}/${blocks.length} (coverage=${block.coverage.toFixed(2)}, ${block.endWord - block.startWord} kata) → ditulis ulang (${narrated.split(/\s+/).length} kata)`);
        resultWords.splice(block.startWord, block.endWord - block.startWord, narrated);
        await new Promise(r => setTimeout(r, 400));
    }

    return resultWords.join(' ');
}

module.exports = {
    findJumbleWindows,
    groupIntoBlocks,
    narrateJumbleWithLLM,
    detectAndNarrateJumble,
    JUMBLE_COVERAGE_THRESHOLD,
    WINDOW_SIZE,
};