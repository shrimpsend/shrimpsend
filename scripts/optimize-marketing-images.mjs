#!/usr/bin/env node
/** Optimize marketing images: resize, recompress PNG, generate WebP for landing assets. */

import { createRequire } from 'node:module';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const PUBLIC_DIR = path.join(ROOT, 'web', 'public');
const LANDING_DIR = path.join(PUBLIC_DIR, 'landing');

const MAX_WIDTH = 1200;
const WEBP_QUALITY = 85;
const WEBP_EFFORT = 6;

const require = createRequire(path.join(ROOT, 'web', 'package.json'));
const sharp = require('sharp');

/** @type {{ input: string; outputPng: string; webp?: string }[]} */
const JOBS = [
  {
    input: path.join(ROOT, 'marketing', 'hero-showcase-source.png'),
    outputPng: path.join(LANDING_DIR, 'hero-showcase.png'),
    webp: path.join(LANDING_DIR, 'hero-showcase.webp'),
  },
  {
    input: path.join(ROOT, 'marketing', 'readme-banner.png'),
    outputPng: path.join(ROOT, 'marketing', 'readme-banner.png'),
    preferJpeg: true,
  },
];

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  return `${(bytes / 1024).toFixed(1)} KB`;
}

function labelFor(filePath) {
  return path.relative(ROOT, filePath);
}

async function optimizeJob({ input, outputPng, webp, preferJpeg }) {
  const originalBuffer = await readFile(input);
  const beforeSize = originalBuffer.length;
  const metadata = await sharp(originalBuffer).metadata();
  const needsResize = (metadata.width ?? 0) > MAX_WIDTH;

  let pipeline = sharp(originalBuffer);
  if (needsResize) {
    pipeline = pipeline.resize(MAX_WIDTH, null, { withoutEnlargement: true });
  }

  const useJpeg = preferJpeg || metadata.format === 'jpeg';
  let savedBuffer;
  let info;

  if (useJpeg) {
    const result = await pipeline
      .jpeg({ quality: WEBP_QUALITY, mozjpeg: true })
      .toBuffer({ resolveWithObject: true });
    savedBuffer = result.data;
    info = result.info;
  } else {
    const result = await pipeline
      .png({ compressionLevel: 9, adaptiveFiltering: true })
      .toBuffer({ resolveWithObject: true });
    savedBuffer = needsResize || result.data.length < beforeSize ? result.data : originalBuffer;
    info = result.info;
  }

  await mkdir(path.dirname(outputPng), { recursive: true });
  await writeFile(outputPng, savedBuffer);

  let webpSize = null;
  if (webp) {
    const webpBuffer = await sharp(savedBuffer)
      .webp({ quality: WEBP_QUALITY, effort: WEBP_EFFORT })
      .toBuffer();
    await writeFile(webp, webpBuffer);
    webpSize = webpBuffer.length;
  }

  const finalMeta = await sharp(savedBuffer).metadata();

  return {
    input: labelFor(input),
    outputPng: labelFor(outputPng),
    webp: webp ? labelFor(webp) : null,
    width: finalMeta.width ?? info.width,
    height: finalMeta.height ?? info.height,
    beforeSize,
    afterPngSize: savedBuffer.length,
    webpSize,
  };
}

async function main() {
  console.log('Optimizing marketing images...\n');
  console.log('Input'.padEnd(40), 'Before', 'PNG', 'WebP', 'Saved');
  console.log('-'.repeat(88));

  let totalBefore = 0;
  let totalPng = 0;
  let totalWebp = 0;

  for (const job of JOBS) {
    const result = await optimizeJob(job);
    totalBefore += result.beforeSize;
    totalPng += result.afterPngSize;
    if (result.webpSize != null) {
      totalWebp += result.webpSize;
    }

    const saved = result.webpSize != null
      ? result.beforeSize - result.webpSize
      : result.beforeSize - result.afterPngSize;

    console.log(
      result.input.padEnd(40),
      formatBytes(result.beforeSize).padStart(8),
      formatBytes(result.afterPngSize).padStart(8),
      result.webpSize != null ? formatBytes(result.webpSize).padStart(8) : '—'.padStart(8),
      `${saved >= 0 ? '-' : '+'}${formatBytes(Math.abs(saved)).padStart(8)}`,
    );
    if (result.webp) {
      console.log(`  → ${result.outputPng}`);
      console.log(`  → ${result.webp} (${result.width}×${result.height})`);
    } else {
      console.log(`  → ${result.outputPng} (${result.width}×${result.height})`);
    }
  }

  console.log('-'.repeat(88));
  console.log(
    'TOTAL'.padEnd(40),
    formatBytes(totalBefore).padStart(8),
    formatBytes(totalPng).padStart(8),
    totalWebp > 0 ? formatBytes(totalWebp).padStart(8) : '—'.padStart(8),
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
