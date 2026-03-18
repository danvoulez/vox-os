import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { assertMethod, handleError, jsonResponse, parseJson, requireString } from "../_shared/http.ts";
import { createAdminClient, getRequestUser } from "../_shared/supabase.ts";
import { buildDraftOutput } from "../_shared/vox.ts";

Deno.serve(async (request) => {
  try {
    assertMethod(request, "POST");

    const body = await parseJson<Record<string, unknown>>(request);
    const characterId = requireString(body.character_id, "character_id");
    const draftType = requireString(body.draft_type, "draft_type");
    const sceneId = typeof body.scene_id === "string" ? body.scene_id : null;
    const inputPayload = body.input ?? body.input_payload ?? {};

    const admin = createAdminClient();
    const user = await getRequestUser(request);
    const actorId = user?.id ?? null;

    const { data: character, error: characterError } = await admin
      .from("characters")
      .select("id, workspace_id, display_name, current_canon_version_id")
      .eq("id", characterId)
      .maybeSingle();

    if (characterError || !character) {
      return jsonResponse({ error: "Character not found." }, 404);
    }

    const [{ data: version }, { data: profile }, { data: axioms }, { data: scene }, { data: assets }] = await Promise.all([
      character.current_canon_version_id
        ? admin.from("character_versions").select("id, version_no, snapshot").eq("id", character.current_canon_version_id).maybeSingle()
        : Promise.resolve({ data: null }),
      admin.from("character_profiles").select("*").eq("character_id", characterId).maybeSingle(),
      admin.from("character_axioms").select("category, statement, priority, is_mutable").eq("character_id", characterId).order("priority", { ascending: true }),
      sceneId
        ? admin.from("scenes").select("id, name, setting, mood, behavior_notes, visual_notes").eq("id", sceneId).eq("character_id", characterId).maybeSingle()
        : Promise.resolve({ data: null }),
      admin.from("assets")
        .select("id, asset_type, metadata, status")
        .eq("character_id", characterId)
        .in("status", ["approved", "canonical"])
        .limit(8),
    ]);

    const inputRecord = inputPayload && typeof inputPayload === "object" && !Array.isArray(inputPayload)
      ? inputPayload as Record<string, unknown>
      : {};

    const outputPayload = {
      ...buildDraftOutput({
        displayName: character.display_name,
        draftType,
        sceneName: scene?.name ?? null,
        goal: typeof inputRecord.goal === "string" ? inputRecord.goal : null,
        constraints: Array.isArray(inputRecord.constraints)
          ? inputRecord.constraints.filter((value): value is string => typeof value === "string")
          : [],
      }),
      context: {
        canon_version_id: version?.id ?? null,
        canon_version_no: version?.version_no ?? null,
        scene,
        profile,
        axioms: axioms ?? [],
        approved_assets: assets ?? [],
      },
    };

    const { data: draft, error: draftError } = await admin
      .from("drafts")
      .insert({
        character_id: characterId,
        scene_id: sceneId,
        based_on_version_id: version?.id ?? null,
        draft_type: draftType,
        input_payload: inputPayload,
        output_payload: outputPayload,
        status: "draft",
        created_by: actorId,
      })
      .select("*")
      .single();

    if (draftError) {
      throw draftError;
    }

    await admin.from("audit_logs").insert({
      workspace_id: character.workspace_id,
      actor_id: actorId,
      action: "draft.generated",
      target_type: "draft",
      target_id: draft.id,
      payload: {
        character_id: characterId,
        draft_type: draftType,
        scene_id: sceneId,
      },
    });

    return jsonResponse({ data: draft }, 201);
  } catch (error) {
    return handleError(error);
  }
});

