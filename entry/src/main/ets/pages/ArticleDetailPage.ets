import router from '@ohos.router';
import type common from '@ohos.app.ability.common';
import type resourceManager from '@ohos.resourceManager';
import pasteboard from '@ohos.pasteboard';
import promptAction from '@ohos.promptAction';
import webview from '@ohos.web.webview';

import type { Article } from '../model/Article';
import { FavoriteStore } from '../store/FavoriteStore';
import { callZhipu, type AiMode } from '../service/ZhipuAI';
import { HistoryStore } from '../store/HistoryStore';
import { ArticleStore } from '../store/ArticleStore';
import { fetchArticleById } from '../service/WanService';
import type { Comment } from '../model/Comment';
import { InteractionStore, type LikeState } from '../store/InteractionStore';
import { UserActionStore } from '../store/UserActionStore';
import { UserStore } from '../store/UserStore';
import { NotificationStore } from '../store/NotificationStore';
import type { NotificationItem } from '../model/Notification';

interface DetailParams {
  id?: number | string;
  article?: Article;
}

// 确保全局 key 存在
AppStorage.setOrCreate('fav_version', 0);
AppStorage.setOrCreate('session_version', 0);
AppStorage.setOrCreate('history_version', 0);
AppStorage.setOrCreate('liked_version', 0);
AppStorage.setOrCreate('commented_version', 0);
AppStorage.setOrCreate('notification_version', 0);

interface CommentView extends Comment {
  likeCount: number;
  liked: boolean;
  replies: CommentView[];
}

interface CommentViewOverrides {
  liked?: boolean;
  likeCount?: number;
  replies?: CommentView[];
}

@Entry
@Component
struct ArticleDetailPage {
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  @State article: Article | null = null;
  @State uid: string = '0';
  @State favIds: Set<number> = new Set<number>();
  private webController: webview.WebviewController = new webview.WebviewController();
  // ✅ AI 状态
  @State aiLoading: boolean = false;
  @State aiText: string = '';
  @State aiMode: AiMode = 'summary';
  @State aiQuestion: string = '';
  @State aiAnswer: string = '';
  @State aiQaLoading: boolean = false;
  // 监听收藏/登录变化，保证红心同步
  @StorageLink('fav_version')
  @Watch('onFavVersionChange')
  favVersion: number = 0;
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;
  @State comments: CommentView[] = [];
  @State commentCount: number = 0;
  @State newComment: string = '';
  @State replyTarget: CommentView | null = null;
  @State likeCount: number = 0;
  @State liked: boolean = false;
  @State commentSectionTop: number = 0;
  private detailScroller: Scroller = new Scroller();

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

  private onFavVersionChange() {
    this.refreshFav();
    this.refreshInteractions();
  }

  private onSessionVersionChange() {
    this.refreshFav();
    this.refreshInteractions();
  }

  async aboutToAppear() {
    // 1) 读路由参数 id
    const params = router.getParams() as DetailParams;
    const paramArticle = params?.article as Article | undefined;
    const rawId = params?.id;
    const id = typeof rawId === 'number' ? rawId : Number(rawId);

    if ((!id || Number.isNaN(id)) && !paramArticle) {
      this.article = null;
      promptAction.showToast({ message: '文章参数缺失，无法打开' });
      await this.refreshFav();
      await this.refreshInteractions();
      return;
    }

    // 2) 查文章（参数 > 缓存 > 收藏缓存 > 本地 > 历史）
    const resolvedById = await this.resolveArticleById(id);
    this.article = paramArticle
      ?? ArticleStore.getArticleById(id)
      ?? resolvedById;

    // 收藏页传参可能缺少 link，这里用收藏/历史缓存补全
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

    if (this.article) {
      ArticleStore.setArticle(this.article);
    }

    if (this.article) {
      await HistoryStore.addVisit(this.hostCtx(), this.article);
      this.bumpHistoryVersion();
    } else {
      promptAction.showToast({ message: '文章不存在或已被移除' });
    }

    // 3) 刷新收藏状态 + 点赞/评论数据
    await this.refreshFav();
    await this.refreshInteractions();
  }

  private async resolveArticleById(id: number): Promise<Article | null> {
    const ctx = this.hostCtx();

    // 先查收藏缓存（最完整的数据来源）
    const favList = await FavoriteStore.pickCachedArticles(ctx, new Set([id]));
    if (favList.length > 0) {
      return favList[0];
    }

    // 若缓存缺失，则从 WanAndroid 拉取最新数据
    try {
      const remote = await fetchArticleById(id);
      if (remote) {
        return remote;
      }
    } catch (e) {
      promptAction.showToast({ message: (e as Error)?.message ?? '远端文章加载失败' });
    }

    // 最后查历史记录
    const historyList = await HistoryStore.loadHistory(ctx);
    return historyList.find(item => item.id === id) ?? null;
  }

