/*
 * ZhipuAI.ts - 智谱AI大模型服务
 * 
 * 功能说明：
 * - 提供与智谱AI大模型API的交互功能
 * - 支持多种AI处理模式：摘要总结、锐评分析、问答对话
 * - 封装HTTP请求和响应处理
 * - 提供智能提示词构建和结果解析
 * 
 * AI处理模式：
 * - summary: 文章摘要总结（5要点+收获+建议）
 * - review: 文章锐评分析（观点概括+漏洞分析+改进建议）
 * - qa: 智能问答（基于文章内容的问答）
 * 
 * 技术实现：
 * - 使用智谱AI的GLM-4-Flash模型
 * - 构建系统提示词和用户提示词
 * - 处理API认证和错误响应
 * - 结果格式验证和清理
 */

import http from '@ohos.net.http';

/**
 * AI处理模式类型定义
 */
export type AiMode = 'summary' | 'review' | 'qa';

/**
 * 智谱AI API密钥
 * 注意：实际项目中应使用环境变量或安全存储
 */
const API_KEY = '2d890ff673044875af844d4cdda8f356.FwfpRGVx5LtPaDCr';

/**
 * 智谱AI API端点地址
 */
const ENDPOINT = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';

/**
 * 使用的AI模型
 * glm-4-flash是免费的轻量级模型
 */
const MODEL = 'glm-4-flash';

/**
 * 构建AI提示词
 * 根据不同的处理模式构建相应的提示词模板
 * 
 * @param title 文章标题
 * @param content 文章内容
 * @param mode AI处理模式
 * @param question 问答模式的问题（可选）
 * @returns 构建完成的提示词字符串
 */
function buildPrompt(title: string, content: string, mode: AiMode, question?: string): string {
  // 基础提示词：包含文章标题和内容
  const base = `文章标题：${title}\n\n文章内容：\n${content}\n\n`;

  if (mode === 'summary') {
    // 摘要总结模式提示词
    return base +
      `请用中文输出：\n` +
      `1) 用 5 条要点总结文章（每条不超过 25 字）\n` +
      `2) 给出 1 句"适合谁看/读完收获"\n` +
      `3) 给出 2 条可执行建议（如果文章偏观点，就给行动建议）\n` +
      `要求：结构清晰，避免空话。`;
  }

  if (mode === 'qa') {
    // 问答模式提示词
    const questionText = question?.trim() ?? '';
    return base +
      `请仅基于文章内容回答用户问题，若文中没有相关信息请说明"本文未提供相关信息"。\n` +
      `用户问题：${questionText}`;
  }

  // 锐评分析模式提示词
  return base +
    `请用中文输出"锐评"，风格像公众号的犀利评论，但不要人身攻击：\n` +
    `1) 先用 1 句话概括作者核心观点\n` +
    `2) 指出 3 个逻辑漏洞/证据不足点（要具体）\n` +
    `3) 给出 2 个改进方向（如何写更有说服力）\n` +
    `要求：观点明确、短句、有力度。`;
}

/**
 * 调用智谱AI API
 * 
 * @param title 文章标题
 * @param content 文章内容
 * @param mode AI处理模式
 * @param question 问答模式的问题（可选）
 * @returns AI处理后的结果文本
 * @throws 当API密钥未配置、HTTP请求失败或响应格式异常时抛出错误
 */
export async function callZhipu(title: string, content: string, mode: AiMode, question?: string): Promise<string> {
  // API密钥验证
  if (!API_KEY || API_KEY.includes('把你')) {
    throw new Error('未配置智谱 API Key');
  }

  // 创建HTTP客户端
  const req = http.createHttp();
  
  try {
    // 构建请求体
    const body = {
      model: MODEL,                    // 使用的模型
      messages: [
        { 
          role: 'system',              // 系统角色消息
          content: '你是一个严谨但表达清晰的中文写作助手。'  // 系统提示词
        },
        { 
          role: 'user',                // 用户角色消息
          content: buildPrompt(title, content, mode, question)  // 用户提示词
        }
      ],
      temperature: 0.7,               // 温度参数（控制随机性）
      stream: false                   // 非流式响应
    };

    // 发送HTTP POST请求
    const resp = await req.request(ENDPOINT, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',           // JSON内容类型
        'Authorization': `Bearer ${API_KEY}`          // Bearer Token认证
      },
      extraData: JSON.stringify(body),               // 请求体数据
      connectTimeout: 15000,                         // 连接超时15秒
      readTimeout: 20000                             // 读取超时20秒
    });

    // 获取HTTP状态码和响应内容
    const status = resp.responseCode ?? 0;
    const raw = String(resp.result ?? '');

    // 验证HTTP状态码
    if (status < 200 || status >= 300) {
      throw new Error(`AI接口失败(${status})：${raw.slice(0, 200)}`);  //如果不是 2xx 状态码就抛错，并截取 200 个字符用于错误提示。
    }

    // 解析JSON响应
    const json = JSON.parse(raw);
    
    // 提取AI生成的内容
    const text = json?.choices?.[0]?.message?.content;
    
    // 验证响应结构
    if (!text) {
      throw new Error('AI返回结构异常：未找到 content');
    }
    
    // 返回清理后的文本内容
    return String(text).trim();
  } finally {
    // 确保HTTP客户端被正确销毁
    req.destroy();
  }
}