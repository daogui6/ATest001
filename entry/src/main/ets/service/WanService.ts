/*
 * WanService.ts - WanAndroid API服务层
 * 
 * 功能说明：
 * - 提供与WanAndroid网站API的交互功能
 * - 封装HTTP请求和响应处理
 * - 数据格式转换和验证
 * - 用户认证和会话管理
 * 
 * API接口：
 * - 用户注册、登录、退出
 * - 文章列表获取（置顶、最新、分类）
 * - 文章搜索功能
 * - 分类信息获取
 * 
 * 数据模型：
 * - Article: 文章数据模型
 * - Category: 分类数据模型
 * - WanUser: 用户数据模型
 * 
 * 错误处理：
 * - HTTP状态码验证
 * - API错误码处理
 * - 数据格式验证
 * - 网络异常处理
 */

import http from '@ohos.net.http';

import type { Article } from '../model/Article';
import type { Category } from '../model/Category';

/**
 * API响应结果接口
 * WanAndroid API的标准响应格式
 */
interface ApiResult<T> {
  data?: T;           // 响应数据
  errorCode: number;  // 错误代码（0表示成功）
  errorMsg: string;   // 错误消息
}

/**
 * 文章数据负载接口
 * 从API返回的原始文章数据格式
 */
interface ArticlePayload {
  id?: number;              // 文章ID
  title?: string;           // 文章标题
  desc?: string;            // 文章描述
  author?: string;          // 文章作者
  shareUser?: string;       // 分享用户
  superChapterId?: number;  // 上级分类ID
  chapterId?: number;       // 分类ID
  link?: string;            // 文章链接
}

/**
 * 文章列表负载接口
 * 包含文章数据数组的响应格式
 */
interface ArticleListPayload {
  datas?: ArticlePayload[];  // 文章数据数组
}

/**
 * 分类数据负载接口
 * 从API返回的原始分类数据格式
 */
interface CategoryPayload {
  id?: number;    // 分类ID
  name?: string;  // 分类名称
}

/**
 * 用户数据负载接口
 * 从API返回的原始用户数据格式
 */
interface UserPayload {
  id?: number;          // 用户ID
  username?: string;    // 用户名
  nickname?: string;    // 昵称
  publicName?: string;  // 公开名称
  token?: string;       // 用户令牌
}

/**
 * 标准化用户数据接口
 * 处理后的用户数据格式
 */
export interface WanUser {
  id: number;          // 用户ID
  username: string;    // 用户名
  nickname: string;    // 昵称
  publicName: string;  // 公开名称
  token?: string;      // 用户令牌（可选）
  bio?: string;        // 用户简介（可选）
}

/**
 * API基础URL
 * WanAndroid网站的基础地址
 */
const BASE = 'https://www.wanandroid.com';

/**
 * HTTP请求超时时间（毫秒）
 */
const HTTP_TIMEOUT = 12000;

/**
 * 去除HTML标签
 * 清理API返回的文本内容中的HTML标签
 * 
 * @param raw 原始文本内容
 * @returns 清理后的纯文本内容
 */
function stripHtml(raw: string | undefined): string {
  if (!raw) {
    return '';
  }
  return raw.replace(/<[^>]*>/g, '').trim();
}

/**
 * 解析API响应结果
 * 验证HTTP状态码和API错误码，提取数据
 * 
 * @param status HTTP状态码
 * @param raw 原始响应文本
 * @returns 解析后的数据
 * @throws 当状态码错误、JSON解析失败或API返回错误时抛出异常
 */
function parseApiResult<T>(status: number, raw: string): T {
  // 验证HTTP状态码
  if (status < 200 || status >= 300) {
    throw new Error(`接口请求失败(${status})`);
  }

  let parsed: ApiResult<T>;
  try {
    parsed = JSON.parse(raw) as ApiResult<T>;
  } catch (e) {
    throw new Error('接口返回不是合法的 JSON');
  }

  // 验证API错误码
  if (parsed.errorCode !== 0) {
    throw new Error(parsed.errorMsg || '接口返回错误码');
  }

  // 验证数据是否存在
  if (parsed.data === undefined) {
    throw new Error('接口返回为空');
  }

  return parsed.data;
}

/**
 * 提取响应中的Cookie
 * 从HTTP响应中提取Cookie信息用于会话保持
 * 
 * @param resp HTTP响应对象
 * @returns 拼接后的Cookie字符串
 */
