// Adapted from https://github.com/luonghaianh1208/2anh-zalo-bot@9ab55105c83487588e66b55f0ef66894224250a7 (MIT License)

export interface ZaloTextStyleSpan {
  start: number;
  len: number;
  st: string;
}

export interface ZaloFormattedChunk {
  text: string;
  styles: ZaloTextStyleSpan[];
}

const SUPERSCRIPT: Record<string, string> = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
  '+': '⁺', '-': '⁻', '−': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
  a: 'ᵃ', b: 'ᵇ', c: 'ᶜ', d: 'ᵈ', e: 'ᵉ', f: 'ᶠ', g: 'ᵍ', h: 'ʰ', i: 'ⁱ', j: 'ʲ', k: 'ᵏ',
  l: 'ˡ', m: 'ᵐ', n: 'ⁿ', o: 'ᵒ', p: 'ᵖ', r: 'ʳ', s: 'ˢ', t: 'ᵗ', u: 'ᵘ', v: 'ᵛ', w: 'ʷ',
  x: 'ˣ', y: 'ʸ', z: 'ᶻ',
};

const SUBSCRIPT: Record<string, string> = {
  '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄', '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
  '+': '₊', '-': '₋', '−': '₋', '=': '₌', '(': '₍', ')': '₎',
  a: 'ₐ', e: 'ₑ', h: 'ₕ', i: 'ᵢ', j: 'ⱼ', k: 'ₖ', l: 'ₗ', m: 'ₘ', n: 'ₙ', o: 'ₒ', p: 'ₚ',
  r: 'ᵣ', s: 'ₛ', t: 'ₜ', u: 'ᵤ', v: 'ᵥ', x: 'ₓ',
};

const VULGAR_FRACTIONS: Record<string, string> = {
  '1/2': '½',
  '1/3': '⅓',
  '2/3': '⅔',
  '1/4': '¼',
  '3/4': '¾',
  '1/5': '⅕',
  '2/5': '⅖',
  '3/5': '⅗',
  '4/5': '⅘',
  '1/6': '⅙',
  '5/6': '⅚',
  '1/8': '⅛',
  '3/8': '⅜',
  '5/8': '⅝',
  '7/8': '⅞',
};

const SYMBOLS: Record<string, string> = {
  rightarrow: '→', to: '→', leftarrow: '←', gets: '←', leftrightarrow: '↔',
  Rightarrow: '⇒', implies: '⇒', Leftarrow: '⇐', Leftrightarrow: '⇔', iff: '⇔',
  longrightarrow: '⟶', longleftarrow: '⟵', rightleftharpoons: '⇌', uparrow: '↑', downarrow: '↓',
  le: '≤', leq: '≤', ge: '≥', geq: '≥', ne: '≠', neq: '≠', pm: '±', mp: '∓', approx: '≈',
  sim: '∼', simeq: '≃', equiv: '≡', propto: '∝', times: '×', div: '÷', cdot: '·', ast: '∗',
  ll: '≪', gg: '≫', infty: '∞', partial: '∂', nabla: '∇', sum: '∑', prod: '∏', int: '∫',
  in: '∈', notin: '∉', subset: '⊂', subseteq: '⊆', supset: '⊃', cup: '∪', cap: '∩',
  forall: '∀', exists: '∃', emptyset: '∅', varnothing: '∅', therefore: '∴', because: '∵',
  angle: '∠', perp: '⊥', parallel: '∥', degree: '°', circ: '°', prime: '′',
  ldots: '…', dots: '…', cdots: '⋯',
  alpha: 'α', beta: 'β', gamma: 'γ', delta: 'δ', epsilon: 'ε', varepsilon: 'ε', zeta: 'ζ',
  eta: 'η', theta: 'θ', vartheta: 'ϑ', iota: 'ι', kappa: 'κ', lambda: 'λ', mu: 'μ', nu: 'ν',
  xi: 'ξ', pi: 'π', rho: 'ρ', sigma: 'σ', tau: 'τ', upsilon: 'υ', phi: 'φ', varphi: 'φ',
  chi: 'χ', psi: 'ψ', omega: 'ω',
  Gamma: 'Γ', Delta: 'Δ', Theta: 'Θ', Lambda: 'Λ', Xi: 'Ξ', Pi: 'Π', Sigma: 'Σ',
  Upsilon: 'Υ', Phi: 'Φ', Psi: 'Ψ', Omega: 'Ω',
};

