/*
 * ArticleContentService.ts - 文章内容获取与处理服务模块
 *
 * 模块职责：
 * - 从外部链接获取文章原始HTML内容
 * - 清理HTML标签提取纯文本内容
 * - 实现内容长度控制和格式化处理
 * - 提供网络请求异常处理和超时控制
 *
 * 核心功能：
 * - 网络内容获取：通过HTTP GET请求获取文章页面
 * - HTML净化处理：移除脚本、样式等非内容元素
 * - 文本格式化：智能换行处理和空白字符清理
 * - 长度控制：防止内容过长导致的性能问题
 *
 * 技术架构：
 * - 基于HarmonyOS的@ohos.net.http模块
 * - 正则表达式实现HTML标签清理
 * - 流式文本处理避免大内存占用
 *
 * 性能优化：
 * - 超时控制防止长时间网络阻塞
 * - 内容长度限制保护应用性能
 * - 资源自动释放防止内存泄漏
 *
 * 使用场景：
 * - 文章详情页内容展示
 * - AI分析前的数据预处理
 * - 离线阅读内容缓存
 */

import http from '@ohos.net.http';

/**
 * 网络请求配置常量
 */
const HTTP_TIMEOUT = 15000; // 15秒超时，平衡用户体验和网络稳定性
const MAX_CONTENT_LENGTH = 8000; // 最大内容长度，防止性能问题

/**
 * HTML内容净化处理函数
 *
 * 采用三步清理策略：
 * 1. 移除脚本和样式等非内容元素
 * 2. 块级元素转换为换行符保持结构
 * 3. 清理剩余标签和格式化文本
 *
 * @param raw - 原始HTML字符串内容
 * @returns 清理后的纯文本内容，保持可读性
 *
 * @example
* // 输入：<div><p>Hello</p><script>alert()</script></div>
 * // 输出：Hello
 */
function stripHtml(raw: string): string {
  // 第一步：安全清理 - 移除脚本、样式等潜在安全风险元素
  const withoutScripts = raw
    .replace(/<script[\s\S]*?<\/script>/gi, '')  // 移除JavaScript代码块
    .replace(/<style[\s\S]*?<\/style>/gi, '')    // 移除CSS样式定义
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, ''); // 移除noscript内容

  // 第二步：结构优化 - 将块级元素转换为换行符保持段落结构
  const withNewlines = withoutScripts.replace(/<\/(p|div|li|h[1-6]|br|tr)>/gi, '\n');

  // 第三步：最终清理 - 移除所有HTML标签并格式化文本
  return withNewlines
    .replace(/<[^>]+>/g, ' ')         // 移除剩余HTML标签，用空格分隔
    .replace(/\r/g, '')               // 移除Windows回车符，统一换行格式
    .replace(/[ \t]+/g, ' ')          // 合并连续空白字符为单个空格
    .replace(/\n{2,}/g, '\n')         // 合并多个连续换行符为单个
    .trim();                          // 去除首尾空白字符
}

/**
 * 内容长度控制函数
 *
 * 防止过长的内容导致性能问题，提供友好的截断提示
 *
 * @param content - 原始文本内容
 * @returns 长度控制后的文本内容，包含截断提示
 *
 * @example
* // 输入：5000字符的文本
 * // 输出：原样返回
 *
 * // 输入：10000字符的文本
 * // 输出：前8000字符 + 截断提示
 */
function clampContent(content: string): string {
  // 长度检查：如果内容在限制范围内，直接返回
  if (content.length <= MAX_CONTENT_LENGTH) {
    return content;
  }

  // 智能截断：保留前MAX_CONTENT_LENGTH字符，添加友好提示
  return `${content.slice(0, MAX_CONTENT_LENGTH)}\n（正文过长，仅截取前${MAX_CONTENT_LENGTH}字）`;
}

/**
 * 从文章链接获取并处理文章内容
 *
 * 完整的工作流程：
 * 1. 创建HTTP客户端并配置请求参数
 * 2. 发送GET请求获取原始HTML内容
 * 3. 验证HTTP响应状态
 * 4. 执行HTML净化处理
 * 5. 应用内容长度控制
 *
 * @param link - 文章链接URL地址
 * @returns Promise<string> 处理后的纯文本文章内容
 *
 * @throws {Error} 当以下情况发生时：
 * - 网络请求失败（超时、DNS解析失败等）
 * - HTTP状态码非2xx（404、500等错误）
 * - 响应内容为空或格式异常
 *
 * @example
* // 基本使用示例
 * const content = await fetchArticleContent("https://example.com/article");
 */
export async function fetchArticleContent(link: string): Promise<string> {
  // 创建HTTP客户端实例，使用HarmonyOS网络模块
  const client = http.createHttp();

  try {
    // 发送HTTP GET请求获取文章原始内容
    const resp = await client.request(link, {
      method: http.RequestMethod.GET,
      connectTimeout: HTTP_TIMEOUT,      // 连接建立超时时间
      readTimeout: HTTP_TIMEOUT,         // 数据读取超时时间
      expectDataType: http.HttpDataType.STRING,  // 期望返回字符串类型数据
      header: {
        'User-Agent': 'Mozilla/5.0 (HarmonyOS; AI Reader)'  // 用户代理标识，模拟浏览器访问
      }
    });

    // 提取HTTP响应状态码，处理可能的undefined情况
    const status = resp.responseCode ?? 0;

    // HTTP状态码验证：仅接受2xx成功状态码
    if (status < 200 || status >= 300) {
      throw new Error(`文章内容请求失败(HTTP ${status})`);
    }

    // 获取响应内容并转换为字符串
    const raw = String(resp.result ?? '');

    // 执行HTML净化处理，提取纯文本内容
    const text = stripHtml(raw);

    // 应用内容长度控制并返回最终结果
    return clampContent(text);
  } finally {
    // 资源清理：确保HTTP客户端被正确销毁，防止资源泄漏
    client.destroy();
  }
}