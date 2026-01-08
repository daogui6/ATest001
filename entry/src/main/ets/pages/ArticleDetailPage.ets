/**
 * 文章详情页面 - 核心功能页面
 * 
 *  功能概述：
 * - 完整的文章展示与交互系统
 * - 集成AI智能分析（总结/锐评/答疑）
 * - 多层级评论系统与点赞互动
 * - 收藏管理、历史记录、分享功能
 * - 跨组件状态同步与数据持久化
 * 
 *  架构特点：
 * - 采用MVVM模式，数据与UI分离
 * - 多Store状态管理，职责清晰
 * - 响应式状态驱动UI更新
 * - 模块化设计，易于扩展维护
 * 
 *  技术亮点：
 * - 智能文章解析策略（参数 > 缓存 > 远程 > 历史）
 * - WebView与原生内容无缝切换
 * - 嵌套评论树形结构渲染
 * - 全局状态同步机制
 * - AI服务集成与异步处理
 */

import router from '@ohos.router';
import type common from '@ohos.app.ability.common';
import type resourceManager from '@ohos.resourceManager';
import pasteboard from '@ohos.pasteboard';
import promptAction from '@ohos.promptAction';
import webview from '@ohos.web.webview';

// 数据模型导入
import type { Article } from '../model/Article';
import { FavoriteStore } from '../store/FavoriteStore';
import { callZhipu, type AiMode } from '../service/ZhipuAI';
import { HistoryStore } from '../store/HistoryStore';
import { ArticleStore } from '../store/ArticleStore';
import { fetchArticleContent } from '../service/ArticleContentService';
import { fetchArticleById } from '../service/WanService';
import type { Comment } from '../model/Comment';
import { InteractionStore, type LikeState } from '../store/InteractionStore';
import { UserActionStore } from '../store/UserActionStore';
import { UserStore } from '../store/UserStore';
import { NotificationStore } from '../store/NotificationStore';
import type { NotificationItem } from '../model/Notification';

/**
 * 页面路由参数接口
 * 支持两种传参方式：直接传递文章对象 或 传递文章ID
 */
interface DetailParams {
  id?: number | string;
  article?: Article;
}

/**
 *  全局状态版本控制
 * 通过AppStorage实现跨页面状态同步
 * 当收藏、会话、历史等状态变化时，触发相关页面更新
 */
AppStorage.setOrCreate('fav_version', 0);
AppStorage.setOrCreate('session_version', 0);
AppStorage.setOrCreate('history_version', 0);
AppStorage.setOrCreate('liked_version', 0);
AppStorage.setOrCreate('commented_version', 0);
AppStorage.setOrCreate('notification_version', 0);

/**
 * 评论视图接口 - 扩展基础评论模型
 * 添加点赞状态、计数和回复列表，用于UI渲染
 */
interface CommentView extends Comment {
  likeCount: number;
  liked: boolean;
  replies: CommentView[];
}

/**
 * 评论视图更新接口
 * 用于部分更新评论状态，避免不必要的重渲染
 */
interface CommentViewOverrides {
  liked?: boolean;
  likeCount?: number;
  replies?: CommentView[];
}

/**
 *  文章详情页主组件
 * 
 * @Entry 装饰器标记为页面入口组件
 * @Component 定义可复用的UI组件结构
 * 
 * 核心职责：
 * - 文章内容展示与交互
 * - 用户行为管理（收藏、点赞、评论）
 * - AI功能集成与展示
 * - 状态同步与数据持久化
 */
@Entry
@Component
struct ArticleDetailPage {
  /**
   * 获取宿主上下文
   * 用于访问UIAbility的上下文，执行系统级操作
   */
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  //  响应式状态管理
  
  /**
   * @State 管理的组件内部状态
   * 状态变化会自动触发UI重新渲染
   */
  @State article: Article | null = null; // 当前文章数据
  @State uid: string = '0'; // 当前用户ID
  @State favIds: Set<number> = new Set<number>(); // 用户收藏的文章ID集合
  
  /**
   * WebView控制器
   * 用于管理内嵌网页的加载、导航等操作
   */
  private webController: webview.WebviewController = new webview.WebviewController();
  
