import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { assertMethod, handleError, jsonResponse, parseJson, requireString } from "../_shared/http.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import { detectForbiddenTerms, extractTextFromUnknown } from "../_shared/vox.ts";

Deno.serve(async (request) => {
  try {
    assertMethod(request, "POST");

    const body = await parseJson<Record<string, unknown>>(request);
    const characterId = requireString(body.character_id, "character_id");
    const sceneId = requireString(body.scene_id, "scene_id");
    const draftId = requireString(body.draft_id, "draft_id");

    const admin = createAdminClient();
    const [{ data: scene, error: sceneError }, { data: draft, error: draftError }] = await Promise.all([
      admin.from("scenes")
        .select("id, name, wardrobe_rules, allowed_props, forbidden_props")
        .eq("id", sceneId)
        .eq("character_id", characterId)
        .maybeSingle(),
      admin.from("drafts")
        .select("id, output_payload")
        .eq("id", draftId)
        .eq("character_id", characterId)
        .maybeSingle(),
    ]);

    if (sceneError || !scene) {
      return jsonResponse({ error: "Scene not found." }, 404);
    }

    if (draftError || !draft) {
      return jsonResponse({ error: "Draft not found." }, 404);
    }

    const outputText = extractTextFromUnknown(draft.output_payload);
    const forbiddenProps = Array.isArray(scene.forbidden_props)
      ? scene.forbidden_props.filter((value): value is string => typeof value === "string")
      : [];
    const wardrobeRules = scene.wardrobe_rules && typeof scene.wardrobe_rules === "object" && !Array.isArray(scene.wardrobe_rules)
      ? scene.wardrobe_rules as Record<string, unknown>
      : {};
    const forbiddenWardrobe = Array.isArray(wardrobeRules.forbidden)
      ? wardrobeRules.forbidden.filter((value): value is string => typeof value === "string")
      : [];

    const issues = [
      ...detectForbiddenTerms(outputText, forbiddenProps).map((term) => ({
        type: "scene_conflict",
        message: `forbidden prop detected: ${term}`,
      })),
      ...detectForbiddenTerms(outputText, forbiddenWardrobe).map((term) => ({
        type: "wardrobe_conflict",
        message: `forbidden wardrobe item detected: ${term}`,
      })),
    ];

    const result = {
      status: issues.length === 0 ? "ok" : "warning",
      score: Math.max(0, 1 - issues.length * 0.25),
      issues,
    };

    await admin
      .from("drafts")
      .update({ validation_payload: result })
      .eq("id", draftId)
      .eq("character_id", characterId);

    return jsonResponse(result);
  } catch (error) {
    return handleError(error);
  }
});

