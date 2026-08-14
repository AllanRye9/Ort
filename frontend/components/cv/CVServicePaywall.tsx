'use client';

import { ReactNode } from 'react';

interface CVServicePaywallProps {
  featureName: string;
  children: ReactNode;
}

/**
 * CVServicePaywall — subscriptions removed.
 * All CV services are now free to use; users pay only when they download.
 * This component is kept as a passthrough so existing call-sites don't break.
 */
export function CVServicePaywall({ children }: CVServicePaywallProps) {
  return <>{children}</>;
}