const LETTER_LIKE = new Set([
  ...Object.keys(SYMBOLS).filter((name) => /^[\p{Script=Greek}]+$/u.test(SYMBOLS[name])),
  'partial',
  'nabla',
  'infty',
]);

const SYMBOL_RE = /\\([A-Za-z]+)(?![A-Za-z])/g;

function script(content: string, table: Record<string, string>, marker: string): string {
  const chars = [...content];
  if (chars.length > 0 && chars.every((ch) => table[ch] !== undefined)) {
    return chars.map((ch) => table[ch]).join('');
  }
  return chars.length > 1 ? `${marker}(${content})` : `${marker}${content}`;
}

function replaceSymbols(text: string): string {
  return text.replace(SYMBOL_RE, (match, name: string) => SYMBOLS[name] ?? match);
}

function wrapMathPart(part: string): string {
  return /^[\p{L}\p{N}.,²³⁺⁻₀-₉⁰-⁹]+$/u.test(part) ? part : `(${part})`;
}

function formatFraction(num: string, den: string): string {
  const cleanNum = num.trim();
  const cleanDen = den.trim();
  const vulgar = VULGAR_FRACTIONS[`${cleanNum}/${cleanDen}`];
  if (vulgar) return vulgar;
  return `${wrapMathPart(cleanNum)}/${wrapMathPart(cleanDen)}`;
}

function convertMath(expr: string): string {
  let out = expr;
  out = out.replace(/\\(?:text|mathrm|mathbf|mathit|textbf|textit|operatorname|mbox)\{([^{}]*)\}/g, '$1');
  out = out.replace(/\\(?:left|right)(?![A-Za-z])\s*/g, '');
  out = out.replace(/\\[,;:!]|\\q?quad/g, ' ');
  out = out.replace(/\^\{?\\circ\}?/g, '°');
  for (let previous = ''; previous !== out; ) {
    previous = out;
    out = out.replace(/\\[dt]?frac\{([^{}]*)\}\{([^{}]*)\}/g, (_, a: string, b: string) =>
      formatFraction(a, b),
    );
    out = out.replace(/\\sqrt\{([^{}]*)\}/g, (_, a: string) => `√${wrapMathPart(a)}`);
  }
  out = out.replace(/\\sqrt\s*(\S)/g, '√$1');
  out = out.replace(/\\([A-Za-z]+) (?=[\p{L}\p{N}])/gu, (match, name: string) =>
    LETTER_LIKE.has(name) ? SYMBOLS[name] : match,
  );
  out = replaceSymbols(out);
  out = out.replace(/\^\{([^{}]*)\}|\^(\S)/g, (_, group?: string, single?: string) =>
    script(group ?? single ?? '', SUPERSCRIPT, '^'),
  );
  out = out.replace(/_\{([^{}]*)\}|_(\S)/g, (_, group?: string, single?: string) =>
    script(group ?? single ?? '', SUBSCRIPT, '_'),
  );
  return out.replace(/[{}]/g, '');
}

function looksLikeMath(inner: string): boolean {
  return /[\\^_{}]/.test(inner) || /^[A-Za-z]$/.test(inner);
}

