import fs from 'fs';
import path from 'path';

export function readJsonFile<T>(relativePath: string, defaultValue: T): T {
  const fullPath = path.join(process.cwd(), relativePath);

  try {
    if (!fs.existsSync(fullPath)) {
      return defaultValue;
    }

    const raw = fs.readFileSync(fullPath, 'utf-8');
    return JSON.parse(raw) as T;
  } catch {
    return defaultValue;
  }
}

export function writeJsonFile<T>(relativePath: string, data: T): void {
  const fullPath = path.join(process.cwd(), relativePath);
  const dir = path.dirname(fullPath);

  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  fs.writeFileSync(fullPath, JSON.stringify(data, null, 2), 'utf-8');
}
