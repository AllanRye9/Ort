'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';

/**
 * Fetches a UserDocument's actual file content through the authenticated
 * GET /upload/documents/:id/file route (not the raw `fileUrl` on the
 * document — that path is deliberately blocked on the backend for
 * documents) and exposes it as a local `blob:` URL suitable for
 * <img>/<iframe>/<a> src or href.
 *
 * The backend route checks ownership/visibility before streaming anything,
 * so this only succeeds for the caller's own documents, a document marked
 * public, or an admin. On failure (403/404/network error) `url` stays null
 * so callers can show a fallback instead of a broken preview.
 *
 * The object URL is revoked whenever the document changes or the component
 * unmounts, so blob memory doesn't accumulate across views.
 */
export function useDocumentFileUrl(documentId: string | null | undefined) {
  const [url, setUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  useEffect(() => {
    if (!documentId) {
      setUrl(null);
      setLoading(false);
      setError(false);
      return;
    }

    let cancelled = false;
    let objectUrl: string | null = null;
    setLoading(true);
    setError(false);

    api
      .get(`/upload/documents/${documentId}/file`, { responseType: 'blob' })
      .then(({ data }) => {
        if (cancelled) return;
        objectUrl = URL.createObjectURL(data);
        setUrl(objectUrl);
      })
      .catch(() => {
        if (cancelled) return;
        setUrl(null);
        setError(true);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [documentId]);

  return { url, loading, error };
}
