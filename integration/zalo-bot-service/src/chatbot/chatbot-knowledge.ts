// A knowledge snippet may carry a per-account targeting tag on its own line:
//   [Accounts] id1, id2
// No tag (or empty) means the document applies to every account. The tag is an
// operator-only control and must be stripped before the snippet reaches the AI.
const ACCOUNTS_LINE = /(?:^|\n)\[Accounts\][^\n]*/;

/**
 * Keep only the knowledge snippets that apply to `accountId` and strip the
 * `[Accounts]` targeting tag from each so it never reaches the AI prompt.
 */
export function filterKnowledgeSnippetsForAccount(
  snippets: string[],
  accountId: string,
): string[] {
  const result: string[] = [];
  for (const snippet of snippets) {
    if (typeof snippet !== 'string') continue;
    const match = snippet.match(ACCOUNTS_LINE);
    if (match) {
      const ids = match[0]
        .replace(/\s*\[Accounts\]/, '')
        .split(',')
        .map((value) => value.trim())
        .filter(Boolean);
      if (ids.length > 0 && !ids.includes(accountId)) continue;
    }
    const cleaned = snippet.replace(ACCOUNTS_LINE, '').trimEnd();
    if (cleaned.trim().length > 0) result.push(cleaned);
  }
  return result;
}
