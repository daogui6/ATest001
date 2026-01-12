/**
 * 首页 - 文章流展示页面
 *
 * 功能概述：
 * - 展示置顶文章和最新文章
 * - 支持下拉刷新和上拉加载更多
 * - 文章收藏状态管理
 * - 搜索功能入口
 * - 个性化推荐算法
 * - 轮播图展示
 *
 * 组件结构：
 * - Component组件封装首页逻辑
 * - 响应式状态管理文章数据
 * - 全局状态同步收藏状态
 * - 推荐算法个性化排序
 *
 * 状态管理：
 * - 文章列表和分页状态
 * - 收藏ID集合管理
 * - 加载和错误状态
 * - 动画效果状态
 * - 推荐策略展示状态
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

// 数据模型和存储导入
import type { Article } from '../model/Article';
import { FavoriteStore } from '../store/FavoriteStore';
import { fetchCategories, fetchLatestArticles, fetchTopArticles } from '../service/WanService';
import { ArticleStore } from '../store/ArticleStore';
import type { Category } from '../model/Category';
import { HistoryStore } from '../store/HistoryStore';
import { AppLoadingProgress } from '../components/AppLoadingProgress';

// 确保全局状态key存在 - 用于跨页面状态同步
AppStorage.setOrCreate('fav_version', 0);    // 收藏状态版本号，用于触发收藏状态更新
AppStorage.setOrCreate('session_version', 0); // 会话版本号，用于用户登录状态变化

/**
 * 分类页面路由参数接口
 */
interface CategoryRouteParams {
  cid?: number;        // 可选分类ID，指定跳转到具体分类
  fromHome?: boolean;  // 标记是否从首页跳转
}

/**
 * 个性化推荐配置接口
 * 基于用户行为构建的推荐策略
 */
interface RecommendationProfile {
  scores: Map<number, number>;  // 分类偏好分数映射，key为分类ID，value为偏好分数
  strategyText: string;         // 推荐策略描述文本
  topics: Category[];           // 推荐的主题分类列表
}

/**
 * 排序后的文章接口
 * 用于推荐算法中的文章排序
 */
interface RankedArticle {
  item: Article;   // 文章对象
  index: number;   // 原始索引位置
  score: number;   // 综合评分（偏好分 + 置顶加分）
}

/**
 * 轮播图项接口
 * 首页顶部轮播图的数据结构
 */
interface BannerItem {
  id: string;      // 轮播图唯一标识
  title: string;   // 主标题
  subtitle: string; // 副标题
  image: string;   // 图片URL
}

/**
 * 首页组件
 * 核心职责：文章流展示和用户交互
 *
 * 主要功能：
 * - 文章列表展示（置顶+最新）
 * - 个性化推荐排序
 * - 收藏状态管理
 * - 下拉刷新和上拉加载
 * - 搜索和分类导航
 */
@Component
export struct HomePage {
  /**
   * 获取宿主上下文
   * 用于访问应用级别的上下文信息
   */
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  // ==================== 全局状态同步 ====================

  /**
   * 收藏状态版本号
   * 用于监听收藏状态变化，触发收藏列表更新
   */
  @StorageLink('fav_version')
  @Watch('onFavVersionChange')
  favVersion: number = 0;

  /**
   * 会话版本号
   * 用于监听用户登录状态变化，更新个性化推荐
   */
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;

  // ==================== 文章数据状态 ====================

  @State articles: Article[] = [];           // 文章列表数据
  @State loading: boolean = true;            // 初始加载状态
  @State refreshing: boolean = false;        // 下拉刷新状态
  @State loadingMore: boolean = false;       // 加载更多状态
  @State errorMsg: string = '';              // 错误信息
  @State uid: string = '0';                  // 用户ID，'0'表示未登录
  @State favIds: Set<number> = new Set<number>(); // 收藏文章ID集合
  @State nextPage: number = 0;               // 下一页页码（用于分页加载）
  @State hasMore: boolean = true;            // 是否有更多数据可加载
  @State strategyText: string = '基于热门与最新内容推荐，浏览/收藏后会更懂你'; // 推荐策略描述
  @State topics: Category[] = [];            // 推荐的主题分类列表
  @State showStrategy: boolean = false;      // 是否显示推荐策略面板

  // ==================== UI动画状态 ====================