function extractCookies(resp: http.HttpResponse): string {
  // 尝试从cookies属性获取
  const rawCookies = (resp as http.HttpResponse & { cookies?: string[] }).cookies;
  if (rawCookies && Array.isArray(rawCookies)) {
    return rawCookies.join('; ');
  }

  // 尝试从响应头获取
  const header = typeof resp.header === 'object' && resp.header !== null
    ? (resp.header as Record<string, unknown>)
    : undefined;
  const setCookie = header?.['Set-Cookie'] ?? header?.['set-cookie'];
  
  if (Array.isArray(setCookie)) {
    return setCookie.join('; ');
  }
  if (typeof setCookie === 'string') {
    return setCookie;
  }

  return '';
}

/**
 * 发送GET请求
 * 封装GET请求的通用逻辑
 * 
 * @param path API路径
 * @param cookie Cookie字符串（可选）
 * @returns 解析后的响应数据
 */
async function getJson<T>(path: string, cookie?: string): Promise<T> {
  const client = http.createHttp();
  try {
    const resp = await client.request(`${BASE}${path}`, {
      method: http.RequestMethod.GET,
      connectTimeout: HTTP_TIMEOUT,
      readTimeout: HTTP_TIMEOUT,
      expectDataType: http.HttpDataType.STRING,
      header: cookie ? { Cookie: cookie } : undefined
    });

    const status = resp.responseCode ?? 0;
    const raw = String(resp.result ?? '');
    return parseApiResult<T>(status, raw);
  } finally {
    client.destroy();  // 确保HTTP客户端被销毁
  }
}

/**
 * 发送POST请求
 * 封装POST请求的通用逻辑
 * 
 * @param path API路径
 * @param body 请求体数据
 * @param cookie Cookie字符串（可选）
 * @returns 解析后的响应数据
 */
async function postJson<T>(path: string, body: string, cookie?: string): Promise<T> {
  const client = http.createHttp();
  try {
    const resp = await client.request(`${BASE}${path}`, {
      method: http.RequestMethod.POST,
      connectTimeout: HTTP_TIMEOUT,
      readTimeout: HTTP_TIMEOUT,
      expectDataType: http.HttpDataType.STRING,
      header: {
        'Content-Type': 'application/x-www-form-urlencoded',
        ...(cookie ? { Cookie: cookie } : {})
      },
      extraData: body
    });

    const status = resp.responseCode ?? 0;
    const raw = String(resp.result ?? '');
    return parseApiResult<T>(status, raw);
  } finally {
    client.destroy();
  }
}

/**
 * 发送POST请求并返回Cookie
 * 用于需要会话保持的请求（如登录、注册）
 * 
 * @param path API路径
 * @param body 请求体数据
 * @param cookie Cookie字符串（可选）
 * @returns 包含数据和Cookie的对象
 */
async function postJsonWithCookie<T>(path: string, body: string, cookie?: string): Promise<{ data: T; cookie: string }> {
  const client = http.createHttp();
  try {
    const resp = await client.request(`${BASE}${path}`, {
      method: http.RequestMethod.POST,
      connectTimeout: HTTP_TIMEOUT,
      readTimeout: HTTP_TIMEOUT,
      expectDataType: http.HttpDataType.STRING,
      header: {
        'Content-Type': 'application/x-www-form-urlencoded',
        ...(cookie ? { Cookie: cookie } : {})
      },
      extraData: body
    });

    const status = resp.responseCode ?? 0;
    const raw = String(resp.result ?? '');
    const data = parseApiResult<T>(status, raw);
    const cookieStr = extractCookies(resp);
    return { data, cookie: cookieStr };
  } finally {
    client.destroy();
  }
}

/**
 * 标准化用户数据
 * 将API返回的用户数据转换为标准格式
 * 
 * @param payload 原始用户数据
 * @returns 标准化后的用户数据
 */
function normalizeUser(payload: UserPayload): WanUser {
  const username = payload.username ?? '';
  const nickname = payload.nickname ?? payload.publicName ?? username;
  const publicName = payload.publicName ?? nickname ?? username;
  
  return {
    id: payload.id ?? 0,
    username,
    nickname: nickname || '未知用户',
    publicName: publicName || '未知用户',
    token: payload.token
  };
}

/**
 * 映射文章数据
 * 将API返回的文章数据转换为标准格式
 * 
 * @param item 原始文章数据
 * @returns 标准化后的文章数据
 */
function mapArticle(item: ArticlePayload): Article {
  const id = item.id ?? 0;
  const title = stripHtml(item.title) || '未命名';
  const desc = stripHtml(item.desc) || title;
  const link = item.link && item.link.trim().length > 0 ? item.link.trim() : '';
  const author = stripHtml(item.author)
    || stripHtml(item.shareUser)
    || '佚名';
  const cid = item.chapterId ?? item.superChapterId ?? 0;

  // 生成文章内容
  const content = `${title}\n\n来源：wanandroid（ID=${id}）\n作者：${author}\n分类：${cid}\n链接：${link || '暂无链接'}\n\n摘要：${desc}`;
  
  return {
    id,
    title,
    desc,
    author,
    cid,
    link,
    content
  };
}

