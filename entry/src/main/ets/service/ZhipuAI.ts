import http from '@ohos.net.http';

export type AiMode = 'summary' | 'review';

const API_KEY = '2d890ff673044875af844d4cdda8f356.FwfpRGVx5LtPaDCr';
const ENDPOINT = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
const MODEL = 'glm-4-flash'; // 免费模型一般用这个

function buildPrompt(title: string, content: string, mode: AiMode): string {
  const base = `文章标题：${title}\n\n文章内容：\n${content}\n\n`;

  if (mode === 'summary') {
    return base +
      `请用中文输出：\n` +
      `1) 用 5 条要点总结文章（每条不超过 25 字）\n` +
      `2) 给出 1 句“适合谁看/读完收获”\n` +
      `3) 给出 2 条可执行建议（如果文章偏观点，就给行动建议）\n` +
      `要求：结构清晰，避免空话。`;
  }

  // review
  return base +
    `请用中文输出“锐评”，风格像公众号的犀利评论，但不要人身攻击：\n` +
    `1) 先用 1 句话概括作者核心观点\n` +
    `2) 指出 3 个逻辑漏洞/证据不足点（要具体）\n` +
    `3) 给出 2 个改进方向（如何写更有说服力）\n` +
    `要求：观点明确、短句、有力度。`;
}

export async function callZhipu(title: string, content: string, mode: AiMode): Promise<string> {
  if (!API_KEY || API_KEY.includes('把你')) {
    throw new Error('未配置智谱 API Key');
  }

  const req = http.createHttp();
  try {
    const body = {
      model: MODEL,
      messages: [
        { role: 'system', content: '你是一个严谨但表达清晰的中文写作助手。' },
        { role: 'user', content: buildPrompt(title, content, mode) }
      ],
      temperature: 0.7,
      stream: false
    };

    const resp = await req.request(ENDPOINT, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${API_KEY}`
      },
      extraData: JSON.stringify(body),
      connectTimeout: 15000,
      readTimeout: 20000
    });

    const status = resp.responseCode ?? 0;
    const raw = String(resp.result ?? '');

    if (status < 200 || status >= 300) {
      throw new Error(`AI接口失败(${status})：${raw.slice(0, 200)}`);
    }

    // 解析 choices[0].message.content
    const json = JSON.parse(raw);
    const text = json?.choices?.[0]?.message?.content;
    if (!text) {
      throw new Error('AI返回结构异常：未找到 content');
    }
    return String(text).trim();
  } finally {
    req.destroy();
  }
}
