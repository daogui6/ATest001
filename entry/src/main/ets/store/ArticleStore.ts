import type { Article } from '../model/Article';

export class ArticleStore {
  private static articleMap: Map<number, Article> = new Map<number, Article>();

  static setArticles(list: Article[]): void {
    list.forEach(item => {
      if (item && typeof item.id === 'number') {
        ArticleStore.articleMap.set(item.id, item);
      }
    });
  }

  static setArticle(article: Article): void {
    if (article && typeof article.id === 'number') {
      ArticleStore.articleMap.set(article.id, article);
    }
  }

  static getArticleById(id: number): Article | null {
    if (!id || Number.isNaN(id)) {
      return null;
    }
    return ArticleStore.articleMap.get(id) ?? null;
  }

  static clear(): void {
    ArticleStore.articleMap.clear();
  }
}