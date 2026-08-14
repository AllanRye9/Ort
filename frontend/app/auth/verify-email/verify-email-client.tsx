'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { api } from '@/lib/api';
import AuthColorBlend from '@/components/ui/AuthColorBlend';

type VerificationState = 'loading' | 'success' | 'error';

export default function VerifyEmailClientPage() {
  const searchParams = useSearchParams();
  const [state, setState] = useState<VerificationState>('loading');
  const [message, setMessage] = useState('Verifying your email...');

  useEffect(() => {
    const token = searchParams?.get('token') || '';

    if (!token) {
      setState('error');
      setMessage('Verification token is missing. Please use the link from your email.');
      return;
    }

    let mounted = true;

    const verify = async () => {
      try {
        const { data } = await api.post('/auth/verify-email', { token });
        if (!mounted) return;
        setState('success');
        setMessage(data?.message || 'Email verified successfully. You can now sign in.');
      } catch (err: unknown) {
        if (!mounted) return;
        const axiosErr = err as { response?: { data?: { message?: string } } };
        setState('error');
        setMessage(axiosErr.response?.data?.message || 'Verification failed. The link may be invalid or expired.');
      }
    };

    void verify();

    return () => {
      mounted = false;
    };
  }, [searchParams]);

  return (
    <AuthColorBlend className="flex items-center justify-center">
      <div className="w-full max-w-md animate-fade-up">
        <div className="rounded-3xl border border-white/30 dark:border-white/20 bg-white/95 dark:bg-slate-900/85 shadow-2xl backdrop-blur-xl p-6 sm:p-7 text-center">
          <h1 className="text-[1.65rem] leading-tight font-extrabold text-slate-950 dark:text-white mb-2">Email Verification</h1>
          <p className="text-sm text-slate-600 dark:text-slate-300 mb-5">{message}</p>

          {state === 'loading' && (
            <div className="mx-auto w-8 h-8 border-4 border-sky-200 border-t-sky-500 rounded-full animate-spin" />
          )}

          {state !== 'loading' && (
            <Link
              href="/auth/login"
              className="inline-flex items-center justify-center w-full py-3 rounded-xl bg-gradient-to-r from-fuchsia-600 via-sky-600 to-indigo-600 text-white text-sm font-bold shadow-glow hover:brightness-110 transition-all"
            >
              Go to Sign In
            </Link>
          )}
        </div>
      </div>
    </AuthColorBlend>
  );
}