  private async refreshFav() {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);
    this.uid = uid;
    if (uid === '0') {
      this.favIds = new Set<number>();
      return;
    }
    this.favIds = await FavoriteStore.loadFavSet(ctx, uid);
  }

  private async refreshInteractions() {
    if (!this.article) {
      this.comments = [];
      this.commentCount = 0;
      this.likeCount = 0;
      this.liked = false;
      return;
    }

    const ctx = this.hostCtx();
    const rawComments = await InteractionStore.loadComments(ctx, this.article.id);
    this.commentCount = rawComments.length;
    const likeStates = new Map<string, LikeState>();
    await Promise.all(
      rawComments.map(async (comment: Comment) => {
        const state = await InteractionStore.loadCommentLikeState(ctx, this.article!.id, comment.id, this.uid);
        likeStates.set(comment.id, state);
      })
    );

    const viewMap = new Map<string, CommentView>();
    const defaultLikeState: LikeState = { liked: false, count: 0 };
    rawComments.forEach((comment: Comment) => {
      const state = likeStates.get(comment.id) ?? defaultLikeState;
      viewMap.set(comment.id, this.buildCommentView(comment, state));
    });

    const roots: CommentView[] = [];
    rawComments.forEach((comment: Comment) => {
      const view = viewMap.get(comment.id);
      if (!view) {
        return;
      }
      if (view.parentId && viewMap.has(view.parentId)) {
        viewMap.get(view.parentId)!.replies.push(view);
      } else {
        roots.push(view);
      }
    });
    this.comments = roots;
    const likeState = await InteractionStore.loadLikeState(ctx, this.article.id, this.uid);
    this.likeCount = likeState.count;
    this.liked = likeState.liked;
  }

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

  private async toggleFav(id: number) {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);
    if (uid === '0') {
      promptAction.showToast({ message: '请先在【我的】里登录' });
      return;
    }

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
    this.bumpFavVersion();
  }

  private formatTime(ts: number): string {
    const d = new Date(ts);
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

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

  private async pushNotification(targetUid: string, item: NotificationItem) {
    const ctx = this.hostCtx();
    await NotificationStore.add(ctx, targetUid, item);
    this.bumpNotificationVersion();
  }

  private async submitComment() {
    const article = this.article;
    if (!article) {
      promptAction.showToast({ message: '文章未加载' });
      return;
    }

    const content = this.newComment.trim();
    if (content.length === 0) {
      promptAction.showToast({ message: '请输入评论内容' });
      return;
    }

    const ctx = this.hostCtx();
    const currentUser = await UserStore.currentUser(ctx);
    const sessionUid = await FavoriteStore.getUid(ctx);
    const uid = sessionUid;
    if (!uid || uid === '0') {
      promptAction.showToast({ message: '请先登录后再评论' });
      return;
    }

    const nickname = currentUser?.nickname ?? currentUser?.username ?? '匿名用户';
    const replyTarget = this.replyTarget;
    const comment: Comment = {
      id: `${article.id}-${Date.now()}`,
      articleId: article.id,
      userId: uid,
      nickname,
      content,
      createdAt: Date.now(),
      parentId: replyTarget?.id,
      replyTo: replyTarget?.nickname
    };

    await InteractionStore.addComment(ctx, article.id, comment);
    await this.refreshInteractions();
    await UserActionStore.addCommented(ctx, uid, article);
    this.bumpCommentedVersion();
    this.newComment = '';
    this.replyTarget = null;
    promptAction.showToast({ message: '评论成功' });

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

  // ✅ AI 调用（总结/锐评）
  private async runAi(mode: AiMode) {
    if (!this.article) {
      promptAction.showToast({ message: '文章未加载' });
      return;
    }

    this.aiMode = mode;
    this.aiLoading = true;
    this.aiText = '';

    try {
      const text = await callZhipu(this.article.title, this.article.content, mode);
      this.aiText = text;
    } catch (e) {
      const msg = (e as Error)?.message ?? 'AI调用失败';
      promptAction.showToast({ message: msg });
    } finally {
      this.aiLoading = false;
    }
  }

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
      const text = await callZhipu(this.article.title, this.article.content, 'qa', question);
      this.aiAnswer = text;
    } catch (e) {
      const msg = (e as Error)?.message ?? 'AI调用失败';
      promptAction.showToast({ message: msg });
    } finally {
      this.aiQaLoading = false;
    }
  }

  @Builder
  private renderComment(item: CommentView, level: number) {
    Column({ space: 6 }) {
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(item.nickname || '匿名用户').fontSize(this.commentNameSize(level)).fontWeight(FontWeight.Medium)
          Text(this.formatTime(item.createdAt)).fontSize(this.commentTimeSize(level)).opacity(0.6)
        }
        if (item.replyTo) {
          Text(`回复 ${item.replyTo}：`).fontSize(this.commentReplySize(level)).opacity(0.6)
        }
        Text(item.content).fontSize(this.commentContentSize(level)).lineHeight(this.commentLineHeight(level))
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

  build() {
    Column() {
      // 顶部栏（左返回 + 标题 + 右收藏）
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

      // 内容区（可滚动）
      if (!this.article) {
        Text('文章不存在或参数错误').margin(16).opacity(0.7)
      } else {
        Scroll(this.detailScroller) {
          Column({ space: 10 }) {
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

            // ✅ AI 按钮区（两个按钮）
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

            // ✅ AI 展示区
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

            // ✅ AI 答疑
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
                Row({ space: 8 }) {
                  LoadingProgress()
                  Text('AI思考中…').opacity(0.7)
                }
                .alignItems(VerticalAlign.Center)
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

            // 正文（优先展示原网页）
            if (this.article.link && this.article.link.trim().length > 0) {
              Web({ src: this.article.link, controller: this.webController })
                .width('100%')
                .height(520)
                .margin({ top: 10 })
            } else {
              Text(this.article.content)
                .fontSize(15)
                .lineHeight(22)
                .width('100%')
                .margin({ top: 10 })
            }

            Divider().margin({ top: 12, bottom: 4 })

            // 评论列表
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
      // 底部固定评论/点赞栏
      Column({ space: 6 }) {
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
