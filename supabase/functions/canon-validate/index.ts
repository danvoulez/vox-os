import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { assertMethod, handleError, jsonResponse, parseJson, requireString } from "../_shared/http.ts";
import { createAdminClient } from "../_shared/supabase.ts";

Deno.serve(async (request) => {
  try {
    assertMethod(request, "POST");

    const body = await parseJson<Record<string, unknown>>(request);
    const characterId = requireString(body.character_id, "character_id");
    const candidatePayload = body.candidate_payload && typeof body.candidate_payload === "object" && !Array.isArray(body.candidate_payload)
      ? body.candidate_payload as Record<string, unknown>
      : {};

    const admin = createAdminClient();
    const { data: character, error: characterError } = await admin
      .from("characters")
      .select("id, current_canon_version_id")
      .eq("id", characterId)
      .maybeSingle();

    if (characterError || !character) {
      return jsonResponse({ error: "Character not found." }, 404);
    }

    const [{ data: version }, { data: axioms }] = await Promise.all([
      character.current_canon_version_id
        ? admin.from("character_versions").select("snapshot").eq("id", character.current_canon_version_id).maybeSingle()
        : Promise.resolve({ data: null }),
      admin.from("character_axioms").select("category, statement, is_mutable").eq("character_id", characterId),
    ]);

    const snapshot = version?.snapshot && typeof version.snapshot === "object" ? version.snapshot as Record<string, unknown> : {};
    const issues: Array<Record<string, unknown>> = [];

    const currentName = ((snapshot.identity as Record<string, unknown> | undefined)?.display_name ?? null);
    const candidateName = ((candidatePayload.identity as Record<string, unknown> | undefined)?.display_name ?? null);
    if (typeof currentName === "string" && typeof candidateName === "string" && currentName !== candidateName) {
      issues.push({
        type: "identity_shift",
        message: "display_name diverges from current canon",
      });
    }

    for (const axiom of axioms ?? []) {
      if (axiom.is_mutable === false && typeof axiom.statement === "string") {
        const statement = axiom.statement.toLowerCase();
        const candidateText = JSON.stringify(candidatePayload).toLowerCase();
        if (statement.includes("never") && candidateText.length > 0 && !candidateText.includes(statement.replace("never ", ""))) {
          continue;
        }
      }
    }

    const score = Math.max(0, 1 - issues.length * 0.2);

    return jsonResponse({
      status: issues.length === 0 ? "ok" : "warning",
      score: Math.round(score * 100) / 100,
      issues,
    });
  } catch (error) {
    return handleError(error);
  }
});

