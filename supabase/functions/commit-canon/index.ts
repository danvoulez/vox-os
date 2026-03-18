import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { assertMethod, handleError, HttpError, jsonResponse, parseJson, requireString } from "../_shared/http.ts";
import { createAdminClient, getRequestUser } from "../_shared/supabase.ts";
import { applyCanonDiff, buildCanonSnapshot } from "../_shared/vox.ts";

Deno.serve(async (request) => {
  try {
    assertMethod(request, "POST");

    const body = await parseJson<Record<string, unknown>>(request);
    const characterId = requireString(body.character_id, "character_id");
    const title = requireString(body.title, "title");
    const summary = typeof body.summary === "string" ? body.summary : null;
    const sourceReviewId = requireString(body.source_review_id, "source_review_id");
    const diff = body.diff && typeof body.diff === "object" && !Array.isArray(body.diff)
      ? body.diff as Record<string, unknown>
      : {};

    const admin = createAdminClient();
    const user = await getRequestUser(request);
    if (!user) {
      return jsonResponse({ error: "Authentication required." }, 401);
    }

    const { data: review, error: reviewError } = await admin
      .from("reviews")
      .select("id, decision")
      .eq("id", sourceReviewId)
      .maybeSingle();

    if (reviewError || !review || review.decision !== "approve") {
      throw new HttpError(400, "A valid approved review is required before canon commit.");
    }

    const { data: character, error: characterError } = await admin
      .from("characters")
      .select("id, workspace_id, status, current_canon_version_id")
      .eq("id", characterId)
      .maybeSingle();

    if (characterError || !character) {
      return jsonResponse({ error: "Character not found." }, 404);
    }

    const [{ data: currentVersion }, { data: profile }, { data: axioms }, { count: versionCount }] = await Promise.all([
      character.current_canon_version_id
        ? admin.from("character_versions").select("id, snapshot, version_no").eq("id", character.current_canon_version_id).maybeSingle()
        : Promise.resolve({ data: null }),
      admin.from("character_profiles").select("*").eq("character_id", characterId).maybeSingle(),
      admin.from("character_axioms").select("id, category, statement, priority, is_mutable").eq("character_id", characterId),
      admin.from("character_versions").select("*", { count: "exact", head: true }).eq("character_id", characterId),
    ]);

    const baseSnapshot = buildCanonSnapshot(
      profile ?? null,
      axioms ?? [],
      currentVersion?.snapshot && typeof currentVersion.snapshot === "object"
        ? currentVersion.snapshot as Record<string, unknown>
        : null,
    );

    const nextSnapshot = applyCanonDiff(baseSnapshot, diff);
    const nextVersionNo = (versionCount ?? 0) + 1;

    const { data: version, error: versionError } = await admin
      .from("character_versions")
      .insert({
        character_id: characterId,
        version_no: nextVersionNo,
        title,
        snapshot: nextSnapshot,
        diff_from_previous: diff,
        created_by: user.id,
      })
      .select("*")
      .single();

    if (versionError) {
      throw versionError;
    }

    const { data: commit, error: commitError } = await admin
      .from("commits")
      .insert({
        character_id: characterId,
        commit_type: "canon",
        title,
        summary,
        diff,
        source_review_id: sourceReviewId,
        authored_by: user.id,
      })
      .select("*")
      .single();

    if (commitError) {
      throw commitError;
    }

    await admin
      .from("characters")
      .update({
        current_canon_version_id: version.id,
        status: character.status === "draft" ? "active" : character.status,
      })
      .eq("id", characterId);

    await admin.from("audit_logs").insert({
      workspace_id: character.workspace_id,
      actor_id: user.id,
      action: "canon.committed",
      target_type: "character_version",
      target_id: version.id,
      payload: {
        character_id: characterId,
        commit_id: commit.id,
        version_no: nextVersionNo,
      },
    });

    return jsonResponse({
      data: {
        version,
        commit,
      },
    }, 201);
  } catch (error) {
    return handleError(error);
  }
});

