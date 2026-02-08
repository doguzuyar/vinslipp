const OWNER = "doguzuyar";
const REPO = "vinslipp";
const BRANCH = "main";
const API = "https://api.github.com";

export type UploadStep =
  | "reading_files"
  | "creating_blobs"
  | "creating_tree"
  | "creating_commit"
  | "updating_ref"
  | "done"
  | "error";

export const STEP_LABELS: Record<UploadStep, string> = {
  reading_files: "Reading files\u2026",
  creating_blobs: "Uploading file data\u2026",
  creating_tree: "Creating file tree\u2026",
  creating_commit: "Creating commit\u2026",
  updating_ref: "Pushing to main\u2026",
  done: "Done! Rebuild triggered.",
  error: "Upload failed.",
};

export interface FileToCommit {
  path: string;
  content: string;
}

// --- Token management ---

export function getGitHubToken(): string | null {
  return localStorage.getItem("ghToken");
}

export function setGitHubToken(token: string): void {
  localStorage.setItem("ghToken", token);
}

export function clearGitHubToken(): void {
  localStorage.removeItem("ghToken");
}

// --- API helpers ---

async function ghFetch(
  path: string,
  token: string,
  options?: RequestInit
): Promise<Response> {
  const res = await fetch(`${API}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      ...(options?.headers as Record<string, string>),
    },
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`GitHub API ${res.status}: ${body}`);
  }
  return res;
}

async function ghJson<T>(
  path: string,
  token: string,
  options?: RequestInit
): Promise<T> {
  const res = await ghFetch(path, token, options);
  return res.json() as Promise<T>;
}

export async function validateToken(token: string): Promise<boolean> {
  try {
    await ghFetch(`/repos/${OWNER}/${REPO}`, token);
    return true;
  } catch {
    return false;
  }
}

// --- Atomic multi-file commit via Git Trees API ---

export async function commitFiles(
  token: string,
  files: FileToCommit[],
  message: string,
  onStep?: (step: UploadStep) => void
): Promise<void> {
  onStep?.("creating_blobs");

  // 1. Get latest commit SHA on main
  const ref = await ghJson<{ object: { sha: string } }>(
    `/repos/${OWNER}/${REPO}/git/ref/heads/${BRANCH}`,
    token
  );
  const latestCommitSha = ref.object.sha;

  // 2. Get the tree SHA from that commit
  const commit = await ghJson<{ tree: { sha: string } }>(
    `/repos/${OWNER}/${REPO}/git/commits/${latestCommitSha}`,
    token
  );
  const baseTreeSha = commit.tree.sha;

  // 3. Create blobs for each file
  const treeEntries: { path: string; mode: string; type: string; sha: string }[] = [];
  for (const file of files) {
    const blob = await ghJson<{ sha: string }>(
      `/repos/${OWNER}/${REPO}/git/blobs`,
      token,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          content: btoa(unescape(encodeURIComponent(file.content))),
          encoding: "base64",
        }),
      }
    );
    treeEntries.push({
      path: file.path,
      mode: "100644",
      type: "blob",
      sha: blob.sha,
    });
  }

  // 4. Create new tree
  onStep?.("creating_tree");
  const tree = await ghJson<{ sha: string }>(
    `/repos/${OWNER}/${REPO}/git/trees`,
    token,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        base_tree: baseTreeSha,
        tree: treeEntries,
      }),
    }
  );

  // 5. Create commit
  onStep?.("creating_commit");
  const newCommit = await ghJson<{ sha: string }>(
    `/repos/${OWNER}/${REPO}/git/commits`,
    token,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        message,
        tree: tree.sha,
        parents: [latestCommitSha],
      }),
    }
  );

  // 6. Update branch ref
  onStep?.("updating_ref");
  await ghFetch(
    `/repos/${OWNER}/${REPO}/git/refs/heads/${BRANCH}`,
    token,
    {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ sha: newCommit.sha }),
    }
  );

  onStep?.("done");
}
