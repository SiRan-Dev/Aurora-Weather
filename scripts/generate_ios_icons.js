#!/usr/bin/env node
/**
 * Regenerates ios/Runner/Assets.xcassets/AppIcon.appiconset from a 1024x1024 master PNG.
 *
 * Usage:
 *   npm run generate:ios-icons [path/to/icon-1024.png]
 *
 * The master defaults to assets/icons/app_icon_1024.png. Every generated image is
 * flattened to opaque RGB because iOS app icons must not contain an alpha channel.
 */
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const ROOT = path.resolve(__dirname, '..');
const SOURCE = path.resolve(
  process.argv[2] || path.join(ROOT, 'assets/icons/app_icon_1024.png'),
);
const OUT_DIR = path.join(
  ROOT,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset',
);

// [idiom, size, scale, pixel size]
const SLOTS = [
  ['iphone', '20x20', '2x', 40],
  ['iphone', '20x20', '3x', 60],
  ['iphone', '29x29', '2x', 58],
  ['iphone', '29x29', '3x', 87],
  ['iphone', '40x40', '2x', 80],
  ['iphone', '40x40', '3x', 120],
  ['iphone', '60x60', '2x', 120],
  ['iphone', '60x60', '3x', 180],
  ['ipad', '20x20', '1x', 20],
  ['ipad', '20x20', '2x', 40],
  ['ipad', '29x29', '1x', 29],
  ['ipad', '29x29', '2x', 58],
  ['ipad', '40x40', '1x', 40],
  ['ipad', '40x40', '2x', 80],
  ['ipad', '76x76', '1x', 76],
  ['ipad', '76x76', '2x', 152],
  ['ipad', '83.5x83.5', '2x', 167],
  ['ios-marketing', '1024x1024', '1x', 1024],
];

async function main() {
  if (!fs.existsSync(SOURCE)) {
    throw new Error(`Icon source not found: ${SOURCE}`);
  }

  const meta = await sharp(SOURCE).metadata();
  if (meta.width !== 1024 || meta.height !== 1024) {
    throw new Error(
      `Icon source must be 1024x1024, got ${meta.width}x${meta.height}: ${SOURCE}`,
    );
  }

  fs.mkdirSync(OUT_DIR, { recursive: true });

  const files = new Map();
  for (const [, size, scale, px] of SLOTS) {
    files.set(`Icon-App-${size}@${scale}.png`, px);
  }

  for (const [name, px] of files) {
    await sharp(SOURCE)
      .resize(px, px, { kernel: 'lanczos3', fit: 'fill' })
      .removeAlpha()
      .png({ compressionLevel: 9 })
      .toFile(path.join(OUT_DIR, name));
  }

  // Drop stale icon PNGs left over from a previous naming scheme.
  const keep = new Set(['Contents.json', ...files.keys()]);
  for (const file of fs.readdirSync(OUT_DIR)) {
    if (file.endsWith('.png') && !keep.has(file)) {
      fs.rmSync(path.join(OUT_DIR, file));
    }
  }

  const contents = {
    images: SLOTS.map(([idiom, size, scale]) => ({
      size,
      idiom,
      filename: `Icon-App-${size}@${scale}.png`,
      scale,
    })),
    info: { version: 1, author: 'xcode' },
  };
  fs.writeFileSync(
    path.join(OUT_DIR, 'Contents.json'),
    `${JSON.stringify(contents, null, 2)}\n`,
  );

  console.log(
    `Generated ${files.size} icons in ${path.relative(ROOT, OUT_DIR)} from ${path.relative(ROOT, SOURCE)}`,
  );
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