function convertProse(text: string): string {
  let out = text;
  out = out.replace(/\$\$([\s\S]+?)\$\$/g, (_, inner: string) => convertMath(inner.trim()));
  out = out.replace(/\\\[([\s\S]+?)\\\]/g, (_, inner: string) => convertMath(inner.trim()));
  out = out.replace(/\\\(([\s\S]+?)\\\)/g, (_, inner: string) => convertMath(inner.trim()));
  out = out.replace(/\$(?!\s)([^$\n]*?[^\s$])\$/g, (match, inner: string) =>
    looksLikeMath(inner) ? convertMath(inner) : match,
  );
  for (let previous = ''; previous !== out; ) {
    previous = out;
    out = out.replace(/\\[dt]?frac\{([^{}]*)\}\{([^{}]*)\}/g, (_, a: string, b: string) =>
      formatFraction(a, b),
    );
    out = out.replace(/\\sqrt\{([^{}]*)\}/g, (_, a: string) => `√${wrapMathPart(a)}`);
  }
  out = replaceSymbols(out);
  out = out.replace(
    /(?<=(?:^|[^\p{L}\p{N}_])(?:[A-Z][a-z]?)+)_(\{[^{}\s]*\}|\d+)(?![\p{L}_])/gu,
    (_, part: string) => script(part.replace(/^\{|\}$/g, ''), SUBSCRIPT, '_'),
  );
  out = out.replace(
    /(?<=[\p{L}\p{N})])\^(\{[^{}\s]*\}|[+\-−]|\d+)/gu,
    (_, part: string) => script(part.replace(/^\{|\}$/g, ''), SUPERSCRIPT, '^'),
  );
  return out;
}

export function latexToUnicode(input: string): string {
  const source = String(input ?? '');
  if (!/[\\$^_]/.test(source)) return source;
  return source
    .split(/(```[\s\S]*?```|`[^`\n]*`|https?:\/\/\S+)/)
    .map((part, index) => (index % 2 === 1 ? part : convertProse(part)))
    .join('');
}

const COLORS: Record<string, string> = {
  red: 'c_db342e',
  green: 'c_15a85f',
  orange: 'c_f27806',
  yellow: 'c_f7b503',
};

const BOLD = 'b';
const BIG = 'f_18';
const ITALIC = 'i';
const STRIKE = 's';

const ALIASES: Array<[RegExp, string]> = [
  [/\{(\/?(?:red|green|orange|yellow|do|xanh|cam|vang))\}/gi, '[$1]'],
  [/\[do\]/gi, '[red]'],
  [/\[\/do\]/gi, '[/red]'],
  [/\[xanh\]/gi, '[green]'],
  [/\[\/xanh\]/gi, '[/green]'],
  [/\[cam\]/gi, '[orange]'],
  [/\[\/cam\]/gi, '[/orange]'],
  [/\[vang\]/gi, '[yellow]'],
  [/\[\/vang\]/gi, '[/yellow]'],
];

const DEFAULT_MAX_CHARS = 2000;
const DEFAULT_MAX_STYLES = 40;
const DEFAULT_MAX_PAYLOAD_BYTES = 3000;
const MENTION_RESERVE_BYTES = 60;

function payloadBytes(chunk: ZaloFormattedChunk): number {
  const ats = (chunk.text.match(/@/g) || []).length;
  return (
    Buffer.byteLength(chunk.text, 'utf8') +
    Buffer.byteLength(JSON.stringify(chunk.styles), 'utf8') +
    ats * MENTION_RESERVE_BYTES
  );
}

export function formatZaloMarkdown(markdown: string): ZaloFormattedChunk {
  if (!markdown) return { text: '', styles: [] };

  let raw = latexToUnicode(String(markdown));
  for (const [pattern, replacement] of ALIASES) {
    raw = raw.replace(pattern, replacement);
  }

  const styles: ZaloTextStyleSpan[] = [];
  const outLines: string[] = [];
  let offset = 0;

  const lines = raw.split(/\r?\n/);
  let inCodeBlock = false;
  let prevBlank = false;

  for (let line of lines) {
    if (/^\s*```/.test(line)) {
      inCodeBlock = !inCodeBlock;
      continue;
    }

    if (inCodeBlock) {
      outLines.push(line);
      offset += line.length + 1;
      prevBlank = false;
      continue;
    }

    if (/^\s*([-*_])\1{2,}\s*$/.test(line)) {
      continue;
    }

    const isBlank = line.trim() === '';
    if (isBlank && prevBlank) continue;
    prevBlank = isBlank;

    let wholeLineStyles: string[] = [];

    const heading = line.match(/^\s*(#{1,6})\s+(.*)$/);
    if (heading) {
      line = heading[2];
      wholeLineStyles = [BOLD, BIG];
    }

    const quote = line.match(/^\s*>\s?(.*)$/);
    if (!heading && quote) {
      line = quote[1];
      wholeLineStyles = [ITALIC];
    }

    line = line.replace(/^(\s*)([-*•])\s+/, (_match, indent: string) =>
      indent.length >= 2 ? `${indent}• ` : `${indent}- `,
    );

    let listNumStart = 0;
    let listNumLen = 0;
    if (!heading) {
      const numMatch = line.match(/^(\s*)(\d+[.)]\s+)/);
      if (numMatch) {
        listNumStart = numMatch[1].length;
        listNumLen = numMatch[2].length;
      }
    }

    const { text, styles: lineStyles } = renderInline(line, offset);

    if (wholeLineStyles.length > 0 && text.length > 0) {
      for (const st of wholeLineStyles) {
        lineStyles.push({ start: offset, len: text.length, st });
      }
    }

    if (listNumLen > 0) {
      lineStyles.push({ start: offset + listNumStart, len: listNumLen, st: BOLD });
      lineStyles.push({ start: offset + listNumStart, len: listNumLen, st: BIG });
    }

    styles.push(...lineStyles);
    outLines.push(text);
    offset += text.length + 1;
  }

  return { text: outLines.join('\n'), styles };
}

