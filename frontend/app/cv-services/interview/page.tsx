'use client';

import Link from 'next/link';
import { API_URL } from '@/lib/api';
import { useState, useEffect } from 'react';
import { Breadcrumb } from '@/components/ui/Breadcrumb';
import { CVServicePaywall } from '@/components/cv/CVServicePaywall';
import { resolveImageUrl } from '@/lib/utils';

const TIPS = [
  { icon: '📚', title: 'Research the Company', desc: 'Know their mission, recent news, and how your skills align with their goals.' },
  { icon: '🪞', title: 'Practise Out Loud', desc: 'Rehearse answers to common questions in front of a mirror or record yourself.' },
  { icon: '⭐', title: 'Use the STAR Method', desc: 'Structure answers as Situation → Task → Action → Result for behavioural questions.' },
  { icon: '❓', title: 'Prepare Questions', desc: 'Have 3–5 thoughtful questions ready to ask the interviewer.' },
  { icon: '👔', title: 'Dress Appropriately', desc: 'Research the company culture and dress one level above their standard.' },
  { icon: '⏰', title: 'Arrive Early', desc: 'Plan to arrive 10–15 minutes early to allow time to compose yourself.' },
];

const QUESTION_BANKS = [
  {
    category: 'Common Questions',
    color: '#0EA5E9',
    questions: [
      'Tell me about yourself.',
      'Why do you want to work here?',
      'What are your greatest strengths?',
      'What is your biggest weakness?',
      'Where do you see yourself in 5 years?',
    ],
  },
  {
    category: 'Behavioural',
    color: '#7C3AED',
    questions: [
      'Describe a time you handled conflict at work.',
      'Give an example of a goal you set and achieved.',
      'Tell me about a time you failed and what you learned.',
      'Describe a situation where you showed leadership.',
    ],
  },
  {
    category: 'Situational',
    color: '#059669',
    questions: [
      'How would you handle a missed deadline?',
      'What would you do if you disagreed with your manager?',
      'How do you prioritise tasks when everything is urgent?',
    ],
  },
];

export default function InterviewPrepPage() {
  const [openBank, setOpenBank] = useState<string | null>(null);
  const [demoVideoUrl, setDemoVideoUrl] = useState<string | null>(null);
  const [demoVideoTitle, setDemoVideoTitle] = useState<string | null>(null);

  useEffect(() => {
    fetch(`${API_URL}/api/public/site-config`)
      .then((r) => r.ok ? r.json() : null)
      .then((d) => {
        if (d?.interviewDemoVideoUrl) {
          setDemoVideoUrl(d.interviewDemoVideoUrl);
          setDemoVideoTitle(d.interviewDemoVideoTitle || null);
        }
      })
      .catch(() => {});
  }, []);

  return (
    <div className="max-w-5xl mx-auto px-4 py-4 sm:py-6 animate-fade-in">
      <Breadcrumb
        className="mb-4"
        items={[
          { label: 'Home', href: '/' },
          { label: 'CV Services', href: '/cv-services' },
          { label: 'Interview Preparation' },
        ]}
      />

      {/* Hero */}
      <div className="rounded-3xl bg-gradient-to-r from-rose-600 to-red-600 px-5 py-5 text-white shadow-xl mb-5">
        <p className="inline-flex items-center rounded-full border border-white/20 bg-white/10 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-white/85 mb-4">
          Interview Preparation
        </p>
        <h1 className="text-3xl sm:text-4xl font-black mb-2">Walk In Confident. Walk Out Hired.</h1>
        <p className="text-white/80 max-w-2xl text-sm">
          Run an autonomous interview simulator with ready-made question banks and instant prep workflows.
        </p>
      </div>

      {/* Demo video — admin-uploaded, shown only when available */}
      {demoVideoUrl && (
        <section className="mb-6">
          {demoVideoTitle && (
            <h2 className="text-xl font-black text-gray-900 mb-3">{demoVideoTitle}</h2>
          )}
          <div className="rounded-2xl overflow-hidden border border-gray-100 shadow-sm bg-black aspect-video">
            <video
              src={resolveImageUrl(demoVideoUrl)}
              controls
              className="w-full h-full object-contain"
            />
          </div>
        </section>
      )}

      {/* Tips */}
      <section className="mb-6">
        <h2 className="text-xl font-black text-gray-900 mb-3">Interview Tips</h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {TIPS.map((tip) => (
            <div key={tip.title} className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5 hover:shadow-md transition-all">
              <span className="text-2xl">{tip.icon}</span>
              <h3 className="font-bold text-gray-900 mt-2 mb-1 text-sm">{tip.title}</h3>
              <p className="text-xs text-gray-500 leading-relaxed">{tip.desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Question banks */}
      <section className="mb-6">
        <h2 className="text-xl font-black text-gray-900 mb-1">Question Banks</h2>
        <p className="text-sm text-gray-500 mb-3">Practise with our categorised question banks.</p>
        <div className="space-y-3">
          {QUESTION_BANKS.map((bank) => (
            <div key={bank.category} className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
              <button
                onClick={() => setOpenBank(openBank === bank.category ? null : bank.category)}
                className="w-full flex items-center justify-between p-4 text-left hover:bg-gray-50 transition-colors"
              >
                <span className="font-bold text-gray-900" style={{ color: bank.color }}>{bank.category}</span>
                <span className="text-gray-400 text-lg">{openBank === bank.category ? '▲' : '▼'}</span>
              </button>
              {openBank === bank.category && (
                <ul className="border-t border-gray-100 divide-y divide-gray-50">
                  {bank.questions.map((q) => (
                    <li key={q} className="px-4 py-3 text-sm text-gray-700 flex items-start gap-2">
                      <span style={{ color: bank.color }}>→</span>
                      {q}
                    </li>
                  ))}
                </ul>
              )}
            </div>
          ))}
        </div>
      </section>

      <CVServicePaywall featureName="Interview Simulator">
        <section className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4 sm:p-5">
          <h2 className="text-lg font-black text-gray-900 mb-1">Start Digital Interview Simulation</h2>
          <p className="text-sm text-gray-500 mb-3">Before your interview, make sure your application is complete:</p>
          <div className="flex flex-col sm:flex-row gap-3 mb-5">
            <div className="flex-1 bg-sky-50 border border-sky-100 rounded-xl p-3 text-sm text-sky-800 font-semibold flex items-center gap-2">
              📄 Create your CV and Cover Letter
            </div>
          </div>
          <div className="flex flex-wrap gap-3">
            <Link href="/cv-generator/builder" className="inline-flex items-center gap-2 rounded-xl bg-sky-600 px-5 py-2.5 text-sm font-bold text-white hover:bg-sky-700">
              📄 Build Your CV
            </Link>
            <Link href="/cv-generator/cover-letter" className="inline-flex items-center gap-2 rounded-xl border border-sky-200 px-5 py-2.5 text-sm font-semibold text-sky-700 hover:bg-sky-50">
              📝 Write Cover Letter
            </Link>
            <Link href="/cv-generator?theme=bold" className="inline-flex items-center gap-2 rounded-xl bg-rose-600 px-5 py-2.5 text-sm font-bold text-white hover:bg-rose-700">
              🎤 Launch Interview Simulator
            </Link>
          </div>
        </section>
      </CVServicePaywall>
    </div>
  );
}
