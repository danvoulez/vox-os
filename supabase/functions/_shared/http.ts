export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

export class HttpError extends Error {
  status: number;
  details?: unknown;

  constructor(status: number, message: string, details?: unknown) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

export function jsonResponse(data: unknown, init?: number | ResponseInit): Response {
  const responseInit = typeof init === "number" ? { status: init } : init ?? { status: 200 };

  return new Response(JSON.stringify(data, null, 2), {
    ...responseInit,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders,
      ...(responseInit.headers ?? {}),
    },
  });
}

export async function parseJson<T>(request: Request): Promise<T> {
  try {
    return await request.json();
  } catch (error) {
    throw new HttpError(400, "Invalid JSON body.", error instanceof Error ? error.message : error);
  }
}

export function assertMethod(request: Request, method: string): void {
  if (request.method === "OPTIONS") {
    throw new HttpError(204, "No content");
  }

  if (request.method !== method) {
    throw new HttpError(405, `Method ${request.method} not allowed.`);
  }
}

export function handleError(error: unknown): Response {
  if (error instanceof HttpError) {
    if (error.status === 204) {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    return jsonResponse(
      {
        error: error.message,
        details: error.details ?? null,
      },
      error.status,
    );
  }

  console.error(error);

  return jsonResponse(
    {
      error: "Internal server error.",
      details: error instanceof Error ? error.message : String(error),
    },
    500,
  );
}

export function requireString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpError(400, `Field "${field}" is required.`);
  }

  return value.trim();
}

export function requireArray(value: unknown, field: string): unknown[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw new HttpError(400, `Field "${field}" must be a non-empty array.`);
  }

  return value;
}

