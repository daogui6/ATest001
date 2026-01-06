import http from '@ohos.net.http';

import type { Article } from '../model/Article';
import type { Category } from '../model/Category';

interface ApiResult<T> {
  data?: T;
  errorCode: number;
  errorMsg: string;
}

interface ArticlePayload {
  id?: number;
  title?: string;
  desc?: string;
  author?: string;
  shareUser?: string;
  superChapterId?: number;
  chapterId?: number;
  link?: string;
}

interface ArticleListPayload {
  datas?: ArticlePayload[];
}

interface CategoryPayload {
  id?: number;
  name?: string;
}

interface UserPayload {
  id?: number;
  username?: string;
  nickname?: string;
  publicName?: string;
  token?: string;
}

export interface WanUser {
  id: number;
  username: string;
  nickname: string;
  publicName: string;
  token?: string;
  bio?: string;
}

const BASE = 'https://www.wanandroid.com';
const HTTP_TIMEOUT = 12000;

function stripHtml(raw: string | undefined): string {
  if (!raw) {
    return '';
  }
  return raw.replace(/<[^>]*>/g, '').trim();
}

function parseApiResult<T>(status: number, raw: string): T {
  if (status < 200 || status >= 300) {
    throw new Error(`接口请求失败(${status})`);
  }

  let parsed: ApiResult<T>;
  try {
    parsed = JSON.parse(raw) as ApiResult<T>;
  } catch (e) {
    throw new Error('接口返回不是合法的 JSON');
  }

  if (parsed.errorCode !== 0) {
    throw new Error(parsed.errorMsg || '接口返回错误码');
  }

  if (parsed.data === undefined) {
    throw new Error('接口返回为空');
  }

  return parsed.data;
}

function extractCookies(resp: http.HttpResponse): string {
  const rawCookies = (resp as http.HttpResponse & { cookies?: string[] }).cookies;
  if (rawCookies && Array.isArray(rawCookies)) {
    return rawCookies.join('; ');
  }

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
    client.destroy();
  }
}

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

function mapArticle(item: ArticlePayload): Article {
  const id = item.id ?? 0;
  const title = stripHtml(item.title) || '未命名';
  const desc = stripHtml(item.desc) || title;
  const link = item.link && item.link.trim().length > 0 ? item.link.trim() : '';
  const author = stripHtml(item.author)
    || stripHtml(item.shareUser)
    || '佚名';
  const cid = item.chapterId ?? item.superChapterId ?? 0;

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

export async function registerUser(username: string, password: string, rePassword: string): Promise<{ user: WanUser; cookie: string }> {
  const encodedBody = `username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}&repassword=${encodeURIComponent(rePassword)}`;
  const { data, cookie } = await postJsonWithCookie<UserPayload>('/user/register', encodedBody);
  return { user: normalizeUser(data), cookie };
}

export async function loginUser(username: string, password: string): Promise<{ user: WanUser; cookie: string }> {
  const encodedBody = `username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`;
  const { data, cookie } = await postJsonWithCookie<UserPayload>('/user/login', encodedBody);
  return { user: normalizeUser(data), cookie };
}

export async function logoutUser(cookie?: string): Promise<void> {
  await getJson('/user/logout/json', cookie);
}

export async function fetchTopArticles(): Promise<Article[]> {
  const data = await getJson<ArticlePayload[]>('/article/top/json');
  if (!Array.isArray(data)) {
    throw new Error('文章数据格式错误');
  }
  return data.map(mapArticle);
}

export async function fetchLatestArticles(page: number = 0): Promise<Article[]> {
  const payload = await getJson<ArticleListPayload>(`/article/list/${page}/json`);
  const datas = payload.datas ?? [];
  return datas.map(mapArticle);
}

export async function fetchArticlesByCid(cid: number, page: number = 0): Promise<Article[]> {
  const encoded = encodeURIComponent(String(cid));
  const payload = await getJson<ArticleListPayload>(`/article/list/${page}/json?cid=${encoded}`);
  const datas = payload.datas ?? [];
  return datas.map(mapArticle);
}

export async function fetchArticleById(id: number): Promise<Article | null> {
  if (!id || Number.isNaN(id)) {
    return null;
  }

  const requests: Promise<Article[]>[] = [fetchTopArticles(), fetchLatestArticles()];
  const [top, latest] = await Promise.all(requests);
  const merged = [...top, ...latest];
  return merged.find(item => item.id === id) ?? null;
}

export async function fetchArticlesByIds(ids: Set<number>): Promise<Article[]> {
  if (!ids || ids.size === 0) {
    return [];
  }

  const requests: Promise<Article[]>[] = [fetchTopArticles(), fetchLatestArticles()];
  const [top, latest] = await Promise.all(requests);
  const all = [...top, ...latest];
  const map = new Map<number, Article>();
  all.forEach(item => {
    if (ids.has(item.id)) {
      map.set(item.id, item);
    }
  });

  return Array.from(map.values());
}

export async function searchArticles(keyword: string): Promise<Article[]> {
  const kw = keyword.trim();
  if (kw.length === 0) {
    return [];
  }

  const payload = await postJson<ArticleListPayload>('/article/query/0/json', `k=${encodeURIComponent(kw)}`);
  const datas = payload.datas ?? [];
  return datas.map(mapArticle);
}

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