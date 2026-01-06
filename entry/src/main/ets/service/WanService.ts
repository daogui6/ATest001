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

const BASE = 'https://www.wanandroid.com';
const HTTP_TIMEOUT = 12000;

async function getJson<T>(path: string): Promise<T> {
  const client = http.createHttp();
  try {
    const resp = await client.request(`${BASE}${path}`, {
      method: http.RequestMethod.GET,
      connectTimeout: HTTP_TIMEOUT,
      readTimeout: HTTP_TIMEOUT,
      expectDataType: http.HttpDataType.STRING
    });

    const status = resp.responseCode ?? 0;
    const raw = String(resp.result ?? '');
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
  } finally {
    client.destroy();
  }
}

function mapArticle(item: ArticlePayload): Article {
  const id = item.id ?? 0;
  const title = item.title ?? '未命名';
  const desc = item.desc && item.desc.trim().length > 0 ? item.desc : title;
  const link = item.link && item.link.trim().length > 0 ? item.link.trim() : '';
  const author = (item.author && item.author.trim().length > 0)
    ? item.author
    : (item.shareUser && item.shareUser.trim().length > 0 ? item.shareUser : '佚名');
  const cid = item.chapterId ?? item.superChapterId ?? 0;

  const content = `${title}\n\n来源：wanandroid（ID=${id}）\n作者：${author}\n分类：${cid}\n链接：${link || '暂无链接'}\n\n摘要：${desc}`;
  return {
    id,
    title,
    desc,
    author,
    cid,
    content
  };
}

export async function fetchTopArticles(): Promise<Article[]> {
  const data = await getJson<ArticlePayload[]>('/article/top/json');
  if (!Array.isArray(data)) {
    throw new Error('文章数据格式错误');
  }
  return data.map(mapArticle);
}

export async function fetchLatestArticles(): Promise<Article[]> {
  const payload = await getJson<ArticleListPayload>('/article/list/0/json');
  const datas = payload.datas ?? [];
  return datas.map(mapArticle);
}

export async function fetchArticlesByCid(cid: number): Promise<Article[]> {
  const encoded = encodeURIComponent(String(cid));
  const payload = await getJson<ArticleListPayload>(`/article/list/0/json?cid=${encoded}`);
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