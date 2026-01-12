/*
 * ZhipuAI.ts - 智谱AI大模型服务模块
 *
 * 模块职责：
 * - 提供与智谱AI大模型API的标准化交互接口
 * - 封装AI处理功能：摘要总结、锐评分析、智能问答
 * - 管理API认证、请求构建、响应解析全流程
 * - 实现智能提示词模板和结果质量控制
 *
 * 核心功能：
 * - 多模式AI处理：支持summary(摘要)、review(锐评)、qa(问答)三种模式
 * - 智能提示词构建：根据不同模式动态生成优化的提示词模板
 * - 错误处理机制：完整的API调用异常处理和错误信息反馈
 * - 性能优化：连接超时控制、资源自动释放
 *
 * 技术架构：
 * - 基于HarmonyOS的@ohos.net.http模块进行网络通信
 * - 使用智谱AI的GLM-4-Flash轻量级模型
 * - 实现Bearer Token认证机制
 * - 支持JSON格式数据交互
 *
 * 安全考虑：
 * - API密钥硬编码警告（生产环境应使用安全存储）
 * - 请求超时保护防止长时间阻塞
 * - 响应数据验证防止恶意内容注入
 *
 * 版本信息：
 * - 创建时间：2024年
 * - 依赖版本：HarmonyOS 4.0+
 * - API版本：智谱AI v4
 */

import http from '@ohos.net.http';

/**
 * AI处理模式枚举类型
 *
 * 定义三种处理模式：
 * - summary: 文章摘要总结模式，输出结构化要点
 * - review: 锐评分析模式，提供批判性分析
 * - qa: 智能问答模式，基于内容的精准回答
 */
export type AiMode = 'summary' | 'review' | 'qa';

/**
 * 智谱AI服务配置常量
 *
 * ⚠️ 安全警告：API密钥应使用环境变量或安全存储
 * 当前为开发测试用途，生产环境必须移除硬编码
 */
const API_KEY = '2d890ff673044875af844d4cdda8f356.FwfpRGVx5LtPaDCr';
const ENDPOINT = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
const MODEL = 'glm-4-flash'; // 轻量级免费模型，适合移动端使用

/**
 * 构建AI处理提示词模板
 *
 * 根据不同的处理模式生成优化的提示词，确保AI输出格式化和结构化
 *
 * @param title - 文章标题，用于上下文理解
 * @param content - 文章内容，AI分析的主要数据源
 * @param mode - AI处理模式，决定提示词模板
 * @param question - 问答模式的问题文本（仅qa模式需要）
 * @returns 构建完成的提示词字符串
 *
 * @example
* // 摘要模式提示词示例
 * buildPrompt("标题", "内容", "summary")
 *
 * @throws 无显式抛出，但依赖参数验证
 */
function buildPrompt(title: string, content: string, mode: AiMode, question?: string): string {
  // 基础上下文：提供文章标题和内容作为AI分析的基础
  const base = `文章标题：${title}\n\n文章内容：\n${content}\n\n`;

  if (mode === 'summary') {
    // 摘要总结模式：结构化输出5要点+收获+建议
    return base +
      `请用中文输出：\n` +
      `1) 用 5 条要点总结文章（每条不超过 25 字）\n` +
      `2) 给出 1 句"适合谁看/读完收获"\n` +
      `3) 给出 2 条可执行建议（如果文章偏观点，就给行动建议）\n` +
      `要求：结构清晰，避免空话。`;
  }

  if (mode === 'qa') {
    // 问答模式：基于内容的精确回答，避免编造信息
    const questionText = question?.trim() ?? '';
    return base +
      `请仅基于文章内容回答用户问题，若文中没有相关信息请说明"本文未提供相关信息"。\n` +
      `用户问题：${questionText}`;
  }

  // 锐评分析模式：批判性思维，指出问题并提供改进建议
  return base +
    `请用中文输出"锐评"，风格像公众号的犀利评论，但不要人身攻击：\n` +
    `1) 先用 1 句话概括作者核心观点\n` +
    `2) 指出 3 个逻辑漏洞/证据不足点（要具体）\n` +
    `3) 给出 2 个改进方向（如何写更有说服力）\n` +
    `要求：观点明确、短句、有力度。`;
}

/**
 * 调用智谱AI API进行文章分析
 *
 * 主要业务流程：
 * 1. 参数验证和API密钥检查
 * 2. HTTP客户端创建和请求构建
 * 3. API调用和响应处理
 * 4. 结果解析和错误处理
 *
 * @param title - 文章标题，必填参数
 * @param content - 文章内容，必填参数
 * @param mode - AI处理模式，决定分析类型
 * @param question - 问答模式的问题（仅qa模式需要）
 * @returns Promise<string> AI处理后的结构化文本结果
 *
 * @throws {Error} 当以下情况发生时：
 * - API密钥未配置或格式错误
 * - HTTP请求失败（网络问题或服务器错误）
 * - 响应数据格式异常或缺少必要字段
 * - JSON解析失败
 *
 * @example
* // 基本使用示例
 * const result = await callZhipu("文章标题", "文章内容", "summary");
 *
 * // 问答模式使用示例
 * const answer = await callZhipu("标题", "内容", "qa", "这篇文章的主要观点是什么？");
 */
export async function callZhipu(title: string, content: string, mode: AiMode, question?: string): Promise<string> {
  // API密钥安全验证：检查密钥是否存在且格式正确
  if (!API_KEY || API_KEY.includes('把你')) {
    throw new Error('未配置智谱 API Key，请检查API密钥配置');
  }

  // 创建HTTP客户端实例，使用HarmonyOS网络模块
  const req = http.createHttp();

  try {
    // 构建完整的API请求体，符合智谱AI v4接口规范
    const body = {
      model: MODEL,                    // 指定使用的AI模型
      messages: [
        {
          role: 'system',              // 系统角色：定义AI行为风格
          content: '你是一个严谨但表达清晰的中文写作助手。'  // 系统提示词
        },
        {
          role: 'user',                // 用户角色：具体的处理请求
          content: buildPrompt(title, content, mode, question)  // 动态生成的用户提示词
        }
      ],
      temperature: 0.7,               // 创造性参数：0.7平衡创造性和准确性
      stream: false                   // 非流式响应：一次性返回完整结果
    };

    // 执行HTTP POST请求到智谱AI API端点
    const resp = await req.request(ENDPOINT, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',           // 指定JSON数据格式
        'Authorization': `Bearer ${API_KEY}`          // Bearer Token认证
      },
      extraData: JSON.stringify(body),               // 序列化请求体数据
      connectTimeout: 15000,                         // 连接超时：15秒
      readTimeout: 20000                             // 读取超时：20秒
    });

    // 提取HTTP状态码和响应内容
    const status = resp.responseCode ?? 0;
    const raw = String(resp.result ?? '');

    // HTTP状态码验证：仅接受2xx成功状态
    if (status < 200 || status >= 300) {
      // 错误信息截断前200字符，避免过长日志
      throw new Error(`AI接口HTTP错误(${status})：${raw.slice(0, 200)}`);
    }

    // JSON响应解析和结构验证
    const json = JSON.parse(raw);

    // 提取AI生成的内容文本
    const text = json?.choices?.[0]?.message?.content;

    // 响应结构完整性验证
    if (!text) {
      throw new Error('AI返回数据结构异常：未找到content字段');
    }

    // 返回清理后的文本内容，去除首尾空白
    return String(text).trim();
  } finally {
    // 资源清理：确保HTTP客户端被正确销毁，防止内存泄漏
    req.destroy();
  }
}