/**
 * 用户注册
 * 
 * @param username 用户名
 * @param password 密码
 * @param rePassword 确认密码
 * @returns 包含用户信息和Cookie的对象
 */
export async function registerUser(username: string, password: string, rePassword: string): Promise<{ user: WanUser; cookie: string }> {
  const encodedBody = `username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}&repassword=${encodeURIComponent(rePassword)}`;
  const { data, cookie } = await postJsonWithCookie<UserPayload>('/user/register', encodedBody);
  return { user: normalizeUser(data), cookie };
}

/**
 * 用户登录
 * 
 * @param username 用户名
 * @param password 密码
 * @returns 包含用户信息和Cookie的对象
 */
export async function loginUser(username: string, password: string): Promise<{ user: WanUser; cookie: string }> {
  const encodedBody = `username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`;
  const { data, cookie } = await postJsonWithCookie<UserPayload>('/user/login', encodedBody);
  return { user: normalizeUser(data), cookie };
}

/**
 * 用户退出登录
 * 
 * @param cookie 用户Cookie（可选）
 */
export async function logoutUser(cookie?: string): Promise<void> {
  await getJson('/user/logout/json', cookie);
}

/**
 * 获取置顶文章列表
 * 
 * @returns 置顶文章数组
 */
export async function fetchTopArticles(): Promise<Article[]> {
  const data = await getJson<ArticlePayload[]>('/article/top/json');
  if (!Array.isArray(data)) {
    throw new Error('文章数据格式错误');
  }
  return data.map(mapArticle);
}

/**
 * 获取最新文章列表
 * 
 * @param page 页码（默认0）
 * @returns 最新文章数组
 */
export async function fetchLatestArticles(page: number = 0): Promise<Article[]> {
  const payload = await getJson<ArticleListPayload>(`/article/list/${page}/json`);
  const datas = payload.datas ?? [];
  return datas.map(mapArticle);
}

/**
 * 根据分类ID获取文章列表
 * 
 * @param cid 分类ID
 * @param page 页码（默认0）
 * @returns 分类文章数组
 */
export async function fetchArticlesByCid(cid: number, page: number = 0): Promise<Article[]> {
  const encoded = encodeURIComponent(String(cid));
  const payload = await getJson<ArticleListPayload>(`/article/list/${page}/json?cid=${encoded}`);
  const datas = payload.datas ?? [];
  return datas.map(mapArticle);
}

/**
 * 根据文章ID获取单篇文章
 * 
 * @param id 文章ID
 * @returns 文章对象或null（未找到时）
 */
export async function fetchArticleById(id: number): Promise<Article | null> {
  if (!id || Number.isNaN(id)) {
    return null;
  }

  // 同时获取置顶和最新文章进行搜索
  const requests: Promise<Article[]>[] = [fetchTopArticles(), fetchLatestArticles()];
  const [top, latest] = await Promise.all(requests);
  const merged = [...top, ...latest];
  
  return merged.find(item => item.id === id) ?? null;
}

/**
 * 根据文章ID集合获取多篇文章
 * 
 * @param ids 文章ID集合
 * @returns 文章数组
 */
export async function fetchArticlesByIds(ids: Set<number>): Promise<Article[]> {
  if (!ids || ids.size === 0) {
    return [];
  }

  const requests: Promise<Article[]>[] = [fetchTopArticles(), fetchLatestArticles()];
  const [top, latest] = await Promise.all(requests);
  const all = [...top, ...latest];
  
  // 使用Map去重并保持顺序
  const map = new Map<number, Article>();
  all.forEach(item => {
    if (ids.has(item.id)) {
      map.set(item.id, item);
    }
  });

  return Array.from(map.values());
}

/**
 * 搜索文章
 * 
 * @param keyword 搜索关键词
 * @returns 搜索结果文章数组
 */
export async function searchArticles(keyword: string): Promise<Article[]> {
  const kw = keyword.trim();
  if (kw.length === 0) {
    return [];
  }

  const payload = await postJson<ArticleListPayload>('/article/query/0/json', `k=${encodeURIComponent(kw)}`);
  const datas = payload.datas ?? [];
  return datas.map(mapArticle);
}

/**
 * 获取分类列表
 * 
 * @returns 分类数组
 */
export async function fetchCategories(): Promise<Category[]> {
  const data = await getJson<CategoryPayload[]>('/tree/json');
  if (!Array.isArray(data)) {
    throw new Error('分类数据格式错误');
  }
  
  return data.map(item => ({
    cid: item.id ?? 0,
    name: item.name ?? '未命名'
  }));
}