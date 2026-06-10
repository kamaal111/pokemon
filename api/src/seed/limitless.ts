import z from 'zod';

import {
  CARD_SETS_REGION_NAME,
  CARD_SETS_SOURCE_NAME,
  LIMITLESS_JP_CARD_SETS_URL,
} from './constants.ts';
import type { PokemonCardSet } from './types.ts';

const CardSetCodeSchema = z
  .string()
  .trim()
  .regex(/^(?=.*[a-z])[a-z0-9]{1,8}$/i);
const RegexCaptureSchema = z.string();

const CardSetSchema = z.object({
  code: z.string().trim().min(1),
  name: z.string().trim().min(1),
  region: z.literal(CARD_SETS_REGION_NAME),
  source: z.literal(CARD_SETS_SOURCE_NAME),
  ptcgoCode: z.null(),
});

export async function fetchLimitlessJapaneseCardSets(
  fetchImpl: typeof fetch,
): Promise<PokemonCardSet[]> {
  const response = await fetchImpl(LIMITLESS_JP_CARD_SETS_URL);
  if (!response.ok) {
    throw new Error(`Failed to fetch ${LIMITLESS_JP_CARD_SETS_URL}: ${response.status}`);
  }

  return parseLimitlessJapaneseCardSets(await response.text());
}

export function parseLimitlessJapaneseCardSets(html: string): PokemonCardSet[] {
  const cardSetsByCode = new Map<string, PokemonCardSet>();
  const rowMatches = html.matchAll(/<tr\b[^>]*>([\s\S]*?)<\/tr>/gi);
  for (const rowMatch of rowMatches) {
    const rowHtml = RegexCaptureSchema.parse(rowMatch[1]);
    const cardSet = parseLimitlessJapaneseCardSetRow(rowHtml);
    if (cardSet == null) {
      continue;
    }

    cardSetsByCode.set(cardSet.code, cardSet);
  }

  if (cardSetsByCode.size > 0) {
    return cardSetsByCode
      .values()
      .toArray()
      .toSorted((left, right) => left.code.localeCompare(right.code));
  }

  return parseLimitlessJapaneseCardSetAnchors(html);
}

function parseLimitlessJapaneseCardSetRow(rowHtml: string): PokemonCardSet | null {
  const anchorMatch = rowHtml.match(
    /<a\b[^>]*href="\/cards\/jp\/([^"#?/]+)"[^>]*>([\s\S]*?)<\/a>/i,
  );
  if (anchorMatch == null) {
    return null;
  }
  const codeCandidate = RegexCaptureSchema.parse(anchorMatch[1]);
  const linkTextCandidate = RegexCaptureSchema.parse(anchorMatch[2]);

  const code = normalizeCardSetCode(codeCandidate);
  if (code == null) {
    return null;
  }

  const cells = rowHtml
    .matchAll(/<td\b[^>]*>([\s\S]*?)<\/td>/gi)
    .map((match) => cleanHtmlText(RegexCaptureSchema.parse(match[1])))
    .filter((cell) => cell.length > 0)
    .toArray();
  const linkText = cleanHtmlText(linkTextCandidate);
  const name = cleanCardSetName(cells[0] ?? linkText, code);

  return CardSetSchema.parse({
    code,
    name,
    region: CARD_SETS_REGION_NAME,
    source: CARD_SETS_SOURCE_NAME,
    ptcgoCode: null,
  });
}

function parseLimitlessJapaneseCardSetAnchors(html: string): PokemonCardSet[] {
  const cardSetsByCode = new Map<string, PokemonCardSet>();
  const anchorMatches = html.matchAll(
    /<a\b[^>]*href="\/cards\/jp\/([^"#?/]+)"[^>]*>([\s\S]*?)<\/a>/gi,
  );
  for (const anchorMatch of anchorMatches) {
    const codeCandidate = RegexCaptureSchema.parse(anchorMatch[1]);
    const linkTextCandidate = RegexCaptureSchema.parse(anchorMatch[2]);
    const code = normalizeCardSetCode(codeCandidate);
    if (code == null) {
      continue;
    }

    const linkText = cleanHtmlText(linkTextCandidate);
    const cardSet = CardSetSchema.parse({
      code,
      name: cleanCardSetName(linkText, code),
      region: CARD_SETS_REGION_NAME,
      source: CARD_SETS_SOURCE_NAME,
      ptcgoCode: null,
    });
    cardSetsByCode.set(cardSet.code, cardSet);
  }

  return cardSetsByCode
    .values()
    .toArray()
    .toSorted((left, right) => left.code.localeCompare(right.code));
}

function normalizeCardSetCode(value: string): string | null {
  const parsedCode = CardSetCodeSchema.safeParse(value);
  if (!parsedCode.success) {
    return null;
  }

  return parsedCode.data.toLowerCase();
}

function cleanCardSetName(value: string, code: string): string {
  const caseInsensitiveCode = new RegExp(`\\b${escapeRegExp(code)}\\b`, 'i');
  const name = value
    .replace(caseInsensitiveCode, '')
    .replace(/\b\d{2} [A-Z][a-z]{2} \d{2}\b.*$/u, '')
    .trim();
  if (name.length === 0) {
    return code;
  }

  return name;
}

function cleanHtmlText(value: string): string {
  return value
    .replace(/<[^>]*>/gu, ' ')
    .replace(/&amp;/gu, '&')
    .replace(/&nbsp;/gu, ' ')
    .replace(/\s+/gu, ' ')
    .trim();
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/gu, '\\$&');
}
