import { HttpError } from "./http.ts";

export type JsonValue =
  | null
  | boolean
  | number
  | string
  | JsonValue[]
  | { [key: string]: JsonValue };

export function extractTextFromUnknown(value: unknown): string {
  const parts: string[] = [];

  const walk = (input: unknown) => {
    if (typeof input === "string") {
      const trimmed = input.trim();
      if (trimmed) {
        parts.push(trimmed);
      }
      return;
    }

    if (Array.isArray(input)) {
      input.forEach(walk);
      return;
    }

    if (input && typeof input === "object") {
      Object.values(input).forEach(walk);
    }
  };

  walk(value);

  return parts.join(" ").replace(/\s+/g, " ").trim();
}

export function scoreMemoryEvent(payload: unknown, eventType: string) {
  const text = extractTextFromUnknown(payload);
  const lengthFactor = Math.min(text.length / 280, 1);
  const signalBoost = /\b(canon|axiom|recurring|always|never|look|visual|scene)\b/i.test(text) ? 0.2 : 0;
  const eventBoost = ["interaction", "scene", "appearance", "canon_hint"].includes(eventType) ? 0.15 : 0.05;

  const importance = clamp(0.25 + lengthFactor * 0.4 + signalBoost + eventBoost);
  const novelty = clamp(0.4 + lengthFactor * 0.3);
  const confidence = clamp(text.length > 0 ? 0.8 : 0.55);

  return {
    importance_score: round2(importance),
    novelty_score: round2(novelty),
    confidence_score: round2(confidence),
  };
}

export function summarizeEventsToFact(events: Array<Record<string, unknown>>): string {
  const texts = events
    .map((event) => extractTextFromUnknown(event.payload))
    .map((text) => text.replace(/\s+/g, " ").trim())
    .filter(Boolean);

  if (texts.length === 0) {
    throw new HttpError(400, "Could not derive a fact from the provided events.");
  }

  if (texts.length === 1) {
    return texts[0];
  }

  const uniqueTexts = [...new Set(texts)];
  return `Recurring observation: ${uniqueTexts.slice(0, 3).join(" | ")}`;
}

export function buildCanonSnapshot(profile: Record<string, unknown> | null, axioms: Array<Record<string, unknown>>, existingSnapshot: Record<string, unknown> | null) {
  const baseSnapshot = existingSnapshot ? structuredClone(existingSnapshot) : {};

  const nextSnapshot = {
    ...baseSnapshot,
    identity: {
      ...(asRecord(baseSnapshot.identity) ?? {}),
      short_bio: profile?.short_bio ?? asRecord(baseSnapshot.identity)?.short_bio ?? null,
      archetype: profile?.archetype ?? asRecord(baseSnapshot.identity)?.archetype ?? null,
      public_summary: profile?.public_summary ?? asRecord(baseSnapshot.identity)?.public_summary ?? null,
    },
    tone: profile?.tone_profile ?? asRecord(baseSnapshot.tone) ?? {},
    voice: profile?.voice_profile ?? asRecord(baseSnapshot.voice) ?? {},
    appearance: profile?.appearance_profile ?? asRecord(baseSnapshot.appearance) ?? {},
    relationships: profile?.relationship_profile ?? asRecord(baseSnapshot.relationships) ?? {},
    axioms: axioms
      .map((axiom) => ({
        id: axiom.id,
        category: axiom.category,
        statement: axiom.statement,
        priority: axiom.priority,
        is_mutable: axiom.is_mutable,
      }))
      .sort((left, right) => Number(left.priority ?? 0) - Number(right.priority ?? 0)),
  };

  return nextSnapshot;
}

export function applyCanonDiff(snapshot: Record<string, unknown>, diff: Record<string, unknown>) {
  const next = structuredClone(snapshot);

  for (const [rawPath, instruction] of Object.entries(diff)) {
    const path = rawPath.split(".");
    const currentValue = getAtPath(next, path);

    if (instruction && typeof instruction === "object" && !Array.isArray(instruction)) {
      const typedInstruction = instruction as Record<string, unknown>;

      if ("set" in typedInstruction) {
        setAtPath(next, path, typedInstruction.set);
        continue;
      }

      if ("merge" in typedInstruction) {
        setAtPath(next, path, {
          ...(asRecord(currentValue) ?? {}),
          ...(asRecord(typedInstruction.merge) ?? {}),
        });
        continue;
      }

      if ("add" in typedInstruction || "remove" in typedInstruction) {
        const currentArray = Array.isArray(currentValue) ? [...currentValue] : [];
        const additions = Array.isArray(typedInstruction.add) ? typedInstruction.add : [];
        const removals = new Set(Array.isArray(typedInstruction.remove) ? typedInstruction.remove : []);
        const merged = [...currentArray, ...additions].filter((item, index, array) => {
          const signature = JSON.stringify(item);
          return !removals.has(item) && array.findIndex((candidate) => JSON.stringify(candidate) === signature) === index;
        });
        setAtPath(next, path, merged);
        continue;
      }
    }

    setAtPath(next, path, instruction);
  }

  return next;
}

export function buildDraftOutput(input: {
  displayName: string;
  draftType: string;
  sceneName?: string | null;
  goal?: string | null;
  constraints?: string[];
}) {
  const sceneLine = input.sceneName ? `Scene: ${input.sceneName}.` : "Scene: general context.";
  const goalLine = input.goal ? `Goal: ${input.goal}.` : "Goal: preserve canon while producing a usable draft.";
  const constraintsLine = input.constraints && input.constraints.length > 0
    ? `Constraints: ${input.constraints.join(", ")}.`
    : "Constraints: stay consistent with canon.";

  const text = [
    `${input.displayName} ${draftTypeLabel(input.draftType)} draft.`,
    sceneLine,
    goalLine,
    constraintsLine,
  ].join(" ");

  return {
    mode: "template",
    text,
  };
}

export function detectForbiddenTerms(text: string, terms: string[]) {
  const loweredText = text.toLowerCase();
  return terms.filter((term) => loweredText.includes(term.toLowerCase()));
}

export function average(values: number[]) {
  if (values.length === 0) {
    return 0;
  }

  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

export function encodeBase64(value: string) {
  const bytes = new TextEncoder().encode(value);
  let binary = "";

  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary);
}

function draftTypeLabel(draftType: string) {
  switch (draftType) {
    case "caption":
      return "caption";
    case "script":
      return "script";
    case "dialogue":
      return "dialogue";
    case "scene_plan":
      return "scene-plan";
    case "voice_line":
      return "voice line";
    default:
      return "draft";
  }
}

function clamp(value: number) {
  return Math.max(0, Math.min(1, value));
}

function round2(value: number) {
  return Math.round(value * 100) / 100;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : null;
}

function getAtPath(target: Record<string, unknown>, path: string[]) {
  let cursor: unknown = target;

  for (const segment of path) {
    if (!cursor || typeof cursor !== "object" || Array.isArray(cursor)) {
      return undefined;
    }

    cursor = (cursor as Record<string, unknown>)[segment];
  }

  return cursor;
}

function setAtPath(target: Record<string, unknown>, path: string[], value: unknown) {
  let cursor: Record<string, unknown> = target;

  for (const segment of path.slice(0, -1)) {
    const next = cursor[segment];
    if (!next || typeof next !== "object" || Array.isArray(next)) {
      cursor[segment] = {};
    }

    cursor = cursor[segment] as Record<string, unknown>;
  }

  cursor[path[path.length - 1]] = value;
}

