'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '@/context/AuthContext';
import { api } from '@/lib/api';
import { Breadcrumb } from '@/components/ui/Breadcrumb';

type KycStatus = 'NOT_SUBMITTED' | 'PENDING' | 'APPROVED' | 'REJECTED';
type DocumentType = 'NATIONAL_ID' | 'PASSPORT' | 'DRIVERS_LICENSE' | 'BUSINESS_LICENSE';

interface KycState {
  kycStatus: KycStatus;
  kycDocumentType?: DocumentType | null;
  kycDocumentUrl?: string | null;
  kycSelfieUrl?: string | null;
  kycFullName?: string | null;
  kycSubmittedAt?: string | null;
  kycReviewedAt?: string | null;
  kycRejectionReason?: string | null;
}

const DOCUMENT_LABELS: Record<DocumentType, string> = {
  NATIONAL_ID: 'National ID Card',
  PASSPORT: 'Passport',
  DRIVERS_LICENSE: "Driver's License",
  BUSINESS_LICENSE: 'Business License',
};

async function uploadKycImage(file: File): Promise<string> {
  const formData = new FormData();
  formData.append('image', file);
  const { data } = await api.post('/upload/kyc-document', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return data.url as string;
}

export default function VerificationPage() {
  const { user, loading: authLoading, refreshUser } = useAuth();
  const router = useRouter();

  const [state, setState] = useState<KycState | null>(null);
  const [loading, setLoading] = useState(true);

  const [documentType, setDocumentType] = useState<DocumentType>('NATIONAL_ID');
  const [fullName, setFullName] = useState('');
  const [documentFile, setDocumentFile] = useState<File | null>(null);
  const [documentPreview, setDocumentPreview] = useState<string | null>(null);
  const [selfieFile, setSelfieFile] = useState<File | null>(null);
  const [selfiePreview, setSelfiePreview] = useState<string | null>(null);
  const documentInputRef = useRef<HTMLInputElement>(null);
  const selfieInputRef = useRef<HTMLInputElement>(null);

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!authLoading && !user) router.push('/auth/login?redirect=/profile/verification');
  }, [authLoading, user, router]);

  useEffect(() => {
    if (!user) return;
    setFullName(user.name || '');
    api.get('/kyc/status')
      .then(({ data }) => setState(data))
      .catch(() => setState(null))
      .finally(() => setLoading(false));
  }, [user]);

  const handleFileSelect = (
    files: FileList | null,
    setFile: (f: File | null) => void,
    setPreview: (p: string | null) => void,
  ) => {
    if (!files || files.length === 0) return;
    const file = files[0];
    const allowed = ['image/jpeg', 'image/png', 'image/webp'];
    if (!allowed.includes(file.type)) {
      setError('Only JPG, PNG, or WEBP images are allowed');
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      setError('Image must be under 10 MB');
      return;
    }
    setError('');
    setFile(file);
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === 'string') setPreview(reader.result);
    };
    reader.readAsDataURL(file);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!fullName.trim() || fullName.trim().length < 2) {
      setError('Please enter your full legal name as it appears on your ID.');
      return;
    }
    if (!documentFile) {
      setError('Please upload a clear photo of your ID document.');
      return;
    }

    setSubmitting(true);
    try {
      const documentUrl = await uploadKycImage(documentFile);
      const selfieUrl = selfieFile ? await uploadKycImage(selfieFile) : undefined;

      const { data } = await api.post('/kyc/submit', {
        documentType,
        documentUrl,
        selfieUrl,
        fullName: fullName.trim(),
      });

      setState((prev) => ({ ...(prev || {} as KycState), ...data }));
      await refreshUser();
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { message?: string } } })?.response?.data?.message;
      setError(msg || 'Failed to submit your verification. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  if (authLoading || loading) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-5 animate-pulse space-y-3">
        <div className="h-4 shimmer rounded w-1/3" />
        <div className="h-64 shimmer rounded-2xl" />
      </div>
    );
  }

  const status = state?.kycStatus ?? 'NOT_SUBMITTED';

  return (
    <div className="max-w-2xl mx-auto px-4 py-4 sm:py-6 animate-fade-in">
      <Breadcrumb
        className="mb-4"
        items={[
          { label: 'Home', href: '/' },
          { label: 'Profile', href: '/profile' },
          { label: 'Identity Verification' },
        ]}
      />

      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4 sm:p-5">
        <h1 className="text-2xl font-black text-gray-900 mb-1">Identity Verification (KYC)</h1>
        <p className="text-sm text-gray-500 mb-6">
          Verified sellers get priority review on new listings, appear higher in search results,
          and show a trust badge that helps buyers find them.
        </p>

        {/* ── APPROVED ── */}
        {status === 'APPROVED' && (
          <div className="text-center py-8">
            <div className="w-16 h-16 bg-emerald-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg className="w-8 h-8 text-emerald-600" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clipRule="evenodd" />
              </svg>
            </div>
            <h2 className="text-lg font-bold text-gray-900 mb-1">You&apos;re KYC Verified</h2>
            <p className="text-sm text-gray-500 max-w-sm mx-auto">
              Your identity was verified on{' '}
              {state?.kycReviewedAt ? new Date(state.kycReviewedAt).toLocaleDateString() : 'record'}.
              Your listings now get priority review and your profile shows the verified badge.
            </p>
            <Link
              href="/profile/listings"
              className="inline-flex items-center gap-2 mt-5 px-5 py-2.5 rounded-xl bg-red-600 hover:bg-red-700 text-white text-sm font-semibold transition-colors"
            >
              View My Listings
            </Link>
          </div>
        )}

        {/* ── PENDING ── */}
        {status === 'PENDING' && (
          <div className="text-center py-8">
            <div className="w-16 h-16 bg-amber-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg className="w-8 h-8 text-amber-600 animate-pulse" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <h2 className="text-lg font-bold text-gray-900 mb-1">Verification Pending</h2>
            <p className="text-sm text-gray-500 max-w-sm mx-auto">
              Your documents were submitted
              {state?.kycSubmittedAt ? ` on ${new Date(state.kycSubmittedAt).toLocaleDateString()}` : ''} and are
              awaiting admin review. This usually takes 24–48 hours.
            </p>
          </div>
        )}

        {/* ── NOT_SUBMITTED / REJECTED → show form ── */}
        {(status === 'NOT_SUBMITTED' || status === 'REJECTED') && (
          <>
            {status === 'REJECTED' && state?.kycRejectionReason && (
              <div className="mb-6 p-3 bg-red-50 border border-red-200 rounded-xl">
                <p className="text-sm font-semibold text-red-800 mb-0.5">Your previous submission was rejected</p>
                <p className="text-xs text-red-700">{state.kycRejectionReason}</p>
                <p className="text-xs text-red-600 mt-1">You can correct the issue and resubmit below.</p>
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-5">
              <div>
                <label className="block text-sm font-bold text-gray-800 mb-1.5">
                  Document Type <span className="text-red-500">*</span>
                </label>
                <select
                  value={documentType}
                  onChange={(e) => setDocumentType(e.target.value as DocumentType)}
                  className="w-full rounded-xl border border-gray-200 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-red-300 focus:border-red-400 transition-shadow"
                >
                  {(Object.keys(DOCUMENT_LABELS) as DocumentType[]).map((dt) => (
                    <option key={dt} value={dt}>{DOCUMENT_LABELS[dt]}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-bold text-gray-800 mb-1.5">
                  Full Legal Name <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  placeholder="As it appears on your ID"
                  className="w-full rounded-xl border border-gray-200 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-red-300 focus:border-red-400 transition-shadow"
                />
              </div>

              <div>
                <label className="block text-sm font-bold text-gray-800 mb-1.5">
                  Photo of Document <span className="text-red-500">*</span>
                </label>
                <input
                  ref={documentInputRef}
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  onChange={(e) => handleFileSelect(e.target.files, setDocumentFile, setDocumentPreview)}
                  className="w-full text-sm text-gray-600 file:mr-3 file:py-1.5 file:px-3 file:rounded-lg file:border-0 file:text-xs file:font-semibold file:bg-red-50 file:text-red-700 hover:file:bg-red-100 transition-colors"
                />
                {documentPreview && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={documentPreview} alt="Document preview" className="mt-2 max-h-48 rounded-xl border border-gray-200 object-contain" />
                )}
              </div>

              <div>
                <label className="block text-sm font-bold text-gray-800 mb-1.5">
                  Selfie Holding the Document <span className="text-gray-400 font-normal">(optional, speeds up review)</span>
                </label>
                <input
                  ref={selfieInputRef}
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  onChange={(e) => handleFileSelect(e.target.files, setSelfieFile, setSelfiePreview)}
                  className="w-full text-sm text-gray-600 file:mr-3 file:py-1.5 file:px-3 file:rounded-lg file:border-0 file:text-xs file:font-semibold file:bg-red-50 file:text-red-700 hover:file:bg-red-100 transition-colors"
                />
                {selfiePreview && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={selfiePreview} alt="Selfie preview" className="mt-2 max-h-48 rounded-xl border border-gray-200 object-contain" />
                )}
              </div>

              {error && (
                <div className="p-3 bg-red-50 border border-red-200 rounded-xl text-sm text-red-700">
                  {error}
                </div>
              )}

              <button
                type="submit"
                disabled={submitting}
                className="w-full py-3 rounded-xl bg-red-600 hover:bg-red-700 text-white font-bold text-sm transition-colors disabled:opacity-50 shadow-sm interactive"
              >
                {submitting ? 'Submitting…' : 'Submit for Verification'}
              </button>
            </form>

            <div className="mt-6 p-4 bg-red-50 border border-red-100 rounded-xl">
              <h3 className="text-xs font-bold text-red-800 mb-2">Why verify?</h3>
              <ul className="text-xs text-red-700 space-y-1">
                <li>• Your new listings get priority in the admin review queue</li>
                <li>• A &quot;KYC Verified&quot; badge appears on your profile and listings</li>
                <li>• Verified sellers rank higher in buyer search results</li>
                <li>• Documents are reviewed only by our admin team, never shown publicly</li>
              </ul>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
