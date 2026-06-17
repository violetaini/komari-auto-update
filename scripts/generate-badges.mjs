import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, "..");
const badgeDir = join(repoRoot, ".github", "badges");
const version = readFileSync(join(repoRoot, "VERSION"), "utf8").trim();

const repo = process.env.GITHUB_REPOSITORY || "violetaini/komari-auto-update";
const token = process.env.GITHUB_TOKEN || "";
const branch = process.env.GITHUB_REF_NAME || "main";

const headers = {
  Accept: "application/vnd.github+json",
  "User-Agent": "komari-auto-update-badge-generator",
};

if (token) {
  headers.Authorization = `Bearer ${token}`;
}

function badge(label, message, color = "blue", logo = undefined) {
  const data = {
    schemaVersion: 1,
    label,
    message: String(message),
    color,
  };
  if (logo) data.logo = logo;
  return data;
}

async function github(path) {
  const response = await fetch(`https://api.github.com${path}`, { headers });
  if (!response.ok) {
    throw new Error(`GitHub API ${response.status} for ${path}`);
  }
  return response;
}

async function githubJson(path) {
  const response = await github(path);
  return response.json();
}

function countFromLinkHeader(linkHeader) {
  if (!linkHeader) return null;
  const last = linkHeader
    .split(",")
    .map((part) => part.trim())
    .find((part) => part.includes('rel="last"'));
  const match = last?.match(/[?&]page=(\d+)/);
  return match ? Number(match[1]) : null;
}

async function countContributors() {
  const response = await github(`/repos/${repo}/contributors?per_page=1&anon=true`);
  const lastPage = countFromLinkHeader(response.headers.get("link"));
  if (lastPage !== null) return lastPage;
  const data = await response.json();
  return Array.isArray(data) ? data.length : 0;
}

async function main() {
  mkdirSync(badgeDir, { recursive: true });

  const [repoInfo, contributorCount, commits] = await Promise.all([
    githubJson(`/repos/${repo}`),
    countContributors(),
    githubJson(`/repos/${repo}/commits?sha=${encodeURIComponent(branch)}&per_page=1`),
  ]);

  const pushedAt = repoInfo.pushed_at ? new Date(repoInfo.pushed_at) : null;
  const daysSincePush = pushedAt
    ? Math.max(0, Math.floor((Date.now() - pushedAt.getTime()) / 86400000))
    : null;

  const files = {
    "version.json": badge("version", version, "8b5cf6"),
    "stars.json": badge("stars", repoInfo.stargazers_count ?? 0, "111827", "github"),
    "forks.json": badge("forks", repoInfo.forks_count ?? 0, "111827", "github"),
    "contributors.json": badge("contributors", contributorCount, "0ea5e9"),
    "commit-activity.json": badge(
      "last commit",
      daysSincePush === null ? "unknown" : daysSincePush === 0 ? "today" : `${daysSincePush}d ago`,
      "22c55e",
    ),
    "repo-size.json": badge("repo size", `${Math.ceil((repoInfo.size ?? 0) / 1024)} MB`, "f59e0b"),
    "latest-commit.json": badge(
      "commit",
      Array.isArray(commits) && commits[0]?.sha ? commits[0].sha.slice(0, 7) : "unknown",
      "64748b",
      "github",
    ),
  };

  for (const [name, content] of Object.entries(files)) {
    writeFileSync(join(badgeDir, name), `${JSON.stringify(content, null, 2)}\n`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
