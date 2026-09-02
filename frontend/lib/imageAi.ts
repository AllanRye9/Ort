// Client for the image-AI Cloudflare Worker used to auto-fill listing
// fields from an uploaded photo. The worker exposes three endpoints:
//   GET  /classify?url=...   -> ResNet-50 label predictions
//   GET  /identify?url=...   -> vision-language model description
//   POST /describe           -> expands text/structured data into a longer description
//
// Configure via NEXT_PUBLIC_IMAGE_AI_URL (see .env.example). Falls back to
// the deployed worker so the feature works out of the box in development.
//
// The worker sets `Access-Control-Allow-Origin: *`, so these calls are made
// directly from the browser — no backend proxy is required.

const DEFAULT_IMAGE_AI_URL = 'https://apkit.allan-rye-999.workers.dev';

const IMAGE_AI_URL = (process.env.NEXT_PUBLIC_IMAGE_AI_URL || DEFAULT_IMAGE_AI_URL).replace(/\/+$/, '');

export interface ClassifyPrediction {
  label: string;
  confidence: number;
}

export interface ClassifyResult {
  topPrediction: ClassifyPrediction | null;
  predictions: ClassifyPrediction[];
  inferenceTimeMs: number;
}

export interface IdentifyResult {
  description: string;
  inferenceTimeMs: number;
}

export interface DescribeResult {
  description: string;
  preset: string;
  inferenceTimeMs: number;
}

export class ImageAiError extends Error {}

interface WorkerJsonResponse {
  success: boolean;
  error?: string;
  [key: string]: unknown;
}

async function requestJson(path: string, init?: RequestInit): Promise<WorkerJsonResponse> {
  let res: Response;
  try {
    res = await fetch(`${IMAGE_AI_URL}${path}`, init);
  } catch {
    throw new ImageAiError('Could not reach the image AI service. Check your connection and try again.');
  }

  const data = (await res.json().catch(() => null)) as WorkerJsonResponse | null;

  if (!res.ok || !data || data.success === false) {
    throw new ImageAiError((data && data.error) || `Image AI request failed (${res.status}).`);
  }

  return data;
}

/** Runs ResNet-50 classification against an already-hosted (publicly reachable) image URL. */
export async function classifyImageUrl(imageUrl: string): Promise<ClassifyResult> {
  const data = await requestJson(`/classify?url=${encodeURIComponent(imageUrl)}`);
  return {
    topPrediction: (data.topPrediction as ClassifyPrediction | null) ?? null,
    predictions: (data.predictions as ClassifyPrediction[]) ?? [],
    inferenceTimeMs: (data.inferenceTimeMs as number) ?? 0,
  };
}

/** Runs the vision-language model to produce a natural-language identification of an image URL. */
export async function identifyImageUrl(imageUrl: string): Promise<IdentifyResult> {
  const data = await requestJson(`/identify?url=${encodeURIComponent(imageUrl)}`);
  return {
    description: (data.description as string) ?? '',
    inferenceTimeMs: (data.inferenceTimeMs as number) ?? 0,
  };
}

/** Expands short text/structured data into a longer, formatted listing description. */
export async function describeFromText(text: string, preset = 'detailed'): Promise<DescribeResult> {
  const data = await requestJson('/describe', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text, preset }),
  });
  return {
    description: (data.description as string) ?? '',
    preset: (data.preset as string) ?? preset,
    inferenceTimeMs: (data.inferenceTimeMs as number) ?? 0,
  };
}
