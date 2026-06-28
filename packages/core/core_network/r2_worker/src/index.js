const MEDIA_RULES = {
  video: {
    maxBytes: 250 * 1024 * 1024,
    allowedContentTypes: new Set(['video/mp4', 'video/quicktime']),
    defaultExtension: 'mp4',
  },
  cover: {
    maxBytes: 15 * 1024 * 1024,
    allowedContentTypes: new Set(['image/webp', 'image/jpeg', 'image/png']),
    defaultExtension: 'webp',
  },
};

function toHex(buffer) {
  return [...new Uint8Array(buffer)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

export default {
  async fetch(request, env) {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, PUT, OPTIONS',
      'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    };
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method === 'GET' && url.pathname.startsWith('/objects/')) {
      const objectKey = decodeURIComponent(url.pathname.replace('/objects/', ''));
      if (!objectKey) {
        return new Response('Missing object key', { status: 400, headers: corsHeaders });
      }

      const object = await env.MEDIA_BUCKET.get(objectKey);
      if (!object) {
        return new Response('Object not found', { status: 404, headers: corsHeaders });
      }

      const headers = new Headers(corsHeaders);
      object.writeHttpMetadata(headers);
      headers.set('etag', object.httpEtag);

      return new Response(object.body, {
        headers,
      });
    }

    if (request.method !== 'PUT') {
      return new Response('Method not allowed', { status: 405 });
    }

    const authorization = request.headers.get('Authorization') || '';
    if (!authorization.startsWith('Bearer ')) {
      return new Response('Missing bearer token', { status: 401, headers: corsHeaders });
    }

    const authResponse = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
      headers: {
        Authorization: authorization,
        apikey: env.SUPABASE_ANON_KEY,
      },
    });

    if (!authResponse.ok) {
      return new Response('Unauthorized upload request', {
        status: 401,
        headers: corsHeaders,
      });
    }

    const user = await authResponse.json();
    const ownerId = user.id;

    const filename = url.searchParams.get('filename');
    const mediaKind = url.searchParams.get('kind');
    if (!filename || !mediaKind) {
      return new Response('Missing filename or kind', {
        status: 400,
        headers: corsHeaders,
      });
    }

    if (!Object.keys(MEDIA_RULES).includes(mediaKind)) {
      return new Response('Unsupported media kind', {
        status: 400,
        headers: corsHeaders,
      });
    }

    const rules = MEDIA_RULES[mediaKind];
    const safeFileName = filename.replace(/[^a-zA-Z0-9._-]/g, '_');
    const extension = safeFileName.includes('.')
      ? safeFileName.split('.').pop()
      : rules.defaultExtension;
    const objectKey =
      `users/${ownerId}/${mediaKind}/${Date.now()}-${crypto.randomUUID()}.${extension}`;
    const contentType =
      request.headers.get('Content-Type') || '';

    if (!rules.allowedContentTypes.has(contentType)) {
      return new Response('Unsupported content type', {
        status: 415,
        headers: corsHeaders,
      });
    }

    const bodyBuffer = await request.arrayBuffer();
    const contentLength = bodyBuffer.byteLength;
    if (contentLength === 0) {
      return new Response('Empty upload body', {
        status: 400,
        headers: corsHeaders,
      });
    }

    if (contentLength > rules.maxBytes) {
      return new Response('Payload too large', {
        status: 413,
        headers: corsHeaders,
      });
    }

    const checksumSha256 = toHex(await crypto.subtle.digest('SHA-256', bodyBuffer));

    await env.MEDIA_BUCKET.put(objectKey, bodyBuffer, {
      httpMetadata: {
        contentType,
      },
      customMetadata: {
        ownerId,
        mediaKind,
        originalFilename: safeFileName,
        checksumSha256,
      },
    });

    return new Response(
      JSON.stringify({
        success: true,
        ownerId,
        mediaKind,
        objectKey,
        publicUrl: `${env.PUBLIC_MEDIA_BASE_URL}/${objectKey}`,
        contentType,
        bytes: contentLength,
        checksumSha256,
        sourceFilename: safeFileName,
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders,
        },
      },
    );
  }
};
