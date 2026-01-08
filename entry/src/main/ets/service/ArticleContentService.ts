/*
 * ArticleContentService.ts - 文章内容获取服务
 * 
 * 功能说明：
 * - 从文章链接获取完整的文章内容
 * - 清理HTML标签，提取纯文本内容
 * - 处理内容长度限制和截断
 * - 提供友好的错误处理和超时控制
 * 
 * 技术实现：
 * - 使用HTTP客户端请求文章原始页面
 * - 正则表达式清理HTML标签和脚本
 * - 智能换行处理保持文本可读性
 * - 内容长度控制和截断提示
 * 
 * 使用场景：
 * - 文章详情页显示完整内容
 * - 离线阅读内容获取
 * - 内容分析和处理
 */

import http from '@ohos.net.http';

/**
 * HTTP请求超时时间（毫秒）
 */
const HTTP_TIMEOUT = 15000;

/**
 * 最大内容长度限制（字符数）
 * 防止内容过长导致性能问题
 */
const MAX_CONTENT_LENGTH = 8000;

/**
 * 清理HTML标签，提取纯文本内容
 * 
 * @param raw 原始HTML内容
 * @returns 清理后的纯文本内容
 */
function stripHtml(raw: string): string {
  // 第一步：移除脚本、样式和noscript标签
  const withoutScripts = raw
    .replace(/<script[\s\S]*?<\/script>/gi, '')  // 移除JavaScript代码
    .replace(/<style[\s\S]*?<\/style>/gi, '')    // 移除CSS样式
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, ''); // 移除noscript内容

  // 第二步：将块级元素转换为换行符
  const withNewlines = withoutScripts.replace(/<\/(p|div|li|h[1-6]|br|tr)>/gi, '\n');
  
  // 第三步：清理所有HTML标签和格式化文本
  return withNewlines
    .replace(/<[^>]+>/g, ' ')         // 移除剩余HTML标签，替换为空格
    .replace(/\r/g, '')               // 移除回车符
    .replace(/[ \t]+/g, ' ')          // 合并连续空格和制表符
    .replace(/\n{2,}/g, '\n')         // 合并连续换行符
    .trim();                          // 去除首尾空白
}

/**
 * 控制内容长度，防止内容过长
 * 
 * @param content 原始内容文本
 * @returns 截断后的内容文本（带提示信息）
 */
function clampContent(content: string): string {
  // 检查内容长度是否超过限制
  if (content.length <= MAX_CONTENT_LENGTH) {
    return content;
  }
  
  // 截断内容并添加提示信息
  return `${content.slice(0, MAX_CONTENT_LENGTH)}\n（正文过长，仅截取前${MAX_CONTENT_LENGTH}字）`;
}

/**
 * 从文章链接获取文章内容
 * 
 * @param link 文章链接地址
 * @returns 清理后的文章纯文本内容
 * @throws 当HTTP请求失败或状态码异常时抛出错误
 */
export async function fetchArticleContent(link: string): Promise<string> {
  // 创建HTTP客户端实例
  const client = http.createHttp();
  
  try {
    // 发送HTTP GET请求获取文章内容
    const resp = await client.request(link, {
      method: http.RequestMethod.GET,
      connectTimeout: HTTP_TIMEOUT,      // 连接超时时间
      readTimeout: HTTP_TIMEOUT,         // 读取超时时间
      expectDataType: http.HttpDataType.STRING,  // 期望返回字符串类型
      header: {
        'User-Agent': 'Mozilla/5.0 (HarmonyOS; AI Reader)'  // 用户代理标识
      }
    });

    // 获取HTTP响应状态码
    const status = resp.responseCode ?? 0;
    
    // 验证HTTP状态码（2xx表示成功）
    if (status < 200 || status >= 300) {
      throw new Error(`原文请求失败(${status})`);
    }

    // 获取响应内容并转换为字符串
    const raw = String(resp.result ?? '');
    
    // 清理HTML标签，提取纯文本
    const text = stripHtml(raw);
    
    // 控制内容长度并返回
    return clampContent(text);
  } finally {
    // 确保HTTP客户端被正确销毁，防止资源泄漏
    client.destroy();
  }
}