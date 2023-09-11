/*
 * make-empty-tiledata.js
 * A utility for generating empty binary tileset data for use with tools like
 * YY-CHR and meant to be directly inserted into linked game ROMS.
 *
 * Usage:
 *    node make-empty-tiledata.js [filename] [size]
 *
 * Example:
 *    node make-empty-tiledata.js my-tileset.bin 2048
 */
const fs = require('fs')

const characteRamSectionSize = 0x800
const filename = process.argv[2] || 'tileset.bin'
const size = parseInt(process.argv[3]) || (characteRamSectionSize * 3)
const buffer = Buffer.alloc(size, 0)

try {
  fs.writeFileSync(filename, buffer)
  console.log(`Empty binary file written to: '${filename}'`)
} catch (err) {
  console.error(`Error writing '${filename}': ${err}`)
}
