import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { assertMethod, handleError, jsonResponse, parseJson, requireString } from "../_shared/http.ts";
import { createAdminClient, getRequestUser } from "../_shared/supabase.ts";
import { scoreMemoryEvent } from "../_shared/vox.ts";

Deno.serve(async (request) => {
  try {
    assertMethod(request, "POST");

    const body = await parseJson<Record<string, unknown>>(request);
    const characterId = requireString(body.character_id, "character_id");
    const eventType = requireString(body.event_type, "event_type");
    const sourceType = requireString(body.source_type, "source_type");
    const payload = body.payload ?? {};
    const sourceRef = typeof body.source_ref === "string" ? body.source_ref : null;
    const sceneId = typeof body.scene_id === "string" ? body.scene_id : null;
    const eventAt = typeof body.event_at === "string" ? body.event_at : new Date().toISOString();

    const admin = createAdminClient();
    const user = await getRequestUser(request);
    const actorId = user?.id ?? null;

    const { data: character, error: characterError } = await admin
      .from("characters")
      .select("id, workspace_id")
      .eq("id", characterId)
      .maybeSingle();

    if (characterError || !character) {
      return jsonResponse({ error: "Character not found." }, 404);
    }

    const scores = scoreMemoryEvent(payload, eventType);

    const { data: event, error: insertError } = await admin
      .from("memory_events")
      .insert({
        character_id: characterId,
        event_type: eventType,
        source_type: sourceType,
        source_ref: sourceRef,
        scene_id: sceneId,
        payload,
        review_state: "new",
        event_at: eventAt,
        ...scores,
      })
      .select("*")
      .single();

    if (insertError) {
      throw insertError;
    }

    await admin.from("audit_logs").insert({
      workspace_id: character.workspace_id,
      actor_id: actorId,
      action: "memory_event.ingested",
      target_type: "memory_event",
      target_id: event.id,
      payload: {
        character_id: characterId,
        event_type: eventType,
        source_type: sourceType,
      },
    });

    return jsonResponse({ data: event }, 201);
  } catch (error) {
    return handleError(error);
  }
});

