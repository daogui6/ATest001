import http from '@ohos.net.http';

const HTTP_TIMEOUT = 15000;
const MAX_CONTENT_LENGTH = 8000;

function stripHtml(raw: string): string {
  const withoutScripts = raw
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, '');

  const withNewlines = withoutScripts.replace(/<\/(p|div|li|h[1-6]|br|tr)>/gi, '\n');
  return withNewlines
    .replace(/<[^>]+>/g, ' ')
    .replace(/\r/g, '')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n{2,}/g, '\n')
    .trim();
}

function clampContent(content: string): string {
  if (content.length <= MAX_CONTENT_LENGTH) {
    return content;
  }
  return `${content.slice(0, MAX_CONTENT_LENGTH)}\n（正文过长，仅截取前${MAX_CONTENT_LENGTH}字）`;
}

export async function fetchArticleContent(link: string): Promise<string> {
  const client = http.createHttp();
  try {
    const resp = await client.request(link, {
      method: http.RequestMethod.GET,
      connectTimeout: HTTP_TIMEOUT,
      readTimeout: HTTP_TIMEOUT,
      expectDataType: http.HttpDataType.STRING,
      header: {
        'User-Agent': 'Mozilla/5.0 (HarmonyOS; AI Reader)'
      }
    });

    const status = resp.responseCode ?? 0;
    if (status < 200 || status >= 300) {
      throw new Error(`原文请求失败(${status})`);
    }

    const raw = String(resp.result ?? '');
    const text = stripHtml(raw);
    return clampContent(text);
  } finally {
    client.destroy();
  }
}