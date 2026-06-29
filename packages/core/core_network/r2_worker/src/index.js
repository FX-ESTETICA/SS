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
  avatar: {
    maxBytes: 15 * 1024 * 1024,
    allowedContentTypes: new Set(['image/webp', 'image/jpeg', 'image/png']),
    defaultExtension: 'webp',
  },
  stream: {
    maxBytes: 250 * 1024 * 1024,
    allowedContentTypes: new Set([
      'application/vnd.apple.mpegurl',
      'application/x-mpegURL',
      'video/mp4',
      'application/octet-stream',
    ]),
    defaultExtension: 'm3u8',
  },
};

const TARGET_VIDEO_WIDTH = 1080;
const TARGET_VIDEO_HEIGHT = 1920;

function getCacheControl(objectKey) {
  if (objectKey.includes('/stream/')) {
    return 'public, max-age=31536000, immutable';
  }

  if (objectKey.includes('/cover/')) {
    return 'public, max-age=604800, stale-while-revalidate=86400';
  }

  if (objectKey.includes('/avatar/')) {
    return 'public, max-age=604800, stale-while-revalidate=86400';
  }

  if (objectKey.includes('/video/')) {
    return 'public, max-age=86400, stale-while-revalidate=604800';
  }

  return 'public, max-age=3600';
}

