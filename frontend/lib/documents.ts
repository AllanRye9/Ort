import { api } from '@/lib/api';

/**
 * Downloads a UserDocument through the authenticated
 * GET /upload/documents/:id/file route and triggers a browser save-as.
 *
 * Document files are deliberately not reachable via a plain URL (the public
 * image proxy and the raw /uploads static mount both refuse the
 * "documents/" storage prefix) — the backend route checks ownership/
 * visibility before streaming anything, so downloads must go through an
 * authenticated request rather than a plain <a href> link.
 */
export async function downloadUserDocument(documentId: string, fileName: string): Promise<void> {
  const { data } = await api.get(`/upload/documents/${documentId}/file`, { responseType: 'blob' });
  const url = URL.createObjectURL(data);
  const link = document.createElement('a');
  link.href = url;
  link.download = fileName || 'document';
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}
