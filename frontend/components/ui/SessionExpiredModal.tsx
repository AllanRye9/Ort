'use client';

import { useState, useEffect, useCallback } from 'react';
import axios from 'axios';
import { useAuth } from '@/context/AuthContext';
import { API_URL } from '@/lib/api';
import { setAuthSession } from '@/lib/authStorage';
import { scheduleProactiveRefresh } from '@/lib/sessionRefreshScheduler';
import {
  registerSessionExpiredHandler,
  unregisterSessionExpiredHandler,
  resolveReauth,
  rejectReauth,
} from '@/lib/sessionExpiry';

/**
 * Mounted once, globally (see PublicShell), never rendering anything until
 * lib/api.ts's response interceptor actually needs it: a request 401'd, the
 * silent background refresh failed too (refresh token expired/invalid), and
 * the user was genuinely mid-session when it happened.
 *
 * Rather than the old behavior — clear the session and hard-navigate to
 * /auth/login, which throws away whatever the user had open (e.g. an
 * unsaved "Post a listing" form) — this shows a lightweight sign-in prompt
 * on top of the current page. On success, the page never unmounted, so
 * every bit of form state, uploaded-but-not-yet-submitted images, etc. is
 * still exactly where the user left it, and the request that originally
 * failed is retried automatically.
 */
export default function SessionExpiredModal() {
  const { refreshUser } = useAuth();
  const [open, setOpen] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const handleOpen = useCallback(() => {
    setError('');
    setOpen(true);
  }, []);

  useEffect(() => {
    registerSessionExpiredHandler(handleOpen);
    return () => unregisterSessionExpiredHandler(handleOpen);
  }, [handleOpen]);

  useEffect(() => {
    if (open) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    return () => { document.body.style.overflow = ''; };
  }, [open]);

  const close = () => {
    setOpen(false);
    setEmail('');
    setPassword('');
    setError('');
  };

  const handleSignIn = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) {
      setError('Please enter your email and password.');
      return;
    }
    setSubmitting(true);
    setError('');
    try {
      // Deliberately a raw axios call, not the shared `api` instance. `api`
      // carries the 401-refresh-retry interceptor that this very modal is
      // registered with (see lib/sessionExpiry.ts) — the stale, now-invalid
      // access token from the expired session is still sitting in storage
      // at this point (it's only cleared if the user gives up), so if this
      // login attempt itself failed with a 401 (wrong password) through
      // `api`, the interceptor would see that stale token, think another
      // session had just expired, and recursively call back into this same
      // modal instead of just reporting "wrong password". Bypassing `api`
      // avoids that entirely — refreshAccessToken() and logout() follow the
      // same rule for the same reason.
      const { data } = await axios.post(`${API_URL}/api/auth/login`, { email, password }, { withCredentials: true });
      setAuthSession(data.accessToken);
      scheduleProactiveRefresh(data.accessToken);
      // Resolve the pending reauth promise BEFORE awaiting refreshUser(). The
      // request that originally triggered this modal (very often
      // AuthContext's own /users/me check) is still pending inside
      // lib/api.ts's interceptor, blocked on this exact promise. refreshUser()
      // (AuthContext.fetchMe) dedupes concurrent calls by awaiting that same
      // in-flight request rather than firing a new one — so if we awaited
      // refreshUser() first, it would sit there waiting for a request that
      // itself can't complete until resolveReauth() runs, which is a
      // deadlock: the "Signing in…" state never clears and the modal never
      // closes. Resolving first lets that stuck request retry with the new
      // token and finish, so refreshUser() below has something to join (or
      // is free to issue its own fresh call) instead of waiting forever.
      resolveReauth(data.accessToken);
      await refreshUser();
      close();
    } catch (err: unknown) {
      const axiosErr = err as { response?: { data?: { message?: string }; status?: number } };
      if (axiosErr.response?.status === 401) {
        setError('Incorrect email or password. Please try again.');
      } else {
        setError(axiosErr.response?.data?.message || 'Unable to sign in right now. Please try again.');
      }
    } finally {
      setSubmitting(false);
    }
  };

  const handleCancel = () => {
    rejectReauth(new Error('User dismissed the session-expired prompt'));
    close();
  };

  if (!open) return null;

  return (
    <>
      <div className="fixed inset-0 z-[9998] bg-black/60 backdrop-blur-md" aria-hidden="true" />

      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="session-expired-title"
        className="fixed inset-0 z-[9999] flex items-center justify-center p-4"
      >
        <div
          className="relative bg-white rounded-3xl shadow-2xl w-full max-w-sm overflow-hidden"
          style={{ animation: 'modal-pop 0.3s cubic-bezier(0.34,1.56,0.64,1) both' }}
        >
          <style>{`
            @keyframes modal-pop {
              from { opacity: 0; transform: scale(0.88) translateY(16px); }
              to   { opacity: 1; transform: scale(1)    translateY(0);    }
            }
          `}</style>

          <div className="bg-gradient-to-br from-red-700 to-red-500 px-6 py-6 text-white">
            <div className="flex items-center gap-3 mb-2">
              <div className="w-11 h-11 rounded-2xl bg-white/15 backdrop-blur-sm flex items-center justify-center text-2xl shadow-inner">
                🔒
              </div>
              <h2 id="session-expired-title" className="text-lg font-black tracking-tight leading-tight">
                Your session has expired
              </h2>
            </div>
            <p className="text-sm text-white/80 leading-relaxed mt-3">
              Sign in again to continue — nothing you&apos;ve entered on this page will be lost.
            </p>
          </div>

          <form onSubmit={handleSignIn} className="p-5 space-y-3">
            {error && (
              <div className="text-sm text-red-600 bg-red-50 border border-red-100 rounded-xl px-3 py-2">
                {error}
              </div>
            )}

            <div>
              <label htmlFor="session-expired-email" className="block text-xs font-bold text-gray-500 uppercase tracking-wide mb-1">
                Email
              </label>
              <input
                id="session-expired-email"
                type="email"
                autoComplete="email"
                autoFocus
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-red-400 focus:border-transparent"
                placeholder="you@example.com"
              />
            </div>

            <div>
              <label htmlFor="session-expired-password" className="block text-xs font-bold text-gray-500 uppercase tracking-wide mb-1">
                Password
              </label>
              <input
                id="session-expired-password"
                type="password"
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-red-400 focus:border-transparent"
                placeholder="••••••••"
              />
            </div>

            <button
              type="submit"
              disabled={submitting}
              className="w-full py-3 rounded-2xl font-bold text-sm text-white bg-red-600 transition-all shadow-lg hover:shadow-xl hover:brightness-105 active:scale-[0.98] disabled:opacity-60 disabled:cursor-not-allowed"
            >
              {submitting ? 'Signing in…' : 'Sign in & continue'}
            </button>

            <p className="text-center text-[11px] text-gray-400">
              <button type="button" onClick={handleCancel} className="underline hover:text-gray-600 transition-colors">
                Cancel and go to the sign-in page instead
              </button>
            </p>
          </form>
        </div>
      </div>
    </>
  );
}
