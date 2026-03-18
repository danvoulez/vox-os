import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { assertMethod, handleError, jsonResponse, parseJson, requireString } from "../_shared/http.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import { encodeBase64 } from "../_shared/vox.ts";

async function putGithubFile(input: {
  owner: string;
  repo: string;
  token: string;
  path: string;
  content: string;
  message: string;
}) {
  const response = await fetch(`https://api.github.com/repos/${input.owner}/${input.repo}/contents/${input.path}`, {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${input.token}`,
      Accept: "application/vnd.github+json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: input.message,
      content: encodeBase64(input.content),
    }),
  });

  const payload = await response.json();

  if (!response.ok) {
    throw new Error(`GitHub export failed: ${response.status} ${JSON.stringify(payload)}`);
  }

  return payload;
}

function buildGithubPath(...parts: Array<string | null | undefined>) {
  return parts
    .filter((part): part is string => typeof part === "string" && part.trim().length > 0)
    .map((part) => part.replace(/^\/+|\/+$/g, ""))
    .join("/");
}

Deno.serve(async (request) => {
  try {
    assertMethod(request, "POST");

    const body = await parseJson<Record<string, unknown>>(request);
    const characterId = requireString(body.character_id, "character_id");
    const commitId = requireString(body.commit_id, "commit_id");

    const admin = createAdminClient();
    const { data: character, error: characterError } = await admin
      .from("characters")
      .select("id, slug, display_name, current_canon_version_id")
      .eq("id", characterId)
      .maybeSingle();

    if (characterError || !character) {
      return jsonResponse({ error: "Character not found." }, 404);
    }

    const [{ data: commit, error: commitError }, { data: version }] = await Promise.all([
      admin.from("commits").select("*").eq("id", commitId).eq("character_id", characterId).maybeSingle(),
      character.current_canon_version_id
        ? admin.from("character_versions").select("*").eq("id", character.current_canon_version_id).maybeSingle()
        : Promise.resolve({ data: null }),
    ]);

    if (commitError || !commit) {
      return jsonResponse({ error: "Commit not found." }, 404);
    }

    const timestamp = (commit.created_at as string).replaceAll(":", "-");
    const basePath = Deno.env.get("GITHUB_BASE_PATH") ?? "";
    const commitPath = buildGithubPath(basePath, "commits", character.slug, `${timestamp}__${commit.id}.json`);
    const latestCanonPath = buildGithubPath(basePath, "canon", character.slug, "latest.json");
    const versionCanonPath = version
      ? buildGithubPath(basePath, "canon", character.slug, `v${String(version.version_no).padStart(3, "0")}.json`)
      : null;

    const exportPayload = {
      exported_at: new Date().toISOString(),
      character: {
        id: character.id,
        slug: character.slug,
        display_name: character.display_name,
      },
      commit,
      version,
    };

    const owner = Deno.env.get("GITHUB_OWNER") ?? "danvoulez";
    const repo = Deno.env.get("GITHUB_REPO") ?? "vox-os";
    const token = Deno.env.get("GITHUB_TOKEN");

    if (!owner || !repo || !token) {
      return jsonResponse({
        mode: "preview",
        files: [
          {
            path: commitPath,
            content: exportPayload,
          },
          ...(version
            ? [
              {
                path: latestCanonPath,
                content: version.snapshot,
              },
              {
                path: versionCanonPath,
                content: version.snapshot,
              },
            ]
            : []),
        ],
      });
    }

    const results = [];

    results.push(await putGithubFile({
      owner,
      repo,
      token,
      path: commitPath,
      content: JSON.stringify(exportPayload, null, 2),
      message: `vox-os: export commit ${commit.id} for ${character.slug}`,
    }));

    if (version) {
      results.push(await putGithubFile({
        owner,
        repo,
        token,
        path: latestCanonPath,
        content: JSON.stringify(version.snapshot, null, 2),
        message: `vox-os: update latest canon for ${character.slug}`,
      }));

      if (versionCanonPath) {
        results.push(await putGithubFile({
          owner,
          repo,
          token,
          path: versionCanonPath,
          content: JSON.stringify(version.snapshot, null, 2),
          message: `vox-os: snapshot canon v${version.version_no} for ${character.slug}`,
        }));
      }
    }

    return jsonResponse({
      mode: "exported",
      results,
    });
  } catch (error) {
    return handleError(error);
  }
});
