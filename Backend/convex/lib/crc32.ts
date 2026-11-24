// CRC-32 (IEEE 802.3), the checksum a ZIP file carries for each entry. The server computes it once, when it confirms an
// upload and already holds the picture's bytes, so the web album's download (worker/src/zip.ts) can write each ZIP entry
// with its checksum up front and pass the picture's bytes through untouched.
const TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
})();

export function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff;
  for (let index = 0; index < bytes.length; index += 1) crc = TABLE[(crc ^ bytes[index]!) & 0xff]! ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}