function isHighSurrogate(code: number): boolean {
  return code >= 0xd800 && code <= 0xdbff;
}

function isLowSurrogate(code: number): boolean {
  return code >= 0xdc00 && code <= 0xdfff;
}

/**
 * Ensure `end` never splits a UTF-16 surrogate pair (`high` at `end - 1` and `low` at `end`).
 * Applied at every split point (MAX_CHARS, style-count boundary, and byte-budget shrink loop).
 */
function guardSurrogateBoundary(text: string, start: number, end: number): number {
  if (end <= start || end >= text.length) return Math.min(end, text.length);
  if (isHighSurrogate(text.charCodeAt(end - 1)) && isLowSurrogate(text.charCodeAt(end))) {
    if (end - 1 > start) {
      return end - 1;
    }
    return Math.min(text.length, end + 1);
  }
  return end;
}

function preferReadableBoundary(text: string, start: number, end: number): number {
  const safeEnd = guardSurrogateBoundary(text, start, end);
  if (safeEnd >= text.length) return text.length;

  const window = text.slice(start, safeEnd);
  for (const marker of ['\n\n', '\n', '. ', '; ', ', ', ' ']) {
    const idx = window.lastIndexOf(marker);
    if (idx > 0 && idx >= window.length * 0.6) {
      return guardSurrogateBoundary(text, start, start + idx + marker.length);
    }
  }
  return safeEnd;
}

function styleCountInRange(styles: ZaloTextStyleSpan[], start: number, end: number): number {
  return styles.filter((style) => style.start < end && style.start + style.len > start).length;
}

function lastStyleBoundaryBefore(
  styles: ZaloTextStyleSpan[],
  start: number,
  end: number,
  maxStyles: number,
): number | null {
  const boundaries = styles
    .flatMap((style) => [style.start, style.start + style.len])
    .filter((pos) => pos > start && pos < end)
    .sort((a, b) => b - a);
  return boundaries.find((pos) => styleCountInRange(styles, start, pos) <= maxStyles) ?? null;
}

