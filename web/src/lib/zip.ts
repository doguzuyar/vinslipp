export interface ZipEntry {
  filename: string;
  data: Uint8Array;
}

/**
 * Extract files from a zip archive using browser-native APIs.
 * Supports "stored" (method 0) and "deflate" (method 8) entries.
 */
export async function extractZip(file: File): Promise<ZipEntry[]> {
  const buf = await file.arrayBuffer();
  const view = new DataView(buf);
  const bytes = new Uint8Array(buf);

  // Find End of Central Directory record (signature 0x06054b50)
  let eocdOffset = -1;
  for (let i = bytes.length - 22; i >= 0; i--) {
    if (view.getUint32(i, true) === 0x06054b50) {
      eocdOffset = i;
      break;
    }
  }
  if (eocdOffset === -1) throw new Error("Invalid zip file: EOCD not found");

  const cdOffset = view.getUint32(eocdOffset + 16, true);
  const cdEntries = view.getUint16(eocdOffset + 10, true);

  const entries: ZipEntry[] = [];
  let pos = cdOffset;

  for (let i = 0; i < cdEntries; i++) {
    if (view.getUint32(pos, true) !== 0x02014b50) break;

    const nameLen = view.getUint16(pos + 28, true);
    const extraLen = view.getUint16(pos + 30, true);
    const commentLen = view.getUint16(pos + 32, true);
    const localHeaderOffset = view.getUint32(pos + 42, true);
    const filename = new TextDecoder().decode(bytes.slice(pos + 46, pos + 46 + nameLen));

    // Skip directories
    if (!filename.endsWith("/")) {
      // Read local file header to get actual data
      const lhPos = localHeaderOffset;
      if (view.getUint32(lhPos, true) === 0x04034b50) {
        const method = view.getUint16(lhPos + 8, true);
        const compressedSize = view.getUint32(lhPos + 18, true);
        const lhNameLen = view.getUint16(lhPos + 26, true);
        const lhExtraLen = view.getUint16(lhPos + 28, true);
        const dataStart = lhPos + 30 + lhNameLen + lhExtraLen;
        const compressed = bytes.slice(dataStart, dataStart + compressedSize);

        let data: Uint8Array;
        if (method === 0) {
          // Stored (no compression)
          data = compressed;
        } else if (method === 8) {
          // Deflate
          data = await inflate(compressed);
        } else {
          // Skip unsupported compression methods
          pos += 46 + nameLen + extraLen + commentLen;
          continue;
        }

        // Strip directory prefix — use only the basename
        const basename = filename.includes("/")
          ? filename.slice(filename.lastIndexOf("/") + 1)
          : filename;

        entries.push({ filename: basename, data });
      }
    }

    pos += 46 + nameLen + extraLen + commentLen;
  }

  return entries;
}

async function inflate(compressed: Uint8Array): Promise<Uint8Array> {
  const ds = new DecompressionStream("deflate-raw");
  const writer = ds.writable.getWriter();
  const reader = ds.readable.getReader();

  writer.write(compressed as unknown as Uint8Array<ArrayBuffer>);
  writer.close();

  const chunks: Uint8Array[] = [];
  let totalLen = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    totalLen += value.length;
  }

  const result = new Uint8Array(totalLen);
  let offset = 0;
  for (const chunk of chunks) {
    result.set(chunk, offset);
    offset += chunk.length;
  }
  return result;
}

export function uint8ArrayToString(data: Uint8Array): string {
  return new TextDecoder("utf-8").decode(data);
}
