import test from 'node:test';
import assert from 'node:assert/strict';
import { filterKnowledgeSnippetsForAccount } from './chatbot-knowledge.js';

test('untagged snippets apply to every account and are returned unchanged', () => {
  assert.deepEqual(
    filterKnowledgeSnippetsForAccount(['Bảng giá A', 'Catalogue B'], 'acc-1'),
    ['Bảng giá A', 'Catalogue B'],
  );
});

test('tagged snippet is kept for a listed account and the tag is stripped', () => {
  assert.deepEqual(
    filterKnowledgeSnippetsForAccount(
      ['Nội dung\n[Accounts] acc-1, acc-2'],
      'acc-1',
    ),
    ['Nội dung'],
  );
});

test('tagged snippet is dropped for an account not in the list', () => {
  assert.deepEqual(
    filterKnowledgeSnippetsForAccount(
      ['Riêng acc-2\n[Accounts] acc-2'],
      'acc-1',
    ),
    [],
  );
});

test('mixed list filters per account', () => {
  const snippets = [
    'Chung cho mọi tài khoản',
    'Chỉ acc-1\n[Accounts] acc-1',
    'Chỉ acc-2\n[Accounts] acc-2',
  ];
  assert.deepEqual(filterKnowledgeSnippetsForAccount(snippets, 'acc-1'), [
    'Chung cho mọi tài khoản',
    'Chỉ acc-1',
  ]);
});
