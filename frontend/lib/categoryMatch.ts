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

function tokenize(text: string): string[] {
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
