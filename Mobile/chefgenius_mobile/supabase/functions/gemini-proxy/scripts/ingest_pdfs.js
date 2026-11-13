const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const dotenv = require('dotenv');
const pdfParse = require('pdf-parse');
const readline = require('readline');
const { createClient } = require('@supabase/supabase-js');
const { RecursiveCharacterTextSplitter } = require('@langchain/textsplitters');
const { detectAndNarrateJumble } = require('./jumble_detector'); // <-- TAMBAHAN

dotenv.config({ path: path.resolve(__dirname, '.env') });
dotenv.config();

const SUPABASE_URL = process.env.SUPABASE_URL || '';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const EMBEDDING_MODEL = 'gemini-embedding-001';
const EMBEDDING_DELAY_MS = Math.max(0, parseInt(process.env.EMBEDDING_DELAY_MS || '300', 10) || 300);

// Support multiple API keys for rotation on rate limit (GEMINI_KEYS=key1,key2 or fallback to GEMINI_API_KEY)
const GEMINI_KEYS = (process.env.GEMINI_KEYS || process.env.GEMINI_API_KEY || '')
    .split(',').map(k => k.trim()).filter(Boolean);
let geminiKeyIndex = 0;
function getNextGeminiKey() {
    const key = GEMINI_KEYS[geminiKeyIndex];
    geminiKeyIndex = (geminiKeyIndex + 1) % GEMINI_KEYS.length;
    return key;
}
function currentGeminiKey() { return GEMINI_KEYS[geminiKeyIndex]; }

