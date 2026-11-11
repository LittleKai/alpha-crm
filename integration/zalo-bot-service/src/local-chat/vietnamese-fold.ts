// Adapted from https://github.com/luonghaianh1208/2anh-zalo-bot@9ab55105c83487588e66b55f0ef66894224250a7 (MIT License)

const COMBINING_MARKS = /[\u0300-\u036f]/g;

/**
 * Fold Vietnamese text into lowercase ASCII-comparable text by stripping
 * NFD combining diacritics and mapping đ/Đ to d.
 */
export function foldVietnamese(input: unknown): string {
  return String(input ?? '')
    .normalize('NFD')
    .replace(COMBINING_MARKS, '')
    .replace(/[đĐ]/g, 'd')
    .toLowerCase();
}