function toHex(buffer) {
  return [...new Uint8Array(buffer)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function getSupabaseHeaders(env, authorization) {
  return {
    Authorization: authorization,
    apikey: env.SUPABASE_ANON_KEY,
    'Content-Type': 'application/json',
  };
}

async function fetchUploadSession(env, authorization, uploadSessionId) {
  const sessionUrl =
    `${env.SUPABASE_URL}/rest/v1/media_upload_sessions` +
    `?select=id,media_kind,source_filename,content_type,file_size_bytes,object_prefix,status,expires_at,retry_count,output_payload` +
    `&id=eq.${encodeURIComponent(uploadSessionId)}`;
  const response = await fetch(sessionUrl, {
    headers: getSupabaseHeaders(env, authorization),
  });

  if (!response.ok) {
    return null;
  }

  const rows = await response.json();
  if (!Array.isArray(rows) || rows.length === 0) {
    return null;
  }
  return rows[0];
}

async function updateUploadSession(env, authorization, uploadSessionId, payload) {
  await fetch(
    `${env.SUPABASE_URL}/rest/v1/media_upload_sessions?id=eq.${encodeURIComponent(uploadSessionId)}`,
    {
      method: 'PATCH',
      headers: getSupabaseHeaders(env, authorization),
      body: JSON.stringify(payload),
    },
  );
}

async function setUploadSessionFailed(env, authorization, uploadSessionId, errorMessage) {
  if (!uploadSessionId) {
    return;
  }
  const session = await fetchUploadSession(env, authorization, uploadSessionId);
  const retryCount = Number.parseInt(`${session?.retry_count ?? 0}`, 10) || 0;
  await updateUploadSession(env, authorization, uploadSessionId, {
    status: 'failed',
    last_error_code: 'worker_upload_failed',
    last_error_message: errorMessage,
    retry_count: retryCount + 1,
  });
}

function buildUploadedSessionResponse(session, ownerId, mediaKind, corsHeaders) {
  const payload = session?.output_payload ?? {};
  const objectKey = payload.objectKey || '';
  const publicUrl = payload.publicUrl || '';
  if (!objectKey || !publicUrl) {
    return null;
  }

  return new Response(
    JSON.stringify({
      success: true,
      ownerId,
      mediaKind,
      uploadSessionId: session?.id || '',
      objectKey,
      objectPrefix: payload.objectPrefix || session?.object_prefix || '',
      publicUrl,
      contentType: payload.contentType || session?.content_type || 'application/octet-stream',
      bytes: session?.file_size_bytes || 0,
      checksumSha256: payload.checksumSha256 || '',
      sourceFilename: session?.source_filename || '',
    }),
    {
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders,
      },
    },
  );
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
      headers.set('cache-control', getCacheControl(objectKey));

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
    const widthParam = url.searchParams.get('width');
    const heightParam = url.searchParams.get('height');
    const prefixParam = url.searchParams.get('prefix');
    const uploadSessionId = url.searchParams.get('upload_session_id');
    const parsedWidth = widthParam ? Number.parseInt(widthParam, 10) : null;
    const parsedHeight = heightParam ? Number.parseInt(heightParam, 10) : null;
    let safePrefix = prefixParam
      ? prefixParam.replace(/[^a-zA-Z0-9/_-]/g, '_').replace(/^\/+|\/+$/g, '')
      : '';
    const safeFileName = filename.replace(/[^a-zA-Z0-9._-]/g, '_');
    const extension = safeFileName.includes('.')
      ? safeFileName.split('.').pop()
      : rules.defaultExtension;
    const objectKey = safePrefix
      ? `users/${ownerId}/${mediaKind}/${safePrefix}/${safeFileName}`
      : `users/${ownerId}/${mediaKind}/${Date.now()}-${crypto.randomUUID()}.${extension}`;
    const contentType =
      request.headers.get('Content-Type') || '';

    if (uploadSessionId) {
      const uploadSession = await fetchUploadSession(
        env,
        authorization,
        uploadSessionId,
      );
      if (!uploadSession) {
        return new Response('Upload session not found', {
          status: 404,
          headers: corsHeaders,
        });
      }

      if (
        uploadSession.status === 'uploaded' ||
        uploadSession.status === 'consumed'
      ) {
        const existingResponse = buildUploadedSessionResponse(
          uploadSession,
          ownerId,
          mediaKind,
          corsHeaders,
        );
        if (existingResponse != null) {
          return existingResponse;
        }
      }

      if (
        uploadSession.status !== 'issued' &&
        uploadSession.status !== 'uploading'
      ) {
        return new Response('Upload session is not writable', {
          status: 409,
          headers: corsHeaders,
        });
      }

      if (uploadSession.media_kind !== mediaKind) {
        return new Response('Upload session kind mismatch', {
          status: 409,
          headers: corsHeaders,
        });
      }

      if (
        uploadSession.source_filename &&
        uploadSession.source_filename !== safeFileName
      ) {
        return new Response('Upload session filename mismatch', {
          status: 409,
          headers: corsHeaders,
        });
      }

      if (
        uploadSession.content_type &&
        uploadSession.content_type !== contentType
      ) {
        return new Response('Upload session content type mismatch', {
          status: 409,
          headers: corsHeaders,
        });
      }

      if (uploadSession.expires_at && Date.parse(uploadSession.expires_at) < Date.now()) {
        return new Response('Upload session expired', {
          status: 410,
          headers: corsHeaders,
        });
      }

      if (uploadSession.object_prefix) {
        safePrefix = uploadSession.object_prefix;
      }

      await updateUploadSession(env, authorization, uploadSessionId, {
        status: 'uploading',
        last_error_code: null,
        last_error_message: null,
      });
    }

    if (!rules.allowedContentTypes.has(contentType)) {
      return new Response('Unsupported content type', {
        status: 415,
        headers: corsHeaders,
      });
    }

    if (
      parsedWidth !== null &&
      (!Number.isInteger(parsedWidth) || parsedWidth <= 0)
    ) {
      return new Response('Invalid width', {
        status: 400,
        headers: corsHeaders,
      });
    }

    if (
      parsedHeight !== null &&
      (!Number.isInteger(parsedHeight) || parsedHeight <= 0)
    ) {
      return new Response('Invalid height', {
        status: 400,
        headers: corsHeaders,
      });
    }

    if (
      (mediaKind === 'video' || mediaKind === 'cover' || mediaKind === 'stream') &&
      (parsedWidth !== null || parsedHeight !== null) &&
      (parsedWidth !== TARGET_VIDEO_WIDTH || parsedHeight !== TARGET_VIDEO_HEIGHT)
    ) {
      return new Response('Unsupported media dimensions', {
        status: 400,
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

    try {
      await env.MEDIA_BUCKET.put(objectKey, bodyBuffer, {
        httpMetadata: {
          contentType,
          cacheControl: getCacheControl(objectKey),
        },
        customMetadata: {
          ownerId,
          mediaKind,
          originalFilename: safeFileName,
          checksumSha256,
          width: parsedWidth ? `${parsedWidth}` : '',
          height: parsedHeight ? `${parsedHeight}` : '',
          objectPrefix: safePrefix,
          processingProfile:
            mediaKind === 'stream'
              ? 'hls-single-1080x1920-v1'
              : parsedWidth === TARGET_VIDEO_WIDTH &&
                    parsedHeight === TARGET_VIDEO_HEIGHT
                ? 'master-1080x1920-v1'
                : 'passthrough',
        },
      });
    } catch (error) {
      await setUploadSessionFailed(
        env,
        authorization,
        uploadSessionId,
        error instanceof Error ? error.message : 'unknown_worker_upload_error',
      );
      return new Response('Worker failed to persist object', {
        status: 500,
        headers: corsHeaders,
      });
    }

    if (uploadSessionId) {
      await updateUploadSession(env, authorization, uploadSessionId, {
        status: 'uploaded',
        bytes_uploaded: contentLength,
        completed_at: new Date().toISOString(),
        output_payload: {
          objectKey,
          objectPrefix: safePrefix,
          publicUrl: `${env.PUBLIC_MEDIA_BASE_URL}/${objectKey}`,
          checksumSha256,
          contentType,
        },
        last_error_code: null,
        last_error_message: null,
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        ownerId,
        mediaKind,
        uploadSessionId: uploadSessionId || '',
        objectKey,
        publicUrl: `${env.PUBLIC_MEDIA_BASE_URL}/${objectKey}`,
        contentType,
        bytes: contentLength,
        checksumSha256,
        sourceFilename: safeFileName,
        width: parsedWidth,
        height: parsedHeight,
        objectPrefix: safePrefix,
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
