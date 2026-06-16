/** Extract pasteable / droppable files from a DataTransfer (clipboard or drop). */

const GENERIC_IMAGE_NAMES = new Set(['image.png', 'image', 'blob', '']);

function screenshotName(type: string): string {
  const ext = type.split('/')[1]?.split('+')[0] || 'png';
  const t = new Date();
  const two = (v: number) => String(v).padStart(2, '0');
  const stamp = `${t.getFullYear()}${two(t.getMonth() + 1)}${two(t.getDate())}-${two(t.getHours())}${two(t.getMinutes())}${two(t.getSeconds())}`;
  return `Screenshot-${stamp}.${ext}`;
}

/**
 * Collects files from clipboard/drop data, normalizing screenshots that arrive
 * with a generic name (e.g. `image.png`) into a timestamped `Screenshot-*` file.
 */
export function extractClipboardFiles(data: DataTransfer): File[] {
  const out: File[] = [];
  const seen = new Set<string>();

  const consider = (file: File | null) => {
    if (!file || file.size <= 0) return;
    let result = file;
    if (
      file.type.startsWith('image/') &&
      GENERIC_IMAGE_NAMES.has(file.name.toLowerCase())
    ) {
      result = new File([file], screenshotName(file.type), {
        type: file.type,
        lastModified: file.lastModified,
      });
    }
    const key = `${result.name}_${result.size}_${result.lastModified}`;
    if (seen.has(key)) return;
    seen.add(key);
    out.push(result);
  };

  if (data.items && data.items.length > 0) {
    for (const item of Array.from(data.items)) {
      if (item.kind !== 'file') continue;
      consider(item.getAsFile());
    }
  }

  if (out.length === 0 && data.files && data.files.length > 0) {
    for (const file of Array.from(data.files)) {
      consider(file);
    }
  }

  return out;
}
