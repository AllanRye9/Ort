import { Suspense } from 'react';
import SubscriptionClientPage from './subscription-client';

export default function SubscriptionPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-sm text-gray-500">Loading…</div>}>
      <SubscriptionClientPage />
    </Suspense>
  );
}
