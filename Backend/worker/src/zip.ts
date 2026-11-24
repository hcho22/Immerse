// The web album's download (v2 PRD V2-FR-47: "save one picture at a time or download the album"): a ZIP file streamed
// from the pictures themselves, each stored as it is, never compressed or changed.
//
// Every entry's size and CRC-32 are known before its bytes arrive (the server computed the CRC when it confirmed the
// upload), so each local header is written whole and the picture's bytes are passed straight through. The Worker spends
// no processor time on them, and holds no picture in memory. A file name is a picture's number in the album and
// nothing else: no Guest Name is written anywhere in the file (V2-FR-46).
export type ZipEntry = {
  name: string;
  size: number;
  crc32: number;
  // When the picture was taken, for the entry's date.
  modified: Date;
  // The picture's bytes, asked for only when the stream reaches the entry.
  body: () => Promise<ReadableStream<Uint8Array>>;
};

// The classic ZIP format holds entries and archives up to 4 GiB and 65,535 entries. A part of the album stays far under
// both (`partsOf`), so no ZIP64 record is ever needed.
const MAX_ARCHIVE_BYTES = 0xffff_fff0;

function dosTime(date: Date): { time: number; day: number } {
  const year = Math.max(1980, date.getUTCFullYear());
  return {
    time: (date.getUTCHours() << 11) | (date.getUTCMinutes() << 5) | (date.getUTCSeconds() >> 1),
    day: ((year - 1980) << 9) | ((date.getUTCMonth() + 1) << 5) | date.getUTCDate(),
  };
}

function localHeader(entry: ZipEntry, name: Uint8Array): Uint8Array {
  const header = new Uint8Array(30 + name.length);
  const view = new DataView(header.buffer);
  const { time, day } = dosTime(entry.modified);
  view.setUint32(0, 0x04034b50, true);
  view.setUint16(4, 20, true); // version needed: 2.0
  view.setUint16(6, 0x0800, true); // names are UTF-8
  view.setUint16(8, 0, true); // stored
  view.setUint16(10, time, true);
  view.setUint16(12, day, true);
  view.setUint32(14, entry.crc32, true);
  view.setUint32(18, entry.size, true);
  view.setUint32(22, entry.size, true);
  view.setUint16(26, name.length, true);
  view.setUint16(28, 0, true);
  header.set(name, 30);
  return header;
}

function centralHeader(entry: ZipEntry, name: Uint8Array, offset: number): Uint8Array {
  const header = new Uint8Array(46 + name.length);
  const view = new DataView(header.buffer);
  const { time, day } = dosTime(entry.modified);
  view.setUint32(0, 0x02014b50, true);
  view.setUint16(4, 20, true);
  view.setUint16(6, 20, true);
  view.setUint16(8, 0x0800, true);
  view.setUint16(10, 0, true);
  view.setUint16(12, time, true);
  view.setUint16(14, day, true);
  view.setUint32(16, entry.crc32, true);
  view.setUint32(20, entry.size, true);
  view.setUint32(24, entry.size, true);
  view.setUint16(28, name.length, true);
  view.setUint32(42, offset, true);
  header.set(name, 46);
  return header;
}

function endRecord(count: number, size: number, offset: number): Uint8Array {
  const record = new Uint8Array(22);
  const view = new DataView(record.buffer);
  view.setUint32(0, 0x06054b50, true);
  view.setUint16(8, count, true);
  view.setUint16(10, count, true);
  view.setUint32(12, size, true);
  view.setUint32(16, offset, true);
  return record;
}

// The whole archive's size, known before a byte is sent, so the download shows its progress.
export function zipSize(entries: ZipEntry[]): number {
  const encoder = new TextEncoder();
  let size = 22;
  for (const entry of entries) size += 30 + 46 + 2 * encoder.encode(entry.name).length + entry.size;
  return size;
}

// The archive as a stream. An entry whose bytes cannot be had, or are not the size the album said, ends the stream with
// an error, so a broken download is never mistaken for a whole one.
export function zipStream(entries: ZipEntry[]): ReadableStream<Uint8Array> {
  if (zipSize(entries) > MAX_ARCHIVE_BYTES || entries.length > 0xffff) throw new Error("Too large for one ZIP part");
  const encoder = new TextEncoder();
  const { readable, writable } = new TransformStream<Uint8Array, Uint8Array>();
  const write = async () => {
    const writer = writable.getWriter();
    try {
      const central: Uint8Array[] = [];
      let offset = 0;
      for (const entry of entries) {
        const name = encoder.encode(entry.name);
        const header = localHeader(entry, name);
        await writer.write(header);
        central.push(centralHeader(entry, name, offset));
        offset += header.length;
        const reader = (await entry.body()).getReader();
        let sent = 0;
        for (;;) {
          const { done, value } = await reader.read();
          if (done) break;
          sent += value.length;
          await writer.write(value);
        }
        if (sent !== entry.size) throw new Error("A picture was not the size the album said");
        offset += sent;
      }
      let directory = 0;
      for (const header of central) {
        await writer.write(header);
        directory += header.length;
      }
      await writer.write(endRecord(entries.length, directory, offset));
      await writer.close();
    } catch (error) {
      await writer.abort(error).catch(() => undefined);
    }
  };
  void write();
  return readable;
}

// The album in parts a browser and the Worker can both carry: at most `pictures` pictures and `bytes` bytes each.
export function partsOf<T extends { size: number }>(items: T[], pictures: number, bytes: number): T[][] {
  const parts: T[][] = [];
  let current: T[] = [];
  let weight = 0;
  for (const item of items) {
    if (current.length > 0 && (current.length >= pictures || weight + item.size > bytes)) {
      parts.push(current);
      current = [];
      weight = 0;
    }
    current.push(item);
    weight += item.size;
  }
  if (current.length > 0) parts.push(current);
  return parts;
}
