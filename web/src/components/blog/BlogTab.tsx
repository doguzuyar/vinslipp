"use client";

import { useState, useEffect } from "react";
import { getBlogPosts, type BlogPost } from "@/lib/firebase";

function formatDate(post: BlogPost): string {
  if (!post.createdAt) return "";
  const d = post.createdAt.toDate();
  const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
  return `${months[d.getMonth()]} ${d.getDate()}, ${String(d.getHours()).padStart(2,"0")}:${String(d.getMinutes()).padStart(2,"0")}`;
}

export function BlogTab() {
  const [posts, setPosts] = useState<BlogPost[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getBlogPosts()
      .then(setPosts)
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="tab-scroll" style={{ display: "flex", alignItems: "center", justifyContent: "center", minHeight: 300, color: "var(--text-muted)", fontSize: 14 }}>
        Loading...
      </div>
    );
  }

  if (posts.length === 0) {
    return (
      <div className="tab-scroll" style={{ display: "flex", alignItems: "center", justifyContent: "center", minHeight: 300, color: "var(--text-muted)", fontSize: 14 }}>
        No blog posts yet. Click Blog on any wine to write one.
      </div>
    );
  }

  return (
    <div className="tab-scroll" style={{ display: "flex", flexDirection: "column", gap: 16, paddingBottom: 40 }}>
      {posts.map((post) => (
        <div
          key={post.id}
          style={{
            background: "var(--bg-alt)",
            borderRadius: 12,
            padding: 16,
            display: "flex",
            flexDirection: "column",
            gap: 8,
          }}
        >
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
            <div>
              <span style={{ fontSize: 15, fontWeight: 600, color: "var(--text)" }}>
                {post.winery}
              </span>
              <span style={{ fontSize: 13, color: "var(--text-muted)", marginLeft: 8 }}>
                {post.wineName} {post.vintage}
              </span>
            </div>
          </div>
          <div style={{ fontSize: 14, color: "var(--text)", lineHeight: 1.5 }}>
            {post.comment}
          </div>
          <div style={{ fontSize: 11, color: "var(--text-muted)", display: "flex", gap: 8 }}>
            <span>{post.userName}</span>
            <span>{formatDate(post)}</span>
          </div>
        </div>
      ))}
    </div>
  );
}
