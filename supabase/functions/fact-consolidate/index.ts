import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { assertMethod, handleError, jsonResponse, parseJson, requireArray, requireString } from "../_shared/http.ts";
import { createAdminClient, getRequestUser } from "../_shared/supabase.ts";
import { average, summarizeEventsToFact } from "../_shared/vox.ts";

Deno.serve(async (request) => {
  try {
    assertMethod(request, "POST");

    const body = await parseJson<Record<string, unknown>>(request);
    const characterId = requireString(body.character_id, "character_id");
    const eventIds = requireArray(body.event_ids, "event_ids").map((value) => requireString(value, "event_ids[]"));

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

    const { data: events, error: eventsError } = await admin
      .from("memory_events")
      .select("id, payload, importance_score, confidence_score")
      .eq("character_id", characterId)
      .in("id", eventIds);

    if (eventsError) {
      throw eventsError;
    }

    if (!events || events.length === 0) {
      return jsonResponse({ error: "No events found for consolidation." }, 404);
    }

    const statement = summarizeEventsToFact(events);
    const confidence = average(events.map((event) => Number(event.confidence_score ?? 0.5)));

    const { data: fact, error: factError } = await admin
      .from("memory_facts")
      .insert({
        character_id: characterId,
        fact_type: "semantic",
        statement,
        supporting_event_ids: eventIds,
        confidence_score: Math.round(confidence * 100) / 100,
        status: "candidate",
      })
      .select("*")
      .single();

    if (factError) {
      throw factError;
    }

    await admin
      .from("memory_events")
      .update({ review_state: "consolidated" })
      .in("id", eventIds)
      .eq("character_id", characterId);

    await admin.from("audit_logs").insert({
      workspace_id: character.workspace_id,
      actor_id: actorId,
      action: "memory_fact.consolidated",
      target_type: "memory_fact",
      target_id: fact.id,
      payload: {
        character_id: characterId,
        event_ids: eventIds,
      },
    });

    return jsonResponse({ data: fact }, 201);
  } catch (error) {
    return handleError(error);
  }
});