function sliceStyledChunk(
  formatted: ZaloFormattedChunk,
  start: number,
  end: number,
): ZaloFormattedChunk {
  const styles: ZaloTextStyleSpan[] = [];
  for (const style of formatted.styles) {
    const styleStart = style.start;
    const styleEnd = style.start + style.len;
    if (styleStart >= end || styleEnd <= start) continue;

    const clippedStart = Math.max(styleStart, start);
    const clippedEnd = Math.min(styleEnd, end);
    if (clippedEnd > clippedStart) {
      styles.push({
        start: clippedStart - start,
        len: clippedEnd - clippedStart,
        st: style.st,
      });
    }
  }

  return { text: formatted.text.slice(start, end), styles };
}

function findChunkEnd(
  formatted: ZaloFormattedChunk,
  start: number,
  maxChars: number,
  maxStyles: number,
  maxPayloadBytes: number,
): number {
  const text = formatted.text;
  let end = Math.min(start + maxChars, text.length);
  end = preferReadableBoundary(text, start, end);

  while (styleCountInRange(formatted.styles, start, end) > maxStyles && end > start + 1) {
    const boundary =
      lastStyleBoundaryBefore(formatted.styles, start, end, maxStyles) ??
      Math.floor((start + end) / 2);
    const clamped = Math.max(start + 1, Math.min(boundary, end - 1, start + maxChars));
    end = guardSurrogateBoundary(text, start, clamped);
    if (end <= start + 1) break;
  }

  let bytes = payloadBytes(sliceStyledChunk(formatted, start, end));
  while (bytes > maxPayloadBytes && end > start + 1) {
    const target = start + Math.floor(((end - start) * maxPayloadBytes) / bytes);
    const candidate = Math.max(start + 1, Math.min(target, end - 1));
    const nextEnd = preferReadableBoundary(text, start, candidate);
    end = guardSurrogateBoundary(
      text,
      start,
      nextEnd < end ? nextEnd : Math.max(start + 1, end - 1),
    );
    const nextBytes = payloadBytes(sliceStyledChunk(formatted, start, end));
    if (nextBytes >= bytes && end <= start + 2) break;
    bytes = nextBytes;
  }

  return guardSurrogateBoundary(text, start, end);
}

export function chunkStyledMessage(
  text: string,
  styles: ZaloTextStyleSpan[],
  maxChars = DEFAULT_MAX_CHARS,
  maxStyles = DEFAULT_MAX_STYLES,
  maxPayloadBytes = DEFAULT_MAX_PAYLOAD_BYTES,
): ZaloFormattedChunk[] {
  const formatted: ZaloFormattedChunk = { text, styles };
  if (!formatted.text.trim()) return [];
  if (
    formatted.text.length <= maxChars &&
    formatted.styles.length <= maxStyles &&
    payloadBytes(formatted) <= maxPayloadBytes
  ) {
    return [formatted];
  }

  const chunks: ZaloFormattedChunk[] = [];
  let start = 0;
  while (start < formatted.text.length) {
    const end = findChunkEnd(formatted, start, maxChars, maxStyles, maxPayloadBytes);
    const safeEnd = end > start ? end : Math.min(formatted.text.length, start + 1);
    chunks.push(sliceStyledChunk(formatted, start, safeEnd));
    start = safeEnd;
  }

  return chunks.filter((chunk) => chunk.text.trim().length > 0);
}

export function formatAndChunkZaloMarkdown(
  markdown: string,
  maxChars = DEFAULT_MAX_CHARS,
  maxStyles = DEFAULT_MAX_STYLES,
  maxPayloadBytes = DEFAULT_MAX_PAYLOAD_BYTES,
): ZaloFormattedChunk[] {
  if (!markdown) return [];
  const formatted = formatZaloMarkdown(String(markdown).trim());
  if (!formatted.text.trim()) return [];
  return chunkStyledMessage(
    formatted.text,
    formatted.styles,
    maxChars,
    maxStyles,
    maxPayloadBytes,
  );
}