  //  AI相关状态
  @State aiLoading: boolean = false; // AI总结/锐评加载状态
  @State aiText: string = ''; // AI生成的内容
  @State aiMode: AiMode = 'summary'; // AI模式：summary总结 / review锐评
  @State aiQuestion: string = ''; // 用户提问的问题
  @State aiAnswer: string = ''; // AI回答的内容
  @State aiQaLoading: boolean = false; // AI答疑加载状态
  private aiSourceContent: string = ''; // 缓存已读取的原文正文，避免重复请求
  private aiSourceLink: string = '';// 记录缓存对应的链接，便于更新时刷新缓存
  
  /**
   *  全局状态同步
   * @StorageLink 与AppStorage建立双向绑定
   * @Watch 监听状态变化，触发回调函数
   * 
   * 实现机制：当其他页面修改AppStorage中的版本号时，
   * 当前页面会自动同步更新并触发相应的刷新逻辑
   */
  @StorageLink('fav_version')
  @Watch('onFavVersionChange')
  favVersion: number = 0; // 收藏版本号，用于同步收藏状态
  
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0; // 会话版本号，用于同步登录状态
  
  //  评论相关状态
  @State comments: CommentView[] = []; // 评论列表（树形结构）
  @State commentCount: number = 0; // 评论总数
  @State newComment: string = ''; // 新评论内容
  @State replyTarget: CommentView | null = null; // 回复目标评论
  @State likeCount: number = 0; // 文章点赞数
  @State liked: boolean = false; // 当前用户是否点赞
  @State commentSectionTop: number = 0; // 评论区域顶部位置，用于滚动定位
  
  /**
   * 滚动控制器
   * 用于实现精确的滚动控制，如滚动到评论区域
   */
  private detailScroller: Scroller = new Scroller();

  /**
   * 构建评论视图对象
   * 将基础评论数据与点赞状态合并，生成UI可用的视图对象
   */
  private buildCommentView(comment: Comment, state: LikeState): CommentView {
    return {
      id: comment.id,
      articleId: comment.articleId,
      userId: comment.userId,
      nickname: comment.nickname,
      content: comment.content,
      createdAt: comment.createdAt,
      parentId: comment.parentId,
      replyTo: comment.replyTo,
      likeCount: state.count,
      liked: state.liked,
      replies: [],
    };
  }

  /**
   * 合并评论视图更新
   * 采用函数式更新模式，避免直接修改原对象
   * 支持部分属性更新，提高渲染性能
   */
  private mergeCommentView(item: CommentView, overrides: CommentViewOverrides): CommentView {
    return {
      id: item.id,
      articleId: item.articleId,
      userId: item.userId,
      nickname: item.nickname,
      content: item.content,
      createdAt: item.createdAt,
      parentId: item.parentId,
      replyTo: item.replyTo,
      likeCount: overrides.likeCount ?? item.likeCount,
      liked: overrides.liked ?? item.liked,
      replies: overrides.replies ?? item.replies,
    };
  }

  /**
   * 收藏版本变化监听器
   * 当全局收藏状态变化时，刷新本地收藏状态
   */
  private onFavVersionChange() {
    this.refreshFav();
    this.refreshInteractions();
  }

  /**
   * 会话版本变化监听器
   * 当用户登录状态变化时，刷新相关状态
   */
  private onSessionVersionChange() {
    this.refreshFav();
    this.refreshInteractions();
  }

  /**
   *  组件生命周期：页面即将显示
   * 在此阶段执行数据初始化操作
   */
  async aboutToAppear() {
    // 1) 读取路由参数，支持ID和直接传递文章对象两种方式
    const params = router.getParams() as DetailParams;
    const paramArticle = params?.article as Article | undefined;
    const rawId = params?.id;
    const id = typeof rawId === 'number' ? rawId : Number(rawId);

    // 参数验证：必须提供文章ID或文章对象
    if ((!id || Number.isNaN(id)) && !paramArticle) {
      this.article = null;
      promptAction.showToast({ message: '文章参数缺失，无法打开' });
      await this.refreshFav();
      await this.refreshInteractions();
      return;
    }

    // 2) 智能文章解析策略（优先级从高到低）：
    //    - 路由参数直接传递的文章对象
    //    - 本地文章缓存
    //    - 通过ID解析得到的文章
    const resolvedById = await this.resolveArticleById(id);
    this.article = paramArticle
      ?? ArticleStore.getArticleById(id)
      ?? resolvedById;

    // 3) 数据完整性处理：收藏页传参可能缺少链接信息
    //    使用解析得到的文章数据补全链接信息
    if (
      this.article &&
        resolvedById &&
        (!this.article.link || this.article.link.trim().length === 0) &&
      resolvedById.link &&
        resolvedById.link.trim().length > 0
    ) {
      this.article = {
        id: this.article.id,
        title: this.article.title,
        desc: this.article.desc,
        author: this.article.author,
        cid: this.article.cid,
        link: resolvedById.link,
        content: resolvedById.content,
      };
    }

    // 4) 数据缓存：将文章存入本地缓存
    if (this.article) {
      ArticleStore.setArticle(this.article);
    }

    this.aiSourceContent = '';
    this.aiSourceLink = '';

    // 5) 记录浏览历史
    if (this.article) {
      await HistoryStore.addVisit(this.hostCtx(), this.article);
      this.bumpHistoryVersion(); // 触发历史记录更新
    } else {
      promptAction.showToast({ message: '文章不存在或已被移除' });
    }

    // 6) 刷新用户交互状态
    await this.refreshFav();
    await this.refreshInteractions();
  }

  private async resolveAiContent(): Promise<string> {
    // 优先使用原文链接正文，失败时回退到摘要内容
    if (!this.article) {
      return '';
    }
    const link = this.article.link?.trim() ?? '';
    if (link.length === 0) {
      return this.article.content;
    }
    // 同一链接命中缓存时直接复用
    if (this.aiSourceContent && this.aiSourceLink === link) {
      return this.aiSourceContent;
    }
    try {
      // 拉取原文正文并缓存
      const text = await fetchArticleContent(link);
      if (text.trim().length > 0) {
        this.aiSourceContent = text;
        this.aiSourceLink = link;
        return text;
      }
    } catch (e) {
      // 原文不可用时提示并降级为摘要
      promptAction.showToast({ message: '原文读取失败，已使用摘要生成' });
    }
    return this.article.content;
  }

  /**
   *  智能文章解析器
   * 根据文章ID从多个数据源获取文章数据
   * 
   * 数据源优先级：
   * 1. 收藏缓存（数据最完整）
   * 2. 远程API（获取最新数据）
   * 3. 历史记录（兜底方案）
   */
  private async resolveArticleById(id: number): Promise<Article | null> {
    const ctx = this.hostCtx();

    // 优先查询收藏缓存（数据最完整）
    const favList = await FavoriteStore.pickCachedArticles(ctx, new Set([id]));
    if (favList.length > 0) {
      return favList[0];
    }

    // 若缓存缺失，从远程API获取最新数据
    try {
      const remote = await fetchArticleById(id);
      if (remote) {
        return remote;
      }
    } catch (e) {
      promptAction.showToast({ message: (e as Error)?.message ?? '远端文章加载失败' });
    }

    // 最后查询历史记录作为兜底方案
    const historyList = await HistoryStore.loadHistory(ctx);
    return historyList.find(item => item.id === id) ?? null;
  }

  /**
   *  刷新收藏状态
   * 获取当前用户的收藏列表，更新本地状态
   */
  private async refreshFav() {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);
    this.uid = uid;
    
    // 未登录用户清空收藏状态
    if (uid === '0') {
      this.favIds = new Set<number>();
      return;
    }
    
    // 加载用户收藏集合
    this.favIds = await FavoriteStore.loadFavSet(ctx, uid);
  }

  /**
   *  刷新交互数据
   * 加载文章的点赞、评论等用户交互数据
   */
  private async refreshInteractions() {
    if (!this.article) {
      this.comments = [];
      this.commentCount = 0;
      this.likeCount = 0;
      this.liked = false;
      return;
    }

    const ctx = this.hostCtx();
    
    // 1) 加载评论数据
    const rawComments = await InteractionStore.loadComments(ctx, this.article.id);
    this.commentCount = rawComments.length;
    
    // 2) 并行加载每个评论的点赞状态
    const likeStates = new Map<string, LikeState>();
    await Promise.all(
      rawComments.map(async (comment: Comment) => {
        const state = await InteractionStore.loadCommentLikeState(ctx, this.article!.id, comment.id, this.uid);
        likeStates.set(comment.id, state);
      })
    );

    // 3) 构建评论视图映射表
    const viewMap = new Map<string, CommentView>();
    const defaultLikeState: LikeState = { liked: false, count: 0 };
    rawComments.forEach((comment: Comment) => {
      const state = likeStates.get(comment.id) ?? defaultLikeState;
      viewMap.set(comment.id, this.buildCommentView(comment, state));
    });

    // 4) 构建树形评论结构
    const roots: CommentView[] = [];
    rawComments.forEach((comment: Comment) => {
      const view = viewMap.get(comment.id);
      if (!view) {
        return;
      }
      // 如果是回复评论，添加到父评论的replies数组中
      if (view.parentId && viewMap.has(view.parentId)) {
        viewMap.get(view.parentId)!.replies.push(view);
      } else {
        roots.push(view);
      }
    });
    this.comments = roots;
    
    // 5) 加载文章点赞状态
    const likeState = await InteractionStore.loadLikeState(ctx, this.article.id, this.uid);
    this.likeCount = likeState.count;
    this.liked = likeState.liked;
  }

  /**
   *  全局状态版本控制方法
   * 通过递增版本号触发其他页面的状态更新
   */
  
  private bumpFavVersion() {
    const v = (AppStorage.get('fav_version') as number) ?? 0;
    AppStorage.set('fav_version', v + 1);
  }

  private bumpHistoryVersion() {
    const v = (AppStorage.get('history_version') as number) ?? 0;
    AppStorage.set('history_version', v + 1);
  }

  private bumpLikedVersion() {
    const v = (AppStorage.get('liked_version') as number) ?? 0;
    AppStorage.set('liked_version', v + 1);
  }

  private bumpCommentedVersion() {
    const v = (AppStorage.get('commented_version') as number) ?? 0;
    AppStorage.set('commented_version', v + 1);
  }

  private bumpNotificationVersion() {
    const v = (AppStorage.get('notification_version') as number) ?? 0;
    AppStorage.set('notification_version', v + 1);
  }

  /**
   *  收藏/取消收藏切换
   * 支持登录验证、本地状态更新、数据持久化
   */
  private async toggleFav(id: number) {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);
    
    // 登录验证
    if (uid === '0') {
      promptAction.showToast({ message: '请先在【我的】里登录' });
      return;
    }

    // 更新本地收藏状态
    const next = new Set(this.favIds);
    if (next.has(id)) {
      next.delete(id);
      await FavoriteStore.removeArticleSnapshot(ctx, id);
    } else {
      next.add(id);
      if (this.article) {
        await FavoriteStore.saveArticleSnapshot(ctx, this.article);
      }
    }

    this.favIds = next;
    await FavoriteStore.saveFavSet(ctx, uid, next);
    this.bumpFavVersion(); // 触发全局收藏状态更新
  }

  /**
   *  时间格式化工具
   * 将时间戳转换为易读的日期时间格式
   */
  private formatTime(ts: number): string {
    const d = new Date(ts);
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  /**
   *  更新评论点赞状态
   * 采用函数式更新，精确更新特定评论的点赞状态
   */
  private updateCommentLikeState(commentId: string, state: LikeState) {
    const update = (items: CommentView[]): CommentView[] => {
      return items.map(item => {
        if (item.id === commentId) {
          return this.mergeCommentView(item, { liked: state.liked, likeCount: state.count });
        }
        if (item.replies.length === 0) {
          return item;
        }
        const nextReplies = update(item.replies);
        return this.mergeCommentView(item, { replies: nextReplies });
      });
    };
    this.comments = update(this.comments);
  }

  /**
   *  推送通知
   * 当用户收到回复或点赞时，创建通知记录
   */
  private async pushNotification(targetUid: string, item: NotificationItem) {
    const ctx = this.hostCtx();
    await NotificationStore.add(ctx, targetUid, item);
    this.bumpNotificationVersion();
  }

  /**
   *  提交评论
   * 支持普通评论和回复评论两种模式
   */
  private async submitComment() {
    const article = this.article;
    if (!article) {
      promptAction.showToast({ message: '文章未加载' });
      return;
    }

    // 评论内容验证
    const content = this.newComment.trim();
    if (content.length === 0) {
      promptAction.showToast({ message: '请输入评论内容' });
      return;
    }

    const ctx = this.hostCtx();
    const currentUser = await UserStore.currentUser(ctx);
    const sessionUid = await FavoriteStore.getUid(ctx);
    const uid = sessionUid;
    
    // 登录验证
    if (!uid || uid === '0') {
      promptAction.showToast({ message: '请先登录后再评论' });
      return;
    }

    // 构建评论对象
    const nickname = currentUser?.nickname ?? currentUser?.username ?? '匿名用户';
    const replyTarget = this.replyTarget;
    const comment: Comment = {
      id: `${article.id}-${Date.now()}`, // 生成唯一ID
      articleId: article.id,
      userId: uid,
      nickname,
      content,
      createdAt: Date.now(),
      parentId: replyTarget?.id,
      replyTo: replyTarget?.nickname
    };

    // 保存评论并刷新状态
    await InteractionStore.addComment(ctx, article.id, comment);
    await this.refreshInteractions();
    await UserActionStore.addCommented(ctx, uid, article);
    this.bumpCommentedVersion();
    
    // 重置评论输入状态
    this.newComment = '';
    this.replyTarget = null;
    promptAction.showToast({ message: '评论成功' });

    // 如果是回复评论，推送通知给被回复用户
    if (replyTarget && replyTarget.userId !== uid) {
      await this.pushNotification(replyTarget.userId, {
        id: `${comment.id}-reply-${uid}`,
        type: 'comment_reply',
        articleId: article.id,
        articleTitle: article.title,
        commentId: replyTarget.id,
        fromUserId: uid,
        fromNickname: nickname,
        content: comment.content,
        createdAt: Date.now(),
        read: false
      });
    }
  }

  /**
   *  文章点赞/取消点赞
   */
  private async toggleLikeStatus() {
    const article = this.article;
    if (!article) {
      promptAction.showToast({ message: '文章未加载' });
      return;
    }

    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);
    this.uid = uid;
    
    if (uid === '0') {
      promptAction.showToast({ message: '请先在【我的】里登录' });
      return;
    }

    const state = await InteractionStore.toggleLike(ctx, article.id, uid);
    this.liked = state.liked;
    this.likeCount = state.count;
    await UserActionStore.updateLiked(ctx, uid, article, state.liked);
    this.bumpLikedVersion();
  }

  /**
   *  评论点赞/取消点赞
   */
  private async toggleCommentLike(comment: CommentView) {
    const article = this.article;
    if (!article) {
      promptAction.showToast({ message: '文章未加载' });
      return;
    }

    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);
    if (!uid || uid === '0') {
      promptAction.showToast({ message: '请先在【我的】里登录' });
      return;
    }

    const state = await InteractionStore.toggleCommentLike(ctx, article.id, comment.id, uid);
    this.updateCommentLikeState(comment.id, state);

    // 如果是点赞操作且不是给自己的评论，推送通知
    if (state.liked && comment.userId !== uid) {
      const currentUser = await UserStore.currentUser(ctx);
      const nickname = currentUser?.nickname ?? currentUser?.username ?? uid;
      await this.pushNotification(comment.userId, {
        id: `${comment.id}-like-${uid}`,
        type: 'comment_like',
        articleId: article.id,
        articleTitle: article.title,
        commentId: comment.id,
        fromUserId: uid,
        fromNickname: nickname,
        content: comment.content,
        createdAt: Date.now(),
        read: false
      });
    }
  }

  /**
   *  分享文章
   * 将文章标题和链接复制到系统剪贴板
   */
  private async shareArticle() {
    if (!this.article) {
      promptAction.showToast({ message: '文章未加载' });
      return;
    }

    const link = this.article.link?.trim();
    const content = link && link.length > 0
      ? `${this.article.title}\n${link}`
      : this.article.title;
    
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = pasteboard.createData('text/plain', content);
      await systemPasteboard.setData(pasteData);
      promptAction.showToast({ message: '已复制分享内容，快去发送给朋友吧' });
    } catch (e) {
      promptAction.showToast({ message: (e as Error)?.message ?? '分享失败' });
    }
  }

  /**
   *  滚动到评论区域
   * 使用Scroller实现平滑滚动动画
   */
  private scrollToComments() {
    if (this.commentSectionTop <= 0) {
      return;
    }
    this.detailScroller.scrollTo({
      xOffset: 0,
      yOffset: this.commentSectionTop,
      animation: { duration: 260, curve: Curve.EaseOut }
    });
  }

  /**
   *  AI功能：总结/锐评
   * 调用智谱AI服务生成文章分析
   */
  private async runAi(mode: AiMode) {
    if (!this.article) {
      promptAction.showToast({ message: '文章未加载' });
      return;
    }

    this.aiMode = mode;
    this.aiLoading = true;
    this.aiText = '';

    try {
      const content = await this.resolveAiContent();
      const text = await callZhipu(this.article.title, content, mode);
      this.aiText = text;
    } catch (e) {
      const msg = (e as Error)?.message ?? 'AI调用失败';
      promptAction.showToast({ message: msg });
    } finally {
      this.aiLoading = false;
    }
  }

  /**
   *  AI功能：答疑
   * 基于文章内容回答用户提问
   */
  private async runAiQuestion() {
    if (!this.article) {
      promptAction.showToast({ message: '文章未加载' });
      return;
    }

    const question = this.aiQuestion.trim();
    if (question.length === 0) {
      promptAction.showToast({ message: '请输入问题再提问' });
      return;
    }

    this.aiQaLoading = true;
    this.aiAnswer = '';

    try {
      const content = await this.resolveAiContent();
      const text = await callZhipu(this.article.title, content, 'qa', question);
      this.aiAnswer = text;
    } catch (e) {
      const msg = (e as Error)?.message ?? 'AI调用失败';
      promptAction.showToast({ message: msg });
    } finally {
      this.aiQaLoading = false;
    }
  }

  /**
   *  评论渲染构建器
   * 采用递归方式渲染嵌套评论树
   * 
   * @param item 评论数据
   * @param level 嵌套层级（0为根评论）
   */
  @Builder
  private renderComment(item: CommentView, level: number) {
    Column({ space: 6 }) {
      // 评论主体
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(item.nickname || '匿名用户').fontSize(this.commentNameSize(level)).fontWeight(FontWeight.Medium)
          Text(this.formatTime(item.createdAt)).fontSize(this.commentTimeSize(level)).opacity(0.6)
        }
        
        // 回复提示
        if (item.replyTo) {
          Text(`回复 ${item.replyTo}：`).fontSize(this.commentReplySize(level)).opacity(0.6)
        }
        
        // 评论内容
        Text(item.content).fontSize(this.commentContentSize(level)).lineHeight(this.commentLineHeight(level))
        
        // 操作按钮
        Row({ space: 12 }) {
          Text('回复').fontSize(this.commentReplySize(level)).opacity(0.7)
            .onClick(() => { this.replyTarget = item; })
          
          Row({ space: 4 }) {
            Text(item.liked ? '❤️' : '🤍').fontSize(this.commentLikeSize(level))
            Text(`${item.likeCount}`).fontSize(this.commentLikeCountSize(level)).opacity(0.7)
          }
          .onClick(async () => await this.toggleCommentLike(item))
        }
      }
      .padding(this.commentPaddingSize(level))
      .width('100%')
      .borderRadius(10)
      .backgroundColor(this.commentBackgroundColor(level))
      .alignItems(HorizontalAlign.Start)

      // 递归渲染子评论
      if (item.replies.length > 0) {
        Column({ space: 6 }) {
          ForEach(item.replies, (child: CommentView) => {
            this.renderComment(child, level + 1)
          })
        }
        .padding({ left: 12, top: 4, bottom: 4 })
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   *  评论样式配置方法
   * 根据嵌套层级动态调整样式，实现视觉层次感
   */
  
  private commentNameSize(level: number): number {
    return level === 0 ? 14 : 13;
  }

  private commentTimeSize(level: number): number {
    return level === 0 ? 12 : 11;
  }

  private commentReplySize(level: number): number {
    return level === 0 ? 12 : 11;
  }

  private commentContentSize(level: number): number {
    return level === 0 ? 14 : 13;
  }

  private commentLineHeight(level: number): number {
    return level === 0 ? 20 : 18;
  }

  private commentLikeSize(level: number): number {
    return level === 0 ? 14 : 12;
  }

  private commentLikeCountSize(level: number): number {
    return level === 0 ? 12 : 11;
  }

  private commentPaddingSize(level: number): number {
    return level === 0 ? 10 : 8;
  }

  private commentBackgroundColor(level: number): string {
    return level === 0 ? '#FAFAFA' : '#FFFFFF';
  }

  /**
   *  页面UI构建
   * 采用分层布局：顶部导航 + 内容区域 + 底部操作栏
   */
  build() {
    Column() {
      // 🎯 顶部导航栏
      Row() {
        Text('←')
          .fontSize(22)
          .margin({ left: 16 })
          .onClick(() => router.back());

        Text('正文')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
          .layoutWeight(1);

        // 右侧操作按钮（分享、收藏）
        if (this.article) {
          Row({ space: 12 }) {
            Text('🔗')
              .fontSize(20)
              .onClick(async () => await this.shareArticle())

            Text(this.favIds.has(this.article.id) ? '★' : '☆')
              .fontSize(22)
              .onClick(async () => await this.toggleFav(this.article!.id));
          }
          .margin({ right: 16 })
        }
      }
      .height(52)
      .alignItems(VerticalAlign.Center)

      //  内容区域
      if (!this.article) {
        Text('文章不存在或参数错误').margin(16).opacity(0.7)
      } else {
        Scroll(this.detailScroller) {
          Column({ space: 10 }) {
            // 文章基本信息
            Text(this.article.title).fontSize(20).fontWeight(FontWeight.Bold)
            Text(`作者：${this.article.author}`).fontSize(12).opacity(0.6)

            Text(`原文链接：${this.article.link && this.article.link.trim().length > 0 ? this.article.link : '暂无链接'}`)
              .fontSize(12)
              .opacity(0.65)
              .lineHeight(18)
              .onClick(() => {
                if (this.article?.link && this.article.link.trim().length > 0) {
                  promptAction.showToast({ message: '请复制链接到浏览器打开：' + this.article!.link });
                }
              })

            Divider().margin({ top: 8, bottom: 8 })

            //  AI功能区域
            Row({ space: 10 }) {
              Button('AI总结', { type: ButtonType.Capsule })
                .onClick(() => {
                  this.runAi('summary');
                })

              Button('AI锐评', { type: ButtonType.Capsule })
                .onClick(() => {
                  this.runAi('review');
                })
            }
            .margin({ top: 4, bottom: 8 })

            // AI结果显示区域
            Column() {
              if (this.aiLoading) {
                Column({ space: 8 }) {
                  LoadingProgress()
                  Text('AI生成中…').opacity(0.7)
                }
                .padding(12)
                .width('100%')
                .alignItems(HorizontalAlign.Center)
              } else if (this.aiText) {
                Text(this.aiMode === 'summary' ? 'AI总结' : 'AI锐评')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .margin({ bottom: 8 })

                Text(this.aiText)
                  .fontSize(14)
                  .lineHeight(20)
                  .opacity(0.85)
              } else {
                Text('点击上方按钮生成 AI 总结/锐评')
                  .opacity(0.6)
                  .padding(12)
              }
            }
            .padding(12)
            .borderRadius(12)
            .backgroundColor('#F5F5F5')

            // AI答疑区域
            Column({ space: 10 }) {
              Text('AI答疑').fontSize(16).fontWeight(FontWeight.Bold)

              TextInput({ text: this.aiQuestion, placeholder: '输入问题，AI基于本文回答' })
                .onChange((v: string) => { this.aiQuestion = v; })
                .height(42)
                .padding({ left: 14, right: 14 })
                .borderRadius(22)
                .backgroundColor('#FFFFFF')

              Button('提问', { type: ButtonType.Capsule })
                .onClick(async () => await this.runAiQuestion())

              if (this.aiQaLoading) {
                Stack({ alignContent: Alignment.Center }) {
                  LoadingProgress()
                  Text('AI思考中…')
                    .opacity(0.7)
                    .fontSize(14)
                    .textAlign(TextAlign.Center)
                }
                .width('100%')
                .height(160)
              } else if (this.aiAnswer) {
                Text(this.aiAnswer)
                  .fontSize(14)
                  .lineHeight(20)
                  .opacity(0.85)
              } else {
                Text('请输入问题后点击提问').opacity(0.6)
              }
            }
            .padding(12)
            .borderRadius(12)
            .backgroundColor('#F5F5F5')

            //  文章内容展示
            if (this.article.link && this.article.link.trim().length > 0) {
              // 优先使用WebView展示原文链接
              Web({ src: this.article.link, controller: this.webController })
                .width('100%')
                .height(520)
                .margin({ top: 10 })
            } else {
              // 无链接时显示本地内容
              Text(this.article.content)
                .fontSize(15)
                .lineHeight(22)
                .width('100%')
                .margin({ top: 10 })
            }

            Divider().margin({ top: 12, bottom: 4 })

            //  评论区域
            Column({ space: 10 }) {
              Text('最新评论').fontSize(16).fontWeight(FontWeight.Medium)
              if (this.comments.length === 0) {
                Text('暂时还没有评论，快来抢沙发～').opacity(0.6)
              } else {
                ForEach(this.comments, (c: CommentView) => {
                  this.renderComment(c, 0)
                })
              }
            }
            .padding(12)
            .borderRadius(12)
            .backgroundColor('#F5F5F5')
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .onAreaChange((_, area) => {
              // 监听评论区域位置变化，用于滚动定位
              const positionY = area.position.y;
              let resolvedY = 0;
              if (typeof positionY === 'number') {
                resolvedY = positionY;
              } else if (typeof positionY === 'string') {
                resolvedY = Number.parseFloat(positionY);
              } else {
                resolvedY = this.hostCtx().resourceManager.getNumber(positionY as resourceManager.Resource);
              }
              this.commentSectionTop = resolvedY;
            })
          }
          .padding({ top: 16, left: 16, right: 16, bottom: 88 })
          .width('100%')
        }
        .layoutWeight(1)
      }

      //  底部固定操作栏
      Column({ space: 6 }) {
        // 回复提示
        if (this.replyTarget) {
          Row({ space: 8 }) {
            Text(`回复 ${this.replyTarget.nickname || '匿名用户'}`)
              .fontSize(12)
              .opacity(0.7)
            Text('取消')
              .fontSize(12)
              .fontColor('#4C6FFF')
              .onClick(() => {this.replyTarget = null;})
          }
        }

        // 评论输入和操作区域
        Row() {
          TextInput({ text: this.newComment, placeholder: this.replyTarget ? `回复 ${this.replyTarget.nickname}` : '说点什么…' })
            .onChange((v: string) => { this.newComment = v; })
            .layoutWeight(1)
            .height(42)
            .padding({ left: 14, right: 14 })
            .borderRadius(22)
            .backgroundColor('#FFFFFF')

          Button('发送', { type: ButtonType.Capsule })
            .height(36)
            .margin({ left: 8, right: 4 })
            .onClick(async () => await this.submitComment())

          // 点赞和评论计数
          Row({ space: 16 }) {
            Row({ space: 4 }) {
              Text(this.liked ? '❤️' : '🤍').fontSize(22)
              Text(`${this.likeCount}`).fontSize(14).opacity(0.8)
            }
            .onClick(async () => await this.toggleLikeStatus())

            Row({ space: 4 }) {
              Text('💬').fontSize(22)
              Text(`${this.commentCount}`).fontSize(14).opacity(0.8)
            }
            .onClick(() => this.scrollToComments())
          }
          .margin({ left: 8 })
            .alignItems(VerticalAlign.Center)
        }
      }
      .padding(12)
      .borderRadius(26)
      .backgroundColor('#F0F1F5')
      .alignItems(HorizontalAlign.Center)
      .margin({ left: 16, right: 16, bottom: 12 })
    }
    .width('100%')
    .height('100%')
  }
}