const pdfDir = path.resolve(__dirname, '../../../../Dokumen_Knowledge_Base_Untuk_Dosen');
const fallbackPdfDir = path.resolve(__dirname, '../../../..');
const csvOutputDir = path.resolve(pdfDir, 'data tabel knowledge base');

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY || GEMINI_KEYS.length === 0) {
    console.error('❌ Missing environment variables.');
    process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

const splitter = new RecursiveCharacterTextSplitter({
    chunkSize: 1000,
    chunkOverlap: 200,
});

function preprocessText(text) {
    let result = text;

    // --- Step 1: Convert § bullet lists to narrative sentences ---
    // FIXED: Gunakan format "Label: value" bukan "Label adalah value"
    // agar tidak menambah noise kata "adalah" ke dalam chunk
    result = result.replace(/§\s*([^§\n]{3,120})/g, (match, content) => {
        content = content.trim();
        if (!content) return '';

        const rangePattern = /^([A-Za-z\s\/\(\)]+)\s+([\d,.\-–\s]+(?:g\/dL|mg\/dL|kg\/m2|mmHg|kal|kkal|gram|mg|g|%|mEq\/L|mL|IU|mmol\/L)?.*)/;
        const rangeMatch = content.match(rangePattern);
        if (rangeMatch) {
            const label = rangeMatch[1].trim();
            const value = rangeMatch[2].trim();
            // FIXED: Pakai ":" bukan "adalah"
            return `${label}: ${value}. `;
        }

        const sentence = content.endsWith('.') ? content : `${content}.`;
        return `${sentence} `;
    });

    // --- Step 2: Detect and narrate flat table rows ---
    // 3-column: "Kondisi | Target | Obat" → "Pada kondisi X, target: Y. Pilihan obat: Z."
    const tableRowPattern = /^([^\n|]{2,40})\s*\|\s*([^\n|]{2,80})\s*\|\s*([^\n|]{2,80})/gm;
    result = result.replace(tableRowPattern, (match, col1, col2, col3) => {
        col1 = col1.trim(); col2 = col2.trim(); col3 = col3.trim();
        if (!col1 || !col2) return match;
        if (col1.length < 4 && col2.length < 4) return match;
        return `Pada kondisi ${col1}, target: ${col2}. Pilihan obat: ${col3}. `;
    });

    // 2-column: "A | B" → "A: B."
    const twoColPattern = /^([^\n|]{2,40})\s*\|\s*([^\n|]{2,80})$/gm;
    result = result.replace(twoColPattern, (match, col1, col2) => {
        col1 = col1.trim(); col2 = col2.trim();
        if (!col1 || !col2 || col1.length < 3) return match;
        return `${col1}: ${col2}. `;
    });

    // --- Step 3: Clean up leftover formatting artifacts ---
    result = result
        .replace(/\s{3,}/g, ' ')
        .replace(/\.{3,}/g, '.')
        .replace(/_{3,}/g, ' ')
        .replace(/\|+/g, ' ')
        .trim();

    return result;
}

const delay = (ms) => new Promise(res => setTimeout(res, ms));

// ============================================================
// CSV EXPORT: Tulis file CSV per-PDF ke folder "data tabel knowledge base"
// Format kolom sesuai schema Supabase: id, category, title, content,
// source, metadata, embedding, created_at, updated_at
// ============================================================
function csvEscapeField(value) {
    const str = String(value ?? '');
    // Wrap dalam tanda kutip jika mengandung koma, kutip, atau newline
    if (str.includes('"') || str.includes(',') || str.includes('\n') || str.includes('\r')) {
        return '"' + str.replace(/"/g, '""') + '"';
    }
    return str;
}

const CSV_HEADERS = ['id', 'category', 'title', 'content', 'source', 'metadata', 'embedding', 'created_at', 'updated_at'];

function writeCsvFile(fileName, rows) {
    if (rows.length === 0) {
        console.log('   ℹ️  Tidak ada baris CSV untuk ditulis.');
        return;
    }

    if (!fs.existsSync(csvOutputDir)) {
        fs.mkdirSync(csvOutputDir, { recursive: true });
    }

    const safeName = fileName.replace(/\.pdf$/i, '').replace(/[^a-zA-Z0-9\-_ ()]/g, '_');
    const csvPath = path.join(csvOutputDir, `${safeName}.csv`);

    const headerLine = CSV_HEADERS.map(csvEscapeField).join(',');
    const dataLines = rows.map(row =>
        CSV_HEADERS.map(col => csvEscapeField(row[col] ?? '')).join(',')
    );

    const csvContent = [headerLine, ...dataLines].join('\n');
    fs.writeFileSync(csvPath, csvContent, 'utf8');
    console.log(`   📄 CSV disimpan: ${csvPath} (${rows.length} baris)`);
}

function sanitizeDbText(value) {
    return String(value ?? '')
        .normalize('NFKC')
        .replace(/\u0000/g, '')
        .replace(/[\uD800-\uDFFF]/g, '')
        .replace(/\\/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
}

// ============================================================
// TABLE DETECTION v2 — Fixed to prevent false positives on
// multi-column PDF prose. Only treats lines as table rows if:
// 1. They contain pipe '|' delimiters, OR
// 2. They have >= 3 short columns (split by 2+ spaces) AND
//    at least one column contains numeric/tabular content.
// Long prose lines with incidental double-spaces are NEVER
// treated as tables.
// ============================================================

function splitTableRow(row) {
    const trimmed = String(row ?? '').trim();
    if (!trimmed) return [];

    if (trimmed.includes('|')) {
        return trimmed.split('|').map(part => part.trim()).filter(Boolean);
    }

    const columns = trimmed.split(/\s{2,}/).map(part => part.trim()).filter(Boolean);
    return columns.length >= 2 ? columns : [];
}

/**
 * Check if a column looks like tabular data (numbers, units, percentages,
 * short codes, etc.) rather than prose words.
 */
function looksTabular(cell) {
    const s = cell.trim();
    if (!s) return false;
    // Numbers with optional units/percentages
    if (/^[\d.,\-–]+\s*(%|g\/dL|mg\/dL|kg\/m2|mmHg|kal|kkal|gram|mg|g|mEq\/L|mL|IU|mmol\/L|mcg|µg)?$/i.test(s)) return true;
    // Ranges like "10-20" or "< 5.0"
    if (/^[<>≤≥]?\s*[\d.,]+\s*[-–]\s*[\d.,]+/.test(s)) return true;
    // Short codes (1-4 chars, all caps or with digits)
    if (s.length <= 4 && /[A-Z0-9]/.test(s)) return true;
    // Percentage expressions
    if (/\d+\s*%/.test(s)) return true;
    return false;
}

function isLikelyTableRow(row) {
    const trimmed = String(row ?? '').trim();
    if (!trimmed) return false;

    // Rule 1: Pipe delimiters → definitely a table
    if (trimmed.includes('|')) return true;

    // Rule 2: Check for multi-column layout with double-space gaps
    if (!/\S\s{2,}\S/.test(trimmed)) return false;

    const columns = trimmed.split(/\s{2,}/).map(c => c.trim()).filter(Boolean);

    // Need at least 3 columns for space-delimited table detection
    if (columns.length < 3) return false;

    // Too many "columns" (> 8) usually means justified prose with
    // double-spaces between every word, not a real table
    if (columns.length > 8) return false;

    // Reject if it looks like prose: total word count > 12 with few gaps
    const totalWords = trimmed.split(/\s+/).length;
    if (totalWords > 15 && columns.length <= 3) return false;

    // Reject if most "columns" are single words (justified prose artifact).
    // Real table cells tend to have content like "LDL ↓ 48-71%" (multi-word).
    const singleWordCols = columns.filter(c => c.split(/\s+/).length === 1).length;
    if (singleWordCols / columns.length > 0.6) return false;

    // At least one column must contain tabular-looking data
    const tabularCount = columns.filter(looksTabular).length;
    if (tabularCount === 0) return false;

    // All columns should be reasonably short (< 8 words each)
    // Prose columns tend to be much longer
    const longColumns = columns.filter(c => c.split(/\s+/).length > 8).length;
    if (longColumns > 0) return false;

    return true;
}

/**
 * Narrate a block of detected table rows into prose.
 * GUARD: If the narrated output looks scrambled (lots of short key:value
 * pairs that don't make sense), abort and return raw text.
 */
function narrateTableBlock(rows) {
    const parsedRows = rows.map(splitTableRow).filter(columns => columns.length >= 2);
    if (parsedRows.length < 2) {
        return rows.join(' ');
    }

    const header = parsedRows[0];
    const dataRows = parsedRows.slice(1);
    const narrations = dataRows.map(columns => {
        let rowProse = [];
        for (let i = 0; i < columns.length; i++) {
            const colName = header[i] ? header[i].replace(/[.,]/g, '').trim() : '';
            const cellVal = columns[i] ? columns[i].replace(/[.,]/g, '').trim() : '';
            if (colName && cellVal) {
                rowProse.push(`${colName}: ${cellVal}`);
            } else if (cellVal) {
                rowProse.push(cellVal);
            }
        }
        return rowProse.join('; ') + '.';
    });

    const result = narrations.join(' ');

    // GUARD: Detect scrambled output.
    // Count key:value pairs where BOTH key and value are short (< 3 words)
    // and neither contains a number. This pattern indicates false table detection.
    const pairs = result.match(/[;,]\s*\S+(?:\s+\S+){0,2}:\s+\S+(?:\s+\S+){0,2}/g) || [];
    const totalWords = result.split(/\s+/).length;
    const scrambledPairs = pairs.filter(p => {
        const parts = p.replace(/^[;,]\s*/, '').split(':');
        if (parts.length < 2) return false;
        const key = parts[0].trim();
        const val = parts.slice(1).join(':').trim();
        // Both sides short AND no numbers → likely scrambled prose
        return key.split(/\s+/).length <= 2 &&
            val.split(/\s+/).length <= 2 &&
            !/\d/.test(key) && !/\d/.test(val);
    }).length;

    // If > 30% of content looks like scrambled pairs, abort narration
    if (totalWords > 10 && scrambledPairs / (totalWords / 4) > 0.3) {
        return rows.join(' ');
    }

    return result;
}

/**
 * Process text line-by-line, detecting table blocks and narrating them.
 * Uses block-level validation: consecutive lines must have consistent
 * column counts (>= 3 rows) to be treated as a table.
 */
function narrateTablesInText(text) {
    const lines = String(text ?? '').split(/\r?\n/);
    const output = [];
    let tableBuffer = [];

    const flushBuffer = () => {
        if (tableBuffer.length === 0) return;

        // Block-level validation: check column count consistency
        if (tableBuffer.length >= 3) {
            const colCounts = tableBuffer.map(r => splitTableRow(r).length);
            // Find the most common column count
            const countFreq = {};
            colCounts.forEach(c => { countFreq[c] = (countFreq[c] || 0) + 1; });
            const maxFreqCount = Math.max(...Object.values(countFreq));
            // At least 60% of rows should have same column count
            if (maxFreqCount / tableBuffer.length >= 0.6) {
                output.push(narrateTableBlock(tableBuffer));
            } else {
                // Inconsistent columns → not a real table, return as prose
                output.push(tableBuffer.join(' '));
            }
        } else if (tableBuffer.length >= 2) {
            // Only 2 rows — narrate only if they have pipe delimiters
            const hasPipes = tableBuffer.some(r => r.includes('|'));
            if (hasPipes) {
                output.push(narrateTableBlock(tableBuffer));
            } else {
                output.push(tableBuffer.join(' '));
            }
        } else {
            output.push(tableBuffer.join(' '));
        }
        tableBuffer = [];
    };

    for (const line of lines) {
        if (isLikelyTableRow(line)) {
            tableBuffer.push(line);
        } else {
            flushBuffer();
            output.push(line);
        }
    }

    flushBuffer();
    return output.join(' ');
}

function createContinuePrompt() {
    if (process.env.AUTO_CONFIRM === 'true' || process.argv.includes('--yes') || process.argv.includes('-y')) {
        return async () => true;
    }
    if (!process.stdin.isTTY || process.env.AUTO_CONTINUE === 'true') {
        return async () => true;
    }

    return async (message) => {
        const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
        return await new Promise((resolve) => {
            rl.question(message, (answer) => {
                rl.close();
                resolve(/^y(es)?$/i.test(String(answer ?? '').trim()));
            });
        });
    };
}

function resolvePdfPath(file) {
    const candidates = [
        path.join(pdfDir, file),
        path.join(fallbackPdfDir, file),
    ];
    for (const candidate of candidates) {
        if (fs.existsSync(candidate)) return candidate;
    }
    return null;
}

async function generateEmbeddingWithRetry(text, chunkLabel, maxRetries = 10) {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        const apiKey = currentGeminiKey();
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${EMBEDDING_MODEL}:embedContent?key=${apiKey}`;
        try {
            const response = await fetch(url, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    model: `models/${EMBEDDING_MODEL}`,
                    content: { parts: [{ text }] },
                    taskType: 'RETRIEVAL_DOCUMENT',
                }),
            });

            if (response.ok) {
                const result = await response.json();
                return { values: result.embedding.values, model: EMBEDDING_MODEL };
            }

            const errorText = await response.text();

            const nextKey = getNextGeminiKey();
            if (GEMINI_KEYS.length > 1 && attempt <= GEMINI_KEYS.length) {
                // Rotate to next key immediately if we haven't tried all keys yet
                console.log(`   ⏳ ${chunkLabel} Rate limited/Error ${response.status} on key ...${apiKey.slice(-6)}. Switching to key ...${nextKey.slice(-6)} (attempt ${attempt}/${maxRetries})`);
                await delay(2000);
            } else {
                let waitSeconds = 15 * attempt;
                const retryMatch = errorText.match(/"retryDelay":\s*"(\d+)s"/);
                if (retryMatch) waitSeconds = parseInt(retryMatch[1]) + 3;
                console.log(`   ⏳ ${chunkLabel} Error ${response.status} on ALL keys (attempt ${attempt}/${maxRetries}). Waiting ${waitSeconds}s...`);
                await delay(waitSeconds * 1000);
            }
            continue;

        } catch (networkError) {
            console.log(`   🌐 ${chunkLabel} Network error (attempt ${attempt}/${maxRetries}): ${networkError.message}. Waiting 15s...`);
            await delay(15000);
        }
    }

    console.error(`   ❌ ${chunkLabel} FAILED after ${maxRetries} retries. Skipping.`);
    return null;
}

// ============================================================
// Hapus chunk lama sebelum insert ulang.
// WAJIB karena chunk size berubah (800 vs 1500) sehingga
// index chunk berbeda — tanpa delete akan ada duplikat.
// ============================================================
async function deleteExistingChunks(source) {
    const { error } = await supabase
        .from('knowledge_base')
        .delete()
        .eq('source', source);

    if (error) {
        console.warn(`   ⚠️ Failed to delete existing chunks for ${source}: ${error.message}`);
    } else {
        console.log(`   🗑️  Deleted old chunks for: ${source}`);
    }
}

// ============================================================
// Resume: hanya skip file yang sudah di-ingest dengan v5.
// File v4 (chunkSize 1500) akan di-re-ingest ulang.
// ============================================================
async function getAlreadyIngestedSources() {
    try {
        const sourcesSet = new Set();
        let step = 1000, hasMore = true, start = 0;
        while (hasMore) {
            const { data, error } = await supabase
                .from('knowledge_base')
                .select('source, metadata')
                .range(start, start + step - 1);
            if (error || !data || data.length === 0) { hasMore = false; break; }
            data.forEach(d => {
                if (d.metadata?.source_code === 'IngestPipeline_v8_c1000_o200') sourcesSet.add(d.source);
            });
            if (data.length < step) hasMore = false;
            start += step;
        }
        return sourcesSet;
    } catch {
        return new Set();
    }
}

// ============================================================
// RESUME_PARTIAL: Query chunk indices yang sudah ada di DB
// untuk file tertentu, sehingga bisa lanjut dari chunk terakhir
// tanpa menghapus dan mengulang dari awal.
// ============================================================
async function getExistingChunkIndices(source) {
    try {
        const existingIdx = new Set();
        let step = 1000, hasMore = true, start = 0;
        while (hasMore) {
            const { data, error } = await supabase
                .from('knowledge_base')
                .select('metadata')
                .eq('source', source)
                .range(start, start + step - 1);
            if (error || !data || data.length === 0) { hasMore = false; break; }
            data.forEach(d => {
                if (d.metadata?.source_code === 'IngestPipeline_v8_c1000_o200' && typeof d.metadata?.chunk_idx === 'number') {
                    existingIdx.add(d.metadata.chunk_idx);
                }
            });
            if (data.length < step) hasMore = false;
            start += step;
        }
        return existingIdx;
    } catch {
        return new Set();
    }
}

async function processPdf(file, resumePartial = false) {
    const csvRows = []; // Kumpulkan semua baris untuk CSV
    const filePath = resolvePdfPath(file);
    if (!filePath) { console.error(`Missing PDF file: ${file}`); return; }

    const dataBuffer = fs.readFileSync(filePath);
    console.log(`\n📄 Parsing PDF: ${file}`);

    let parsedData;
    try {
        parsedData = await pdfParse(dataBuffer);
    } catch (err) {
        console.error(`Could not parse PDF: ${file}. Error: ${err}`);
        return;
    }

    let text = parsedData.text.replace(/\r/g, '\n').replace(/\n{3,}/g, '\n\n').trim();
    if (!text) { console.log(`No readable text in ${file}.`); return; }

    const originalLen = text.length;
    text = preprocessText(narrateTablesInText(text));
    console.log(`✨ Pre-processed: ${originalLen} → ${text.length} chars`);

    // ============================================================
    // TAMBAHAN: tangani "clinical jumble" yang lolos dari isLikelyTableRow()
    // di atas -- tabel yang kolomnya collapse jadi spasi tunggal saat
    // ekstraksi pdf-parse (lihat jumble_detector.js untuk detail lengkap).
    // Dijalankan SEBELUM chunking supaya hasil narasi ikut ter-chunk rapi.
    // ============================================================
    const beforeJumbleLen = text.length;
    text = await detectAndNarrateJumble(text, getNextGeminiKey);
    if (text.length !== beforeJumbleLen) {
        console.log(`🩹 Jumble narration: ${beforeJumbleLen} → ${text.length} chars`);
    }

    console.log(`✂️  Splitting... (chunkSize: 1000, overlap: 200)`);
    const chunks = await splitter.splitText(text);
    console.log(`   Total chunks: ${chunks.length}`);

    // RESUME_PARTIAL: query chunk yang sudah ada, skip yang belum
    // FORCE_REINGEST / normal: hapus semua chunk lama lalu mulai fresh
    let existingChunkIdx = new Set();
    if (resumePartial) {
        // FIX Task 2: Cek apakah DB sudah punya chunk v6 untuk source ini.
        // Jika tidak ada chunk v6 (berarti masih v5 atau kosong), hapus dulu sebelum resume
        // untuk mencegah duplikat mixed v5+v6.
        existingChunkIdx = await getExistingChunkIndices(file);
        if (existingChunkIdx.size === 0) {
            // Tidak ada chunk v6 → kemungkinan masih v5. Hapus semua dulu, lalu mulai fresh.
            console.log(`   ⚠️  Resume partial: tidak ada chunk v6 ditemukan untuk ${file}.`);
            console.log(`   🗑️  Hapus chunk versi lama (jika ada) sebelum memulai fresh...`);
            await deleteExistingChunks(file);
        } else {
            const skippable = existingChunkIdx.size;
            console.log(`   ♻️  Resume partial: ${skippable}/${chunks.length} chunks v6 sudah ada, lanjut dari chunk yang belum.`);
        }
    } else {
        await deleteExistingChunks(file);
    }

    let successCount = 0;
    let skippedCount = 0;
    for (let idx = 0; idx < chunks.length; idx++) {
        const chunk = chunks[idx];

        // Skip chunk yang sudah ada di DB (mode RESUME_PARTIAL)
        if (resumePartial && existingChunkIdx.has(idx)) {
            skippedCount++;
            continue;
        }
        const label = `[${idx + 1}/${chunks.length}]`;
        console.log(`   ${label} Generating embedding...`);

        const embeddingInfo = await generateEmbeddingWithRetry(chunk, label);
        if (!embeddingInfo?.values) continue;

        const rowId = crypto.randomUUID();
        const nowTs = new Date().toISOString();
        const metadataObj = {
            source_code: 'IngestPipeline_v8_c1000_o200',
            chunk_idx: idx,
            citation: `${sanitizeDbText(file.replace('.pdf', ''))} (Chunk ${idx + 1}/${chunks.length})`
        };
        const embeddingStr = `[${embeddingInfo.values.join(',')}]`;

        const record = {
            id: rowId,
            category: 'nutrition_guide',
            title: sanitizeDbText(file.replace('.pdf', '')).substring(0, 100),
            content: sanitizeDbText(chunk).substring(0, 5000),
            source: sanitizeDbText(file),
            embedding: embeddingStr,
            metadata: metadataObj,
        };

        const { error } = await supabase.from('knowledge_base').insert([record]);
        if (error) {
            console.error(`    ${label} DB error:`, error.message || error);
            if (error.details) console.error(`   ↳ details: ${error.details}`);
            if (error.hint) console.error(`   ↳ hint: ${error.hint}`);
        } else {
            successCount++;
            console.log(`   ✅ ${label} Stored.`);

            // Tambah ke CSV rows (hanya jika berhasil masuk DB)
            csvRows.push({
                id: rowId,
                category: record.category,
                title: record.title,
                content: record.content,
                source: record.source,
                metadata: JSON.stringify(metadataObj),
                embedding: embeddingStr,
                created_at: nowTs,
                updated_at: nowTs,
            });
        }

        await delay(EMBEDDING_DELAY_MS);
    }

    // Tulis CSV setelah semua chunk selesai
    writeCsvFile(file, csvRows);
    const resumeNote = resumePartial && skippedCount > 0 ? ` (${skippedCount} skipped/resumed)` : '';
    console.log(`\n🎉 Finished ${file}: ${successCount}/${chunks.length} chunks stored (v6).${resumeNote}`,
        successCount > 0 ? '+ CSV generated ✅' : '');
}

async function main() {
    console.log('ChefGenius PDF Ingestion Pipeline v7');
    console.log('  chunkSize  : 1000 | overlap: 200');
    console.log('  preprocess : § bullets + tables → narasi + clinical jumble detection'); // <-- diperbarui
    console.log('  resume     : skip hanya jika sudah IngestPipeline_v8_c1000_o200');
    console.log('  confirm    : minta persetujuan sebelum dokumen berikutnya');
    console.log('  delete     : hapus chunk lama sebelum insert ulang');
    console.log(`  delay      : ${EMBEDDING_DELAY_MS} ms antar chunk`);
    console.log('=====================================================');

    if (!fs.existsSync(pdfDir)) { console.error(`Directory not found: ${pdfDir}`); return; }

    const primaryFiles = fs.existsSync(pdfDir)
        ? fs.readdirSync(pdfDir).filter(f => f.toLowerCase().endsWith('.pdf')) : [];
    const fallbackFiles = fs.existsSync(fallbackPdfDir)
        ? fs.readdirSync(fallbackPdfDir).filter(f => f.toLowerCase().endsWith('.pdf')) : [];
    let files = [...new Set([...primaryFiles, ...fallbackFiles])];
    // Exclude TKPI (already ingested via structured ingest_tkpi.js) and deleted scan files
    files = files.filter(f => !f.toLowerCase().includes('tkpi') && !f.toLowerCase().includes('obesitas bagi tenaga'));

    const onlySources = (process.env.ONLY_SOURCES || '').split('|').map(s => s.trim()).filter(Boolean);
    if (onlySources.length > 0) {
        files = files.filter(f => new Set(onlySources).has(f));
        console.log(`Target-only mode: ${onlySources.join(', ')}`);
    }

    console.log(`Found ${files.length} PDF files.`);

    const alreadyDone = await getAlreadyIngestedSources();
    const forceReingest = process.env.FORCE_REINGEST === 'true';
    const resumePartial = process.env.RESUME_PARTIAL === 'true';
    if (alreadyDone.size > 0) console.log(`Already v5 (skip): ${[...alreadyDone].join(', ')}`);
    if (forceReingest) console.log('Force reingest: enabled (hapus semua chunk lama → ingest ulang)');
    if (resumePartial) console.log('Resume partial: enabled (lanjut dari chunk yang belum masuk)');

    const askToContinue = createContinuePrompt();

    const startIngest = await askToContinue(`Mulai ingest dokumen pertama? [y/N] `);
    if (!startIngest) {
        console.log('Ingest dibatalkan sebelum mulai.');
        return;
    }

    let pdfNum = 0;
    for (const f of files) {
        pdfNum++;
        // Skip file yang sudah selesai penuh — KECUALI force/resume aktif
        if (alreadyDone.has(f) && !forceReingest && !resumePartial) {
            console.log(`\n[${pdfNum}/${files.length}] Skipping ${f} (already v5)`);
            continue;
        }
        if (forceReingest) {
            console.log(`\n[${pdfNum}/${files.length}] Force re-ingesting: ${f}`);
        } else if (resumePartial) {
            console.log(`\n[${pdfNum}/${files.length}] Resume partial: ${f}`);
        } else {
            console.log(`\n[${pdfNum}/${files.length}] Processing: ${f}`);
        }
        await processPdf(f, resumePartial);

        if (pdfNum < files.length) {
            const shouldContinue = await askToContinue(`\nLanjut ingest dokumen berikutnya? [y/N] `);
            if (!shouldContinue) {
                console.log('Stopped by user before next document.');
                break;
            }
        }
    }

    console.log('\n=====================================================');
    console.log('Done! Setelah ini:');
    console.log('1. Update ground_truth_chunk_idx di semua 15 vignette');
    console.log('2. Re-run semua 15 vignette untuk MRR yang valid');
}

main().catch(console.error);