function renderInline(line: string, base: number): ZaloFormattedChunk {
  const styles: ZaloTextStyleSpan[] = [];
  let out = '';
  let i = 0;

  const push = (start: number, len: number, st: string): void => {
    if (len > 0) styles.push({ start: base + start, len, st });
  };

  while (i < line.length) {
    const rest = line.slice(i);

    const color = matchColorTag(rest);
    if (color) {
      const inner = renderInline(color.inner, base + out.length);
      const start = out.length;
      out += inner.text;
      styles.push(...inner.styles);
      push(start, inner.text.length, COLORS[color.name]);
      i += color.consumed;
      continue;
    }

    const link = rest.match(/^\[([^\]\n]+)\]\(([^)\s]+)\)/);
    if (link) {
      const label = link[1];
      const url = link[2];
      const start = out.length;
      out += label;
      push(start, label.length, BOLD);
      out += ` (${url})`;
      i += link[0].length;
      continue;
    }

    const strike = rest.match(/^~~([\s\S]+?)~~/);
    if (strike) {
      const inner = renderInline(strike[1], base + out.length);
      const start = out.length;
      out += inner.text;
      styles.push(...inner.styles);
      push(start, inner.text.length, STRIKE);
      i += strike[0].length;
      continue;
    }

    const bold = rest.match(/^(\*\*|__)([\s\S]+?)\1/);
    if (bold) {
      const inner = renderInline(bold[2], base + out.length);
      const start = out.length;
      out += inner.text;
      styles.push(...inner.styles);
      push(start, inner.text.length, BOLD);
      i += bold[0].length;
      continue;
    }

    const code = rest.match(/^`([^`\n]+)`/);
    if (code) {
      const start = out.length;
      out += code[1];
      push(start, code[1].length, BOLD);
      i += code[0].length;
      continue;
    }

    const italic = rest.match(/^([*_])([^\s*_][^*_\n]*?)\1/);
    if (italic && isWordBoundary(line, i)) {
      const inner = renderInline(italic[2], base + out.length);
      const start = out.length;
      out += inner.text;
      styles.push(...inner.styles);
      push(start, inner.text.length, ITALIC);
      i += italic[0].length;
      continue;
    }

    out += line[i];
    i += 1;
  }

  return { text: out, styles };
}

function matchColorTag(
  rest: string,
): { name: string; inner: string; consumed: number } | null {
  for (const name of Object.keys(COLORS)) {
    const open = `[${name}]`;
    if (rest.slice(0, open.length).toLowerCase() !== open) continue;
    const closeIdx = rest.toLowerCase().indexOf(`[/${name}]`, open.length);
    if (closeIdx === -1) continue;
    return {
      name,
      inner: rest.slice(open.length, closeIdx),
      consumed: closeIdx + name.length + 3,
    };
  }
  return null;
}

function isWordBoundary(line: string, i: number): boolean {
  if (i === 0) return true;
  return /[\s(["'—–-]/.test(line[i - 1]);
}

/**
 * True only when `err.code` is an integer numeric error code returned by Zalo (`zca-js`),
 * matching upstream `/^-?\d+$/`. Callers must still exclude `isDeadSessionError(err)` (code 600).
 */
export function isZaloNumericErrorCode(err: unknown): boolean {
  if (!err || typeof err !== 'object') return false;
  const code = (err as Record<string, unknown>).code;
  if (typeof code !== 'number' && typeof code !== 'string') return false;
  return /^-?\d+$/.test(String(code).trim());
}

export interface ZaloGroupMemberCandidate {
  id?: string;
  uid?: string;
  name?: string;
  displayName?: string;
  zaloName?: string;
}

export interface ResolvedZaloMention {
  pos: number;
  len: number;
  uid: string;
}

const NAME_CHAR_RE = /[\p{L}\p{N}_]/u;
const NAME_CONTINUES_RE = /^ \p{Lu}/u;
const ALL_TOKEN_RE = /^all(?![\p{L}\p{N}_])/iu;
export const MENTION_ALL_UID = '-1';

/**
 * Resolves plain `@<Tên>` and `@All` tokens inside a formatted chunk `msg` into
 * Zalo UTF-16 `{ pos, len, uid }` mention offsets.
 *
 * - Skips `selfUid` and ambiguous names (`uids.size !== 1`).
 * - Matches longest names first so `@Nguyễn Văn A` never matches `@Nguyễn Văn`.
 * - Protects single-word names against `NAME_CONTINUES_RE` (`@Trang Nguyễn` does not tag `Trang`).
 * - Skips matches at the trailing edge of a chunk (`after.trim() === ''`) when `continuesInNextChunk` is true.
 */
export function findMentions(
  msg: string,
  members: readonly ZaloGroupMemberCandidate[],
  opts?: {
    selfUid?: string;
    continuesInNextChunk?: boolean;
    canMentionAll?: boolean;
  },
): ResolvedZaloMention[] {
  const text = String(msg ?? '');
  if (!text.includes('@')) return [];

  const selfUid = String(opts?.selfUid ?? '');
  const continuesInNextChunk = Boolean(opts?.continuesInNextChunk);
  const canMentionAll = Boolean(opts?.canMentionAll);

  const byLower = new Map<string, { raw: string; uids: Set<string> }>();
  for (const m of members || []) {
    const uid = String(m?.uid ?? m?.id ?? '').trim();
    if (!uid || uid === selfUid) continue;
    const rawCandidates = [m?.name, m?.displayName, m?.zaloName];
    for (const candidate of rawCandidates) {
      const raw = String(candidate ?? '').trim().normalize('NFC');
      if (!raw) continue;
      const lower = raw.toLocaleLowerCase('vi');
      let slot = byLower.get(lower);
      if (!slot) {
        slot = { raw, uids: new Set<string>() };
        byLower.set(lower, slot);
      }
      slot.uids.add(uid);
    }
  }

  const uniqueNames = [...byLower.entries()]
    .filter(([, v]) => v.uids.size === 1)
    .map(([lower, v]) => ({
      lower,
      raw: v.raw,
      uid: [...v.uids][0]!,
    }))
    .sort((a, b) => b.lower.length - a.lower.length);

  if (uniqueNames.length === 0 && !canMentionAll) return [];

  const lowerText = text.toLocaleLowerCase('vi');
  const mentions: ResolvedZaloMention[] = [];
  let cursor = 0;

  while (cursor < text.length) {
    const at = text.indexOf('@', cursor);
    if (at === -1) break;
    if (at > 0 && NAME_CHAR_RE.test(text[at - 1]!)) {
      cursor = at + 1;
      continue;
    }

    const tail = text.slice(at + 1);
    if (canMentionAll && ALL_TOKEN_RE.test(tail)) {
      const len = 4; // '@All'
      const after = text.slice(at + len);
      if (!(continuesInNextChunk && after.trim() === '')) {
        mentions.push({ pos: at, len, uid: MENTION_ALL_UID });
        cursor = at + len;
        continue;
      }
    }

    const tailLower = lowerText.slice(at + 1);
    let matched: { pos: number; len: number; uid: string } | null = null;
    for (const m of uniqueNames) {
      if (!tailLower.startsWith(m.lower)) continue;
      const len = 1 + m.lower.length;
      const after = text.slice(at + len);
      if (after && NAME_CHAR_RE.test(after[0]!)) continue;
      if (continuesInNextChunk && after.trim() === '') continue;
      if (!m.raw.includes(' ') && NAME_CONTINUES_RE.test(after)) continue;
      matched = { pos: at, len, uid: m.uid };
      break;
    }

    if (matched) {
      mentions.push(matched);
      cursor = matched.pos + matched.len;
    } else {
      cursor = at + 1;
    }
  }

  return mentions;
}
