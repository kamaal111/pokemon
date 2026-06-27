import { describe, expect, test } from 'vitest';

import { fetchLimitlessJapaneseCardSets, parseLimitlessJapaneseCardSets } from './limitless.ts';
import { LIMITLESS_JP_CARD_SETS_URL } from './constants.ts';

describe('fetchLimitlessJapaneseCardSets', () => {
  test('fails clearly when the Limitless set index request fails', async () => {
    await expect(
      fetchLimitlessJapaneseCardSets(() =>
        Promise.resolve(new Response('unavailable', { status: 503 })),
      ),
    ).rejects.toThrow(`Failed to fetch ${LIMITLESS_JP_CARD_SETS_URL}: 503`);
  });
});

describe('parseLimitlessJapaneseCardSets', () => {
  test('extracts Japanese printed set codes from the Limitless set index', () => {
    const cardSets = parseLimitlessJapaneseCardSets(`
      <table>
        <tr>
          <td><a href="/cards/jp/M2a">Mega Dream ex M2a</a></td>
          <td><a href="/cards/jp/M2a">28 Nov 25</a></td>
          <td><a href="/cards/jp/M2a">250</a></td>
        </tr>
        <tr>
          <td><a href="/cards/jp/SV8a">Terastal Fest ex SV8a</a></td>
          <td><a href="/cards/jp/SV8a">06 Dec 24</a></td>
          <td><a href="/cards/jp/SV8a">237</a></td>
        </tr>
        <tr>
          <td><a href="/cards/jp/SV4a">Shiny Treasure ex SV4a</a></td>
          <td><a href="/cards/jp/SV4a">01 Dec 23</a></td>
          <td><a href="/cards/jp/SV4a">360</a></td>
        </tr>
      </table>
    `);

    expect(cardSets).toEqual([
      {
        code: 'm2a',
        name: 'Mega Dream ex',
        region: 'jp',
        source: 'limitless-tcg',
        ptcgoCode: null,
      },
      {
        code: 'sv4a',
        name: 'Shiny Treasure ex',
        region: 'jp',
        source: 'limitless-tcg',
        ptcgoCode: null,
      },
      {
        code: 'sv8a',
        name: 'Terastal Fest ex',
        region: 'jp',
        source: 'limitless-tcg',
        ptcgoCode: null,
      },
    ]);
  });

  test('falls back to anchors when the page has no table rows', () => {
    const cardSets = parseLimitlessJapaneseCardSets(`
      <nav>
        <a href="/cards/jp/123">Number-only code 123</a>
        <a href="/cards/jp/M2a">Mega Dream ex M2a 28 Nov 25 250</a>
        <a href="/cards/jp/SV8a">Terastal Fest ex SV8a 06 Dec 24 237</a>
      </nav>
    `);

    expect(cardSets).toEqual([
      {
        code: 'm2a',
        name: 'Mega Dream ex',
        region: 'jp',
        source: 'limitless-tcg',
        ptcgoCode: null,
      },
      {
        code: 'sv8a',
        name: 'Terastal Fest ex',
        region: 'jp',
        source: 'limitless-tcg',
        ptcgoCode: null,
      },
    ]);
  });

  test('keeps anchor-only sets with valid set codes', () => {
    const cardSets = parseLimitlessJapaneseCardSets(`
      <a href="/cards/jp/SVOD">ex Starter Set Steven&apos;s Beldum &amp; Metagross ex SVOD</a>
    `);

    expect(cardSets).toEqual([
      {
        code: 'svod',
        name: 'ex Starter Set Steven&apos;s Beldum & Metagross ex',
        region: 'jp',
        source: 'limitless-tcg',
        ptcgoCode: null,
      },
    ]);
  });

  test('deduplicates by normalized code and ignores invalid set links', () => {
    const cardSets = parseLimitlessJapaneseCardSets(`
      <table>
        <tr>
          <td><a href="/cards/jp/123">Number-only code 123</a></td>
        </tr>
        <tr>
          <td><span>No set link</span></td>
        </tr>
        <tr>
          <td><a href="/cards/jp/SV8a">First Name SV8a</a></td>
          <td>06 Dec 24</td>
          <td>237</td>
        </tr>
        <tr>
          <td><a href="/cards/jp/sv8a">Updated Name sv8a</a></td>
          <td>07 Dec 24</td>
          <td>238</td>
        </tr>
      </table>
    `);

    expect(cardSets).toEqual([
      {
        code: 'sv8a',
        name: 'Updated Name',
        region: 'jp',
        source: 'limitless-tcg',
        ptcgoCode: null,
      },
    ]);
  });

  test('keeps rows without relying on optional page metadata', () => {
    const cardSets = parseLimitlessJapaneseCardSets(`
      <table>
        <tr>
          <td><a href="/cards/jp/M2a">M2a</a></td>
          <td>28 Foo 25</td>
          <td>No count</td>
        </tr>
        <tr>
          <td><a href="/cards/jp/SVOD">ex Starter Set Steven&apos;s Beldum &amp; Metagross ex SVOD</a></td>
        </tr>
        <tr>
          <th><a href="/cards/jp/SVG">Special Deck Set ex Venusaur &amp; Charizard &amp; Blastoise SVG</a></th>
        </tr>
      </table>
    `);

    expect(cardSets).toEqual([
      {
        code: 'm2a',
        name: 'm2a',
        region: 'jp',
        source: 'limitless-tcg',
        ptcgoCode: null,
      },
      {
        code: 'svg',
        name: 'Special Deck Set ex Venusaur & Charizard & Blastoise',
        region: 'jp',
        source: 'limitless-tcg',
        ptcgoCode: null,
      },
      {
        code: 'svod',
        name: 'ex Starter Set Steven&apos;s Beldum & Metagross ex',
        region: 'jp',
        source: 'limitless-tcg',
        ptcgoCode: null,
      },
    ]);
  });
});
