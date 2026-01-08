/*
 * ArticleStore.ts - 文章数据内存存储管理
 * 
 * 功能说明：
 * - 提供文章数据的临时内存存储
 * - 支持文章的批量设置和单个设置
 * - 提供按ID快速检索文章的功能
 * - 支持存储的清理和重置
 * 
 * 设计特点：
 * - 使用Map数据结构实现高效查找
 * - 静态类设计，全局共享存储
 * - 轻量级内存缓存，不涉及持久化
 * - 数据验证和类型安全
 * 
 * 使用场景：
 * - 文章列表页到详情页的数据传递
 * - 避免重复网络请求的缓存
 * - 临时数据共享和状态管理
 */

import type { Article } from '../model/Article';

/**
 * 文章数据内存存储管理类
 * 
 * 提供文章数据的临时内存存储和管理功能
 * 采用静态类设计，便于全局访问和共享数据
 */
export class ArticleStore {
  /**
   * 文章数据存储Map
   * 使用Map数据结构以文章ID为键，文章对象为值
   * 提供O(1)时间复杂度的查找性能
   */
  private static articleMap: Map<number, Article> = new Map<number, Article>();

  // ========== 文章数据操作方法 ==========
  
  /**
   * 批量设置文章数据
   * 将文章列表添加到内存存储中
   * 
   * @param list 文章对象数组
   */
  static setArticles(list: Article[]): void {
    // 遍历文章列表，验证并添加到存储
    list.forEach(item => {
      // 验证文章对象有效性
      if (item && typeof item.id === 'number') {
        // 使用文章ID作为键存储文章对象
        ArticleStore.articleMap.set(item.id, item);
      }
    });
  }

  /**
   * 设置单个文章数据
   * 将单个文章对象添加到内存存储中
   * 
   * @param article 文章对象
   */
  static setArticle(article: Article): void {
    // 验证文章对象有效性
    if (article && typeof article.id === 'number') {
      // 使用文章ID作为键存储文章对象
      ArticleStore.articleMap.set(article.id, article);
    }
  }

  /**
   * 根据文章ID获取文章数据
   * 
   * @param id 文章ID
   * @returns 文章对象或null（未找到时）
   */
  static getArticleById(id: number): Article | null {
    // 验证ID有效性
    if (!id || Number.isNaN(id)) {
      return null;
    }
    
    // 从Map中获取文章对象，未找到时返回null
    return ArticleStore.articleMap.get(id) ?? null;
  }

  /**
   * 清空所有文章数据
   * 清除内存存储中的所有文章对象
   */
  static clear(): void {
    // 清空Map存储
    ArticleStore.articleMap.clear();
  }
}