  @State showBackToTop: boolean = false;     // 是否显示返回顶部按钮
  @State headerOpacity: number = 0;          // 头部导航栏透明度
  @State headerOffset: number = 12;          // 头部导航栏偏移量
  @State backTopOpacity: number = 0;         // 返回顶部按钮透明度
  @State backTopScale: number = 0.9;         // 返回顶部按钮缩放比例

  // ==================== 私有属性 ====================

  private listScroller: Scroller = new Scroller();           // 列表滚动控制器
  private preferenceScores: Map<number, number> = new Map<number, number>(); // 用户偏好分数映射
  private topArticleIds: Set<number> = new Set<number>();    // 置顶文章ID集合
  private bannerItems: BannerItem[] = [                      // 轮播图数据
    {
      id: 'banner-1',
      title: '今日推荐 · 热门趋势',
      subtitle: '精选全站最新热门内容',
      image: 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80'
    },
    {
      id: 'banner-2',
      title: '灵感速递 · 专题合集',
      subtitle: '知识专题一键掌握',
      image: 'https://images.unsplash.com/photo-1500534623283-312aade485b7?auto=format&fit=crop&w=1200&q=80'
    },
    {
      id: 'banner-3',
      title: '高效工作流',
      subtitle: '工具与方法高效整理',
      image: 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=1200&q=80'
    }
  ];

  /**
   * 收藏版本变化监听器
   * 当全局收藏状态变化时触发收藏列表刷新
   */
  private onFavVersionChange() {
    this.refreshFav();
  }

  /**
   * 会话版本变化监听器
   * 当用户登录状态变化时触发收藏列表刷新
   */
  private onSessionVersionChange() {
    this.refreshFav();
  }

  /**
   * 刷新收藏状态
   * 获取当前用户的收藏列表并更新本地状态
   *
   * 逻辑流程：
   * 1. 获取当前用户ID
   * 2. 如果是未登录用户，清空收藏状态
   * 3. 如果是登录用户，加载收藏列表
   */
  private async refreshFav() {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);
    this.uid = uid;

    if (uid === '0') {
      // 未登录用户清空收藏状态
      this.favIds = new Set<number>();
      return;
    }

