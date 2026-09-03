// Heuristic keyword matcher that maps free-text hints (e.g. an AI image
// classification label or identification description) onto one of the
// site's existing listing categories. Used by the "Auto-fill from photo"
// feature on the create-listing page — never applied to the form
// automatically, only offered as a suggestion the seller must accept.

import { Category } from '@/lib/types';

export interface CategoryMatch {
  id: string;
  label: string;
}

interface FlatCategory {
  id: string;
  label: string;
  tokens: string[];
}

export function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((word) => word.length > 2);
}

function flattenCategories(categories: Category[]): FlatCategory[] {
  const flat: FlatCategory[] = [];
  for (const category of categories) {
    flat.push({ id: category.id, label: category.name, tokens: tokenize(category.name) });
    for (const child of category.children ?? []) {
      flat.push({
        id: child.id,
        label: `${category.name} / ${child.name}`,
        tokens: [...tokenize(category.name), ...tokenize(child.name)],
      });
    }
  }
  return flat;
}

/**
 * Scores every category (and subcategory) against the given hint strings
 * and returns the best match by overlapping keyword count. Ties are broken
 * in favor of the more specific (subcategory) match. Returns null when no
 * category shares any keyword with the hints.
 */
export function suggestCategory(categories: Category[], hints: string[]): CategoryMatch | null {
  const hintWords = new Set(hints.flatMap((hint) => tokenize(hint)));
  if (hintWords.size === 0) return null;

  const flat = flattenCategories(categories);
  let best: FlatCategory | null = null;
  let bestScore = 0;

  for (const candidate of flat) {
    let score = 0;
    for (const token of candidate.tokens) {
      if (hintWords.has(token)) score += 1;
    }
    if (score === 0) continue;
    if (score > bestScore || (score === bestScore && best && candidate.label.length > best.label.length)) {
      bestScore = score;
      best = candidate;
    }
  }

  return best ? { id: best.id, label: best.label } : null;
}

// Common, near-content-free words that show up in almost every AI image
// description ("a photo of...", "this appears to be...") and would
// otherwise inflate the overlap score between two completely different
// products (e.g. a laptop photo and a shoe photo both mention "black" and
// "image").
const STOP_WORDS = new Set([
  'the', 'and', 'with', 'for', 'this', 'that', 'from', 'photo', 'image',
  'picture', 'shows', 'showing', 'appears', 'appear', 'looks', 'like',
  'item', 'product', 'object', 'view', 'close', 'background', 'white',
  'black', 'color', 'colour', 'new', 'used', 'good', 'condition', 'set',
  'one', 'two', 'small', 'large', 'and', 'front', 'side', 'top', 'has',
]);

function significantTokens(hints: string[]): Set<string> {
  const tokens = hints.flatMap((hint) => tokenize(hint)).filter((t) => !STOP_WORDS.has(t));
  return new Set(tokens);
}

export interface ItemMatchResult {
  /** true when the two sets of hints plausibly describe the same kind of item. */
  isMatch: boolean;
  /** 0–1 Jaccard-style overlap score between the two hint sets, for debugging/UI. */
  score: number;
}

/**
 * Compares the AI-derived hints (classify label + identify description) for
 * two photos and decides whether they plausibly show the same kind of item
 * (e.g. two photos of the same laptop, or two phones of the same category)
 * versus an unrelated photo accidentally attached to the listing.
 *
 * This is a lightweight keyword-overlap heuristic, not true visual
 * similarity — it's intentionally forgiving (any shared meaningful keyword
 * counts) since photo angles/lighting/AI phrasing vary a lot for the same
 * physical item.
 */
export function matchesSameItem(baseHints: string[], otherHints: string[]): ItemMatchResult {
  const baseTokens = significantTokens(baseHints);
  const otherTokens = significantTokens(otherHints);
  if (baseTokens.size === 0 || otherTokens.size === 0) return { isMatch: true, score: 0 }; // not enough signal — don't falsely flag
  let overlap = 0;
  for (const t of otherTokens) if (baseTokens.has(t)) overlap += 1;
  const union = new Set([...baseTokens, ...otherTokens]).size;
  const score = union === 0 ? 0 : overlap / union;
  return { isMatch: overlap > 0, score };
}
