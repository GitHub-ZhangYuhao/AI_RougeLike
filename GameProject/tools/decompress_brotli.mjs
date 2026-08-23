import { createReadStream, createWriteStream } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { promisify } from 'util';
import { pipeline } from 'stream';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Try to use iltorb if available, otherwise provide instructions
try {
    const iltorb = require('iltorb');
    const decompress = promisify(iltorb.decompress);
    
    const inputPath = process.argv[2];
    const outputPath = process.argv[3] || inputPath.replace('.br', '');
    
    if (!inputPath) {
        console.error('Usage: node decompress_brotli.mjs <input.br> [output]');
        process.exit(1);
    }
    
    console.log(`Decompressing ${inputPath} to ${outputPath}...`);
    const inputBuffer = await createReadStream(inputPath).toArray();
    const decompressed = await decompress(Buffer.concat(inputBuffer));
    await createWriteStream(outputPath).write(decompressed);
    console.log('Decompressed successfully');
} catch (e) {
    console.error('iltorb not available. Please install: npm install iltorb');
    console.error('Or use manual decompression tool');
    process.exit(1);
}