    this.favIds = await FavoriteStore.loadFavSet(ctx, uid);
  }

  /**
   * 组件生命周期：页面即将显示
   * 执行页面初始化操作
   */
  async aboutToAppear() {
    await this.reloadArticles();   // 加载文章数据
    await this.refreshFav();       // 刷新收藏状态
  }

  /**
   * 文章去重工具方法
   * 根据文章ID去除重复的文章项
   *
   * @param list 待去重的文章列表
   * @returns 去重后的文章列表
   */
  private dedupArticles(list: Article[]): Article[] {
    const seen = new Set<number>();
    const result: Article[] = [];
    list.forEach(item => {
      if (!seen.has(item.id)) {
        seen.add(item.id);
        result.push(item);
      }
    });
    return result;
  }

  /**
   * 重新加载文章数据
   * 获取置顶文章和最新文章，并应用推荐算法排序
   *
   * @param randomize 是否随机化相同分数的文章顺序（用于刷新时增加新鲜感）
   */
  private async reloadArticles(randomize: boolean = false) {
    this.loading = true;
    this.errorMsg = '';
    this.hasMore = true;
    this.nextPage = 0;

    try {
      // 并行获取置顶文章、最新文章和分类数据
      const result = await Promise.all([
        fetchTopArticles(),        // 获取置顶文章
        fetchLatestArticles(0),    // 获取第一页最新文章
        fetchCategories()          // 获取分类列表
      ]);

      const top = result[0];
      const latest = result[1];
      const categories = result[2];

      // 构建个性化推荐配置
      const profile = await this.buildRecommendationProfile(categories);
      this.preferenceScores = profile.scores;
      this.topArticleIds = new Set(top.map(item => item.id));
      this.strategyText = profile.strategyText;
      this.topics = profile.topics;

      // 合并并去重文章列表
      const merged: Article[] = [...top, ...latest];
      const deduped = this.dedupArticles(merged);

      // 应用推荐算法排序
      this.articles = this.rankArticles(deduped, this.preferenceScores, this.topArticleIds, randomize);
      this.hasMore = latest.length > 0;
      this.nextPage = 1;
    } catch (e) {
      this.errorMsg = (e as Error)?.message ?? '加载失败';
      this.articles = [];
      this.hasMore = false;
    } finally {
      this.loading = false;
    }
  }

  /**
   * 刷新文章列表
   * 下拉刷新时调用，会重新加载数据并随机化排序
   */
  private async refreshArticles() {
    if (this.refreshing) {
      return;
    }
    this.refreshing = true;
    await this.reloadArticles(true);  // 传入true进行随机化排序
    this.refreshing = false;
  }

  /**
   * 加载更多文章
   * 上拉加载更多时调用，分页获取数据
   */
  private async loadMoreArticles() {
    if (this.loadingMore || this.loading || !this.hasMore) {
      return;
    }

    this.loadingMore = true;
    this.errorMsg = '';

    try {
      const latest = await fetchLatestArticles(this.nextPage);
      if (latest.length === 0) {
        this.hasMore = false;
        return;
      }

      // 合并新数据并重新排序
      const merged = [...this.articles, ...latest];
      const deduped = this.dedupArticles(merged);
      this.articles = this.rankArticles(deduped, this.preferenceScores, this.topArticleIds);
      this.nextPage += 1;
    } catch (e) {
      this.errorMsg = (e as Error)?.message ?? '加载失败';
    } finally {
      this.loadingMore = false;
    }
  }

  /**
   * 滚动到列表顶部
   * 返回顶部按钮点击时调用
   */
  private scrollToTop() {
    this.listScroller.scrollToIndex(0);
  }

  /**
   * 头部导航栏动画
   * 页面显示时执行的入场动画
   */
  private animateHeader() {
    animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
      this.headerOpacity = 1;
      this.headerOffset = 0;
    });
  }

  /**
   * 更新返回顶部按钮显示状态
   * 根据滚动位置控制按钮的显示/隐藏和动画
   *
   * @param show 是否显示返回顶部按钮
   */
  private updateBackToTop(show: boolean) {
    if (this.showBackToTop === show) {
      return;
    }
    this.showBackToTop = show;
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.backTopOpacity = show ? 1 : 0;
      this.backTopScale = show ? 1 : 0.9;
    });
  }

  /**
   * 增加收藏版本号
   * 触发全局收藏状态更新，同步到其他页面
   */
  private async bumpFavVersion() {
    const v = (AppStorage.get('fav_version') as number) ?? 0;
    AppStorage.set('fav_version', v + 1);
  }

  /**
   * 切换文章收藏状态
   *
   * @param article 要切换收藏状态的文章
   *
   * 逻辑流程：
   * 1. 检查用户登录状态
   * 2. 更新本地收藏状态
   * 3. 持久化收藏数据
   * 4. 触发全局状态更新
   */
  private async toggleFav(article: Article) {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);

    // 未登录用户提示登录
    if (uid === '0') {
      promptAction.showToast({ message: '请先在【我的】里登录' });
      return;
    }

    const next = new Set(this.favIds);
    if (next.has(article.id)) {
      // 取消收藏
      next.delete(article.id);
      await FavoriteStore.removeArticleSnapshot(ctx, article.id);
    } else {
      // 添加收藏
      next.add(article.id);
      await FavoriteStore.saveArticleSnapshot(ctx, article);
    }

    this.favIds = next;
    await FavoriteStore.saveFavSet(ctx, uid, next);
    await this.bumpFavVersion();  // 触发全局状态更新
  }

  /**
   * 打开搜索页面
   */
  private async openSearchPage() {
    try {
      await router.pushUrl({ url: 'pages/SearchPage' });
    } catch (e) {
      promptAction.showToast({ message: '无法打开搜索页' });
    }
  }

  /**
   * 打开分类页面
   *
   * @param cid 可选分类ID，指定跳转到具体分类
   */
  private async openCategoryPage(cid?: number) {
    try {
      const params: CategoryRouteParams | undefined = cid ? { cid, fromHome: true } : { fromHome: true };
      await router.pushUrl({
        url: 'pages/CategoryPage',
        params
      });
    } catch (e) {
      promptAction.showToast({ message: '无法打开分类页' });
    }
  }

  /**
   * 构建个性化推荐配置
   * 基于用户行为和偏好计算推荐策略
   *
   * @param categories 全部分类列表
   * @returns 推荐配置对象
   *
   * 算法逻辑：
   * 1. 获取用户收藏和浏览历史
   * 2. 计算各分类的偏好分数（收藏权重3，浏览权重1）
   * 3. 生成推荐策略描述文本
   * 4. 排序并筛选推荐主题
   */
  private async buildRecommendationProfile(categories: Category[]): Promise<RecommendationProfile> {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);
    const favSet = uid === '0' ? new Set<number>() : await FavoriteStore.loadFavSet(ctx, uid);
    const favArticles = favSet.size > 0
      ? await FavoriteStore.pickCachedArticles(ctx, favSet)
      : [];
    const history = await HistoryStore.loadHistory(ctx);

    const scores = new Map<number, number>();

    /**
     * 增加分类分数
     * @param cid 分类ID
     * @param weight 权重分数
     */
    const bumpScore = (cid: number, weight: number): void => {
      if (!cid || Number.isNaN(cid)) {
        return;
      }
      scores.set(cid, (scores.get(cid) ?? 0) + weight);
    };

    // 根据收藏记录计算偏好分数
    favArticles.forEach((article: Article): void => {
      bumpScore(article.cid, 3);  // 收藏文章权重为3
    });

    // 根据浏览历史计算偏好分数
    history.forEach((article: Article): void => {
      bumpScore(article.cid, 1);  // 浏览历史权重为1
    });

    // 生成推荐策略描述文本
    const reasons: string[] = [];
    if (favArticles.length > 0) {
      reasons.push('收藏');
    }
    if (history.length > 0) {
      reasons.push('最近浏览');
    }

    const strategyText = reasons.length > 0
      ? `根据你的${reasons.join('和')}，优先推荐相关分类内容`
      : '基于热门与最新内容推荐，浏览/收藏后会更懂你';

    // 根据偏好分数排序并筛选推荐主题
    const topics: Category[] = [];
    const sortedPrefs = Array.from(scores.entries()) as Array<[number, number]>;//scores.entries() 得到类似：(cid=10, score=7)(cid=20, score=2)
    sortedPrefs.sort((a: [number, number], b: [number, number]) => b[1] - a[1]);

    sortedPrefs.forEach((entry: [number, number]) => {
      const cid = entry[0];
      const matched = categories.find(item => item.cid === cid);
      if (matched) {
        topics.push(matched);
      }
    });

    // 补充其他分类，确保有足够的推荐主题
    const supplement = categories.filter(item => !topics.some(topic => topic.cid === item.cid));//从所有分类 categories 里挑出那些 不在 topics 里的分类，作为补充列表 supplement。
    const combined = [...topics, ...supplement].slice(0, 6);  // 最多显示6个主题

    const profile: RecommendationProfile = { scores, strategyText, topics: combined };
    return profile;
  }

  /**
   * 数组原地随机排序（Fisher-Yates洗牌算法）
   *
   * @param list 待随机排序的数组
   */
  private shuffleInPlace<T>(list: T[]): void {
    for (let i = list.length - 1; i > 0; i -= 1) {
      const j = Math.floor(Math.random() * (i + 1));
      const temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
  }

  /**
   * 文章排序算法
   * 根据偏好分数和置顶状态对文章进行排序
   *
   * @param list 待排序的文章列表
   * @param scores 分类偏好分数映射
   * @param topIds 置顶文章ID集合
   * @param randomize 是否对相同分数的文章进行随机排序
   * @returns 排序后的文章列表
   *
   * 排序规则：
   * 1. 置顶文章获得额外加分（+2）
   * 2. 根据分类偏好分数排序
   * 3. 相同分数时保持原始顺序或随机排序
   */
  private rankArticles(
    list: Article[],
    scores: Map<number, number>,
    topIds: Set<number>,
    randomize: boolean = false
  ): Article[] {
    // 计算每篇文章的综合评分
    const ranked = list.map((item: Article, index: number): RankedArticle => {
      const preferenceScore = scores.get(item.cid) ?? 0;  // 分类偏好分数
      const topBonus = topIds.has(item.id) ? 2 : 0;       // 置顶加分
      return {
        item,
        index,
        score: preferenceScore + topBonus  // 综合评分
      };
    });

    // 按评分降序排序，评分相同时按原始索引排序
    ranked.sort((a, b) => {
      if (b.score === a.score) {
        return a.index - b.index;
      }
      return b.score - a.score;
    });

    // 如果需要随机化，对相同分数的文章组进行随机排序
    if (randomize) {
      let start = 0;
      while (start < ranked.length) {
        const score = ranked[start].score;
        let end = start + 1;

        // 找到相同分数的连续文章组
        while (end < ranked.length && ranked[end].score === score) {
          end += 1;
        }

        // 对相同分数的文章组进行随机排序
        const group = ranked.slice(start, end);
        this.shuffleInPlace(group);

        // 将随机排序后的组放回原数组
        for (let i = 0; i < group.length; i += 1) {
          ranked[start + i] = group[i];
        }
        start = end;
      }
    }

    return ranked.map(entry => entry.item);
  }

  /**
   * UI构建方法
   * 创建首页文章流界面
   *
   * 界面结构：
   * 1. 背景图片
   * 2. 主要内容区域（Column）
   *    - 头部导航栏
   *    - 推荐策略面板（可展开/收起）
   *    - 文章列表区域
   * 3. 返回顶部按钮（浮动）
   */
  build() {
    Stack() {
      // 背景图片
      Image($r('app.media.bgt'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      // 主要内容区域
      Column() {
        // ==================== 头部导航栏 ====================
        Row() {
          // 推荐策略按钮
          Button(this.showStrategy ? '收起策略' : '推荐策略', { type: ButtonType.Capsule })
            .fontSize(12)
            .fontColor('#4F46E5')
            .backgroundColor('#EEF2FF')
            .height(28)
            .padding({ left: 10, right: 10 })
            .onClick(() => {
              this.showStrategy = !this.showStrategy;
            })

          // 页面标题
          Text('首页')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          // 搜索按钮
          Text('搜索')
            .fontSize(18)
            .backgroundColor('#F3F4F6')
            .padding(6)
            .borderRadius(14)
            .shadow({ radius: 8, color: '#14000000', offsetX: 0, offsetY: 3 })
            .onClick(async () => await this.openSearchPage())
        }
        .alignItems(VerticalAlign.Center)
        .padding(12)
        .margin({ top: 12, left: 16, right: 16, bottom: 12 })
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .shadow({ radius: 14, color: '#14000000', offsetX: 0, offsetY: 6 })
        .opacity(this.headerOpacity)
        .translate({ x: 0, y: this.headerOffset })

        // ==================== 推荐策略面板 ====================
        if (this.showStrategy) {
          Column({ space: 10 }) {
            Text('推荐策略')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .textAlign(TextAlign.Center)
            Text(this.strategyText)
              .fontSize(12)
              .opacity(0.7)
              .textAlign(TextAlign.Center)

            // 推荐主题标签
            if (this.topics.length > 0) {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
                ForEach(this.topics, (topic: Category) => {
                  Text(topic.name)
                    .fontSize(12)
                    .padding({
                      left: 12,
                      right: 12,
                      top: 6,
                      bottom: 6
                    })
                    .margin({ right: 8, bottom: 8 })
                    .backgroundColor('#F1F5F9')
                    .borderRadius(14)
                    .onClick(async () => await this.openCategoryPage(topic.cid))
                })
              }
            }

            // 查看全部专题链接
            Row() {
              Text('查看全部专题')
                .fontSize(12)
                .fontColor('#3B82F6')
                .onClick(async () => await this.openCategoryPage())
              Blank().layoutWeight(1)
            }
          }
          .padding(14)
          .margin({ left: 16, right: 16, bottom: 12 })
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .shadow({ radius: 12, color: '#12000000', offsetX: 0, offsetY: 4 })
        }

        // ==================== 内容区域 ====================

        // 加载状态显示
        if (this.loading) {
          Column({ space: 8 }) {
            AppLoadingProgress()
            Text('正在加载文章...')
              .opacity(0.7)
              .textAlign(TextAlign.Center)
          }
          .alignItems(HorizontalAlign.Center)
          .width('100%')
          .padding(16)
        } else if (this.errorMsg) {
          // 错误状态显示
          Column({ space: 6 }) {
            Text('网络加载失败，数据暂不可用').fontSize(14).opacity(0.7)
            Text(this.errorMsg).fontSize(12).opacity(0.6)
          }
          .padding({ left: 16, right: 16, bottom: 6 })
        }

        // ==================== 文章列表区域 ====================
        Refresh({ refreshing: this.refreshing }) {
          List({ scroller: this.listScroller }) {
            // 轮播图区域
            ListItem() {
              Column() {
                Swiper() {
                  ForEach(this.bannerItems, (banner: BannerItem) => {
                    Stack({ alignContent: Alignment.BottomStart }) {
                      Image(banner.image)
                        .width('100%')
                        .height('100%')
                        .objectFit(ImageFit.Cover)
                      Column({ space: 4 }) {
                        Text(banner.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                        Text(banner.subtitle).fontSize(12).opacity(0.85).fontColor('#FFFFFF')
                      }
                      .padding(12)
                      .backgroundColor('#66000000')
                      .borderRadius(12)
                      .margin(12)
                    }
                  }, (banner: BannerItem) => banner.id)
                }
                .autoPlay(true)
                .interval(3200)
                .indicator(true)
                .height(160)
              }
              .padding(12)
              .margin({ left: 16, right: 16, bottom: 12 })
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .shadow({ radius: 12, color: '#14000000', offsetX: 0, offsetY: 6 })
            }

            // 文章列表项
            ForEach(this.articles, (item: Article) => {
              ListItem() {
                Row() {
                  // 文章信息区域
                  Column({ space: 6 }) {
                    Text(item.title).fontSize(16).fontWeight(FontWeight.Medium)
                    Text(item.desc).fontSize(13).opacity(0.7).maxLines(2)
                    Text(`作者：${item.author}`).fontSize(12).opacity(0.6)
                  }
                  .layoutWeight(1)

                  // 收藏按钮
                  Text(this.favIds.has(item.id) ? '★' : '☆')
                    .fontSize(22)
                    .margin({ left: 10 })
                    .onClick(async () => await this.toggleFav(item))
                }
                .padding(12)
                .margin({ left: 16, right: 16, bottom: 12 })
                .borderRadius(16)
                .backgroundColor('#FFFFFF')
                .shadow({ radius: 12, color: '#1A000000', offsetX: 0, offsetY: 5 })
                .onClick(() => {
                  // 跳转到文章详情页
                  ArticleStore.setArticles(this.articles);
                  router.pushUrl({
                    url: 'pages/ArticleDetailPage',
                    params: { id: item.id, article: item }
                  })
                })
              }
            })

            // ==================== 列表底部状态 ====================
            ListItem() {
              if (this.loadingMore) {
                // 加载更多状态
                Row({ space: 8 }) {
                  AppLoadingProgress()
                  Text('加载中...').fontSize(13).opacity(0.7)
                }
                .padding(12)
                .justifyContent(FlexAlign.Center)
              } else if (!this.hasMore) {
                // 无更多数据状态
                Text('已经到底了').fontSize(12).opacity(0.6).padding(12)
              } else {
                // 提示上拉加载更多
                Text('上拉加载更多').fontSize(12).opacity(0.5).padding(12)
              }
            }
          }
          .width('100%')
          .layoutWeight(1)
          .onScrollIndex((first, last) => {
            // 滚动到底部时自动加载更多
            if (last >= this.articles.length - 1) {
              this.loadMoreArticles();
            }
            // 控制返回顶部按钮显示
            this.updateBackToTop(first > 0);
          })
        }
        .onRefreshing(async () => {
          // 下拉刷新回调
          await this.refreshArticles();
        })
      }
      .width('100%')
      .height('100%')
      .onAppear(() => {
        // 页面显示时执行的操作
        this.refreshFav();     // 刷新收藏状态
        this.animateHeader();  // 执行头部动画
      })

      // ==================== 返回顶部按钮 ====================
      Button('↑')
        .backgroundColor('#FFFFFF')
        .fontColor('#444444')
        .border({ width: 1, color: '#E3E5EA', style: BorderStyle.Solid })
        .borderRadius(20)
        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
        .position({ x: '85%', y: '92%' })
        .margin({ right: 16, bottom: 24 })
        .shadow({ radius: 10, color: '#1A000000', offsetX: 0, offsetY: 4 })
        .opacity(this.backTopOpacity)
        .scale({ x: this.backTopScale, y: this.backTopScale })
        .enabled(this.showBackToTop)
        .onClick(() => this.scrollToTop())
    }
    .width('100%')
    .height('100%')
  }
}