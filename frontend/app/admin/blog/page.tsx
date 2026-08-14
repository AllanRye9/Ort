'use client';

import { useEffect, useState, useCallback } from 'react';
import { useAuth } from '@/context/AuthContext';
import { api } from '@/lib/api';
import { useRouter } from 'next/navigation';
import Image from 'next/image';
import { resolveImageUrl } from '@/lib/utils';

interface BlogPost {
  id: string;
  title: string;
  slug: string;
  content: string;
  excerpt: string | null;
  featuredImage: string | null;
  status: 'DRAFT' | 'PUBLISHED';
  publishedAt: string | null;
  createdAt: string;
  author?: { id: string; name: string };
}

function slugify(str: string): string {
  return str.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

function formatDate(d: string): string {
  return new Date(d).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
}

export default function AdminBlogPage() {
  const { user, loading } = useAuth();
  const router = useRouter();

  const [posts, setPosts] = useState<BlogPost[]>([]);
  const [fetching, setFetching] = useState(true);
  const [editing, setEditing] = useState<BlogPost | null>(null);
  const [isNew, setIsNew] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [uploadingImage, setUploadingImage] = useState(false);

  // Form state
  const [title, setTitle] = useState('');
  const [slug, setSlug] = useState('');
  const [content, setContent] = useState('');
  const [excerpt, setExcerpt] = useState('');
  const [featuredImage, setFeaturedImage] = useState('');
  const [status, setStatus] = useState<'DRAFT' | 'PUBLISHED'>('DRAFT');

  useEffect(() => {
    if (!loading && (!user || user.role !== 'ADMIN')) router.replace('/');
  }, [user, loading, router]);

  const fetchPosts = useCallback(async () => {
    try {
      setFetching(true);
      const { data } = await api.get('/blog/admin/all');
      setPosts(data.posts || []);
    } catch {
      setError('Failed to load posts');
    } finally {
      setFetching(false);
    }
  }, []);

  useEffect(() => { fetchPosts(); }, [fetchPosts]);

  const openNew = () => {
    setEditing(null);
    setIsNew(true);
    setTitle('');
    setSlug('');
    setContent('');
    setExcerpt('');
    setFeaturedImage('');
    setStatus('DRAFT');
    setError('');
    setSuccess('');
  };

  const openEdit = async (post: BlogPost) => {
    try {
      const { data } = await api.get(`/blog/admin/${post.id}`);
      const p: BlogPost = data.post;
      setEditing(p);
      setIsNew(false);
      setTitle(p.title);
      setSlug(p.slug);
      setContent(p.content);
      setExcerpt(p.excerpt || '');
      setFeaturedImage(p.featuredImage || '');
      setStatus(p.status);
      setError('');
      setSuccess('');
    } catch {
      setError('Failed to load post');
    }
  };

  const handleTitleChange = (v: string) => {
    setTitle(v);
    if (isNew) setSlug(slugify(v));
  };

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploadingImage(true);
    try {
      const formData = new FormData();
      formData.append('images', file);
      const { data } = await api.post('/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      setFeaturedImage(data.urls?.[0] || '');
    } catch {
      setError('Image upload failed');
    } finally {
      setUploadingImage(false);
      e.target.value = '';
    }
  };

  const handleSave = async () => {
    setError('');
    setSuccess('');
    if (!title.trim() || !slug.trim() || !content.trim()) {
      setError('Title, slug, and content are required.');
      return;
    }
    setSaving(true);
    try {
      if (isNew) {
        await api.post('/blog', { title, slug, content, excerpt: excerpt || null, featuredImage: featuredImage || null, status });
        setSuccess('Post created successfully.');
      } else if (editing) {
        await api.patch(`/blog/${editing.id}`, { title, slug, content, excerpt: excerpt || null, featuredImage: featuredImage || null, status });
        setSuccess('Post updated successfully.');
      }
      fetchPosts();
      setIsNew(false);
      setEditing(null);
    } catch (err) {
      const msg = (err as { response?: { data?: { message?: string } } })?.response?.data?.message || 'Save failed';
      setError(msg);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this post? This cannot be undone.')) return;
    try {
      await api.delete(`/blog/${id}`);
      if (editing?.id === id) { setEditing(null); setIsNew(false); }
      fetchPosts();
    } catch {
      setError('Delete failed');
    }
  };

  if (loading) return <div className="p-8 text-center">Loading...</div>;

  const showEditor = isNew || editing !== null;

  return (
    <div className="max-w-7xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Blog Manager</h1>
          <p className="text-sm text-gray-500 mt-0.5">Create and manage blog posts</p>
        </div>
        <button
          onClick={openNew}
          className="px-4 py-2 bg-sky-600 text-white text-sm font-semibold rounded-lg hover:bg-sky-700 transition-colors"
        >
          + New Post
        </button>
      </div>

      {error && <div className="mb-4 rounded-lg bg-red-50 border border-red-200 text-red-700 px-4 py-3 text-sm">{error}</div>}
      {success && <div className="mb-4 rounded-lg bg-green-50 border border-green-200 text-green-700 px-4 py-3 text-sm">{success}</div>}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Post list */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <div className="px-4 py-3 bg-gray-50 border-b border-gray-100">
            <p className="text-sm font-semibold text-gray-700">All Posts ({posts.length})</p>
          </div>
          {fetching ? (
            <div className="p-8 text-center text-gray-400">Loading posts...</div>
          ) : posts.length === 0 ? (
            <div className="p-8 text-center text-gray-400">
              <p className="text-3xl mb-2">📝</p>
              <p className="text-sm">No posts yet. Create your first one!</p>
            </div>
          ) : (
            <ul className="divide-y divide-gray-100">
              {posts.map((post) => (
                <li key={post.id} className="flex items-start gap-3 px-4 py-3 hover:bg-gray-50 transition-colors">
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-gray-800 truncate">{post.title}</p>
                    <p className="text-xs text-gray-400 mt-0.5">/{post.slug} · {formatDate(post.createdAt)}</p>
                    <span className={`inline-block mt-1 text-[10px] font-bold px-1.5 py-0.5 rounded-full ${
                      post.status === 'PUBLISHED' ? 'bg-green-100 text-green-700' : 'bg-amber-100 text-amber-700'
                    }`}>
                      {post.status}
                    </span>
                  </div>
                  <div className="flex gap-1.5 shrink-0">
                    <button
                      onClick={() => openEdit(post)}
                      className="text-xs px-2 py-1 rounded bg-sky-50 text-sky-600 hover:bg-sky-100 transition-colors font-medium"
                    >
                      Edit
                    </button>
                    <button
                      onClick={() => handleDelete(post.id)}
                      className="text-xs px-2 py-1 rounded bg-red-50 text-red-500 hover:bg-red-100 transition-colors font-medium"
                    >
                      Delete
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>

        {/* Editor */}
        {showEditor && (
          <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
            <h2 className="text-base font-bold text-gray-800 mb-4">{isNew ? 'New Post' : 'Edit Post'}</h2>

            <div className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-gray-600 mb-1">Title *</label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => handleTitleChange(e.target.value)}
                  placeholder="Post title"
                  className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-sky-300"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-600 mb-1">Slug *</label>
                <input
                  type="text"
                  value={slug}
                  onChange={(e) => setSlug(slugify(e.target.value))}
                  placeholder="url-friendly-slug"
                  className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm font-mono focus:outline-none focus:ring-2 focus:ring-sky-300"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-600 mb-1">Excerpt</label>
                <textarea
                  value={excerpt}
                  onChange={(e) => setExcerpt(e.target.value)}
                  placeholder="Short summary (optional)"
                  rows={2}
                  className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-sky-300 resize-none"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-600 mb-1">Featured Image</label>
                <div className="flex items-center gap-3">
                  {featuredImage && (
                    <div className="relative w-16 h-16 rounded-lg overflow-hidden border border-gray-100 shrink-0">
                      <Image src={resolveImageUrl(featuredImage)} alt="Featured" fill className="object-cover" />
                    </div>
                  )}
                  <div className="flex-1">
                    <input
                      type="text"
                      value={featuredImage}
                      onChange={(e) => setFeaturedImage(e.target.value)}
                      placeholder="Paste URL or upload below"
                      className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-sky-300 mb-1"
                    />
                    <label className="cursor-pointer text-xs text-sky-600 hover:text-sky-700 font-medium">
                      {uploadingImage ? 'Uploading...' : '📎 Upload image'}
                      <input type="file" accept="image/*" className="hidden" onChange={handleImageUpload} disabled={uploadingImage} />
                    </label>
                  </div>
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-600 mb-1">Content * (HTML)</label>
                <textarea
                  value={content}
                  onChange={(e) => setContent(e.target.value)}
                  placeholder="<p>Write your post content here...</p>"
                  rows={12}
                  className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm font-mono focus:outline-none focus:ring-2 focus:ring-sky-300 resize-y"
                />
                <p className="text-[11px] text-gray-400 mt-0.5">Supports HTML. Use &lt;h2&gt;, &lt;p&gt;, &lt;ul&gt;, &lt;strong&gt;, &lt;img&gt;, etc.</p>
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-600 mb-1">Status</label>
                <select
                  value={status}
                  onChange={(e) => setStatus(e.target.value as 'DRAFT' | 'PUBLISHED')}
                  className="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-sky-300"
                >
                  <option value="DRAFT">Draft</option>
                  <option value="PUBLISHED">Published</option>
                </select>
              </div>

              <div className="flex gap-3 pt-2">
                <button
                  onClick={handleSave}
                  disabled={saving}
                  className="px-5 py-2 bg-sky-600 text-white text-sm font-semibold rounded-lg hover:bg-sky-700 disabled:opacity-50 transition-colors"
                >
                  {saving ? 'Saving...' : isNew ? 'Create Post' : 'Save Changes'}
                </button>
                <button
                  onClick={() => { setEditing(null); setIsNew(false); setError(''); setSuccess(''); }}
                  className="px-4 py-2 bg-gray-100 text-gray-700 text-sm font-medium rounded-lg hover:bg-gray-200 transition-colors"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
