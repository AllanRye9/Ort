'use client';

import { useState } from 'react';
import { User } from '@/lib/types';
import { resolveImageUrl } from '@/lib/utils';

interface Props {
  user: Partial<User>;
  size?: 'sm' | 'md' | 'lg';
}

const sizes = { sm: 32, md: 48, lg: 96 };

function Initials({ user, px }: { user: Partial<User>; px: number }) {
  return (
    <div
      className="rounded-full bg-sky-500 flex items-center justify-center text-white font-bold shrink-0"
      style={{ width: px, height: px, fontSize: px * 0.4 }}
    >
      {(user.name || 'U').charAt(0).toUpperCase()}
    </div>
  );
}

export function UserAvatar({ user, size = 'md' }: Props) {
  const px = sizes[size];
  // The upload endpoint returns a relative path (e.g. /uploads/... or
  // /api/images/...), not an absolute URL. resolveImageUrl() is the single
  // shared helper (also used for listing/logo images) that rewrites these
  // into a fully-qualified backend URL — this component previously had its
  // own resolver that only handled a "localhost" origin and left relative
  // paths untouched, so uploaded avatars silently 404'd against the
  // frontend's own origin instead of the backend.
  const [failed, setFailed] = useState(false);

  if (user.avatar && !failed) {
    const src = resolveImageUrl(user.avatar);
    return (
      // Use a plain <img> tag so Next.js image-domain restrictions don't
      // prevent avatars from loading regardless of where the bucket is hosted.
      <div
        className="rounded-full overflow-hidden shrink-0 bg-gray-100"
        style={{ width: px, height: px }}
        title={user.name ? `${user.name}'s profile photo` : 'Profile photo'}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={src}
          alt={user.name ? `${user.name}'s profile photo` : 'Profile photo'}
          className="w-full h-full object-cover"
          width={px}
          height={px}
          loading="lazy"
          decoding="async"
          onError={() => setFailed(true)}
        />
      </div>
    );
  }
  return <Initials user={user} px={px} />;
}
