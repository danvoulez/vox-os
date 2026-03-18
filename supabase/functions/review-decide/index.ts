import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { assertMethod, handleError, jsonResponse, parseJson, requireString } from "../_shared/http.ts";
import { createAdminClient, getRequestUser } from "../_shared/supabase.ts";

function reviewMutation(targetType: string, decision: string) {
  if (targetType === "fact") {
    if (decision === "approve") {
      return { table: "memory_facts", values: { status: "approved" } };
    }
    if (decision === "reject") {
      return { table: "memory_facts", values: { status: "rejected" } };
    }
    return { table: "memory_facts", values: { status: "candidate" } };
  }

  if (targetType === "draft") {
    if (decision === "approve") {
      return { table: "drafts", values: { status: "approved" } };
    }
    if (decision === "reject") {
      return { table: "drafts", values: { status: "rejected" } };
    }
    return { table: "drafts", values: { status: "in_review" } };
  }

  if (targetType === "asset") {
    if (decision === "approve") {
      return { table: "assets", values: { status: "approved" } };
    }
    if (decision === "reject") {
      return { table: "assets", values: { status: "archived" } };
    }
    return { table: "assets", values: { status: "draft" } };
  }

  if (targetType === "scene") {
    if (decision === "approve") {
      return { table: "scenes", values: { status: "approved" } };
    }
    if (decision === "reject") {
      return { table: "scenes", values: { status: "archived" } };
    }
    return { table: "scenes", values: { status: "draft" } };
  }

  return null;
}

Deno.serve(async (request) => {
  try {
    assertMethod(request, "POST");

    const body = await parseJson<Record<string, unknown>>(request);
    const targetType = requireString(body.target_type, "target_type");
    const targetId = requireString(body.target_id, "target_id");
    const decision = requireString(body.decision, "decision");
    const notes = typeof body.notes === "string" ? body.notes : null;

    const admin = createAdminClient();
    const user = await getRequestUser(request);
    if (!user) {
      return jsonResponse({ error: "Authentication required." }, 401);
    }

    let characterId: string | null = null;

    if (targetType === "fact") {
      const { data } = await admin.from("memory_facts").select("character_id").eq("id", targetId).maybeSingle();
      characterId = data?.character_id ?? null;
    } else if (targetType === "draft") {
      const { data } = await admin.from("drafts").select("character_id").eq("id", targetId).maybeSingle();
      characterId = data?.character_id ?? null;
    } else if (targetType === "asset") {
      const { data } = await admin.from("assets").select("character_id").eq("id", targetId).maybeSingle();
      characterId = data?.character_id ?? null;
    } else if (targetType === "scene") {
      const { data } = await admin.from("scenes").select("character_id").eq("id", targetId).maybeSingle();
      characterId = data?.character_id ?? null;
    }

    if (!characterId) {
      return jsonResponse({ error: "Target not found or unsupported." }, 404);
    }

    const { data: character } = await admin
      .from("characters")
      .select("workspace_id")
      .eq("id", characterId)
      .maybeSingle();

    const { data: review, error: reviewError } = await admin
      .from("reviews")
      .insert({
        target_type: targetType,
        target_id: targetId,
        decision,
        notes,
        reviewed_by: user.id,
      })
      .select("*")
      .single();

    if (reviewError) {
      throw reviewError;
    }

    const mutation = reviewMutation(targetType, decision);
    if (mutation) {
      const patch = {
        ...mutation.values,
        ...(targetType === "fact" && decision === "approve"
          ? { approved_by: user.id, approved_at: new Date().toISOString() }
          : {}),
      };

      await admin.from(mutation.table).update(patch).eq("id", targetId);
    }

    if (character?.workspace_id) {
      await admin.from("audit_logs").insert({
        workspace_id: character.workspace_id,
        actor_id: user.id,
        action: "review.decided",
        target_type: targetType,
        target_id: targetId,
        payload: {
          decision,
          review_id: review.id,
        },
      });
    }

    return jsonResponse({ data: review }, 201);
  } catch (error) {
    return handleError(error);
  }
});

