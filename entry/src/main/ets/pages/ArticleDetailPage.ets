import router from '@ohos.router';
import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';

import type { Article } from '../model/Article';
import { FavoriteStore } from '../store/FavoriteStore';
import { callZhipu, type AiMode } from '../service/ZhipuAI';
import { HistoryStore } from '../store/HistoryStore';
import { ArticleStore } from '../store/ArticleStore';
import { fetchArticleById } from '../service/WanService';
import type { Comment } from '../model/Comment';
import { InteractionStore } from '../store/InteractionStore';
import { UserStore } from '../store/UserStore';

interface DetailParams {
  id?: number | string;
  article?: Article;
}

// 确保全局 key 存在
AppStorage.setOrCreate('fav_version', 0);
AppStorage.setOrCreate('session_version', 0);
AppStorage.setOrCreate('history_version', 0);

@Entry
@Component
struct ArticleDetailPage {
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  @State article: Article | null = null;
  @State uid: string = '0';
  @State favIds: Set<number> = new Set<number>();
  // ✅ AI 状态
  @State aiLoading: boolean = false;
  @State aiText: string = '';
  @State aiMode: AiMode = 'summary';
  // 监听收藏/登录变化，保证红心同步
  @StorageLink('fav_version')
  @Watch('onFavVersionChange')
  favVersion: number = 0;
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;
  @State comments: Comment[] = [];
  @State newComment: string = '';
  @State likeCount: number = 0;
  @State liked: boolean = false;

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
      this.likeCount = 0;
      this.liked = false;
      return;
    }

    const ctx = this.hostCtx();
    this.comments = await InteractionStore.loadComments(ctx, this.article.id);
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

  private async submitComment() {
    if (!this.article) {
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
    const uid = currentUser?.username ?? this.uid;
    if (!uid || uid === '0') {
      promptAction.showToast({ message: '请先登录后再评论' });
      return;
    }

    const nickname = currentUser?.nickname ?? currentUser?.username ?? '匿名用户';
    const comment: Comment = {
      id: `${this.article.id}-${Date.now()}`,
      articleId: this.article.id,
      userId: uid,
      nickname,
      content,
      createdAt: Date.now()
    };

    this.comments = await InteractionStore.addComment(ctx, this.article.id, comment);
    this.newComment = '';
    promptAction.showToast({ message: '评论成功' });
  }

  private async toggleLikeStatus() {
    if (!this.article) {
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

    const state = await InteractionStore.toggleLike(ctx, this.article.id, uid);
    this.liked = state.liked;
    this.likeCount = state.count;
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
          Text(this.favIds.has(this.article.id) ? '❤️' : '🤍')
            .fontSize(22)
            .margin({ right: 16 })
            .onClick(async () => await this.toggleFav(this.article!.id));
        }
      }
      .height(52)
      .alignItems(VerticalAlign.Center)

      // 内容区（可滚动）
      if (!this.article) {
        Text('文章不存在或参数错误').margin(16).opacity(0.7)
      } else {
        Scroll() {
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
                Row({ space: 10 }) {
                  LoadingProgress()
                  Text('AI生成中…').opacity(0.7)
                }.padding(12)
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

            // 点赞 + 评论
            Column({ space: 10 }) {
              Row({ space: 8 }) {
                Button(this.liked ? `👍 已赞（${this.likeCount}）` : `👍 点赞（${this.likeCount}）`, { type: ButtonType.Capsule })
                  .onClick(async () => await this.toggleLikeStatus())

                Text(`评论 ${this.comments.length}`)
                  .fontSize(14)
                  .opacity(0.7)
              }

              Column({ space: 8 }) {
                Text('发表评论').fontSize(16).fontWeight(FontWeight.Medium)
                TextInput({ text: this.newComment, placeholder: '写下你的想法...' })
                  .onChange((v: string) => { this.newComment = v; })
                Button('发表', { type: ButtonType.Capsule })
                  .onClick(async () => await this.submitComment())
              }
              .padding(12)
              .borderRadius(12)
              .backgroundColor('#F7F7F7')

              Column({ space: 10 }) {
                Text('最新评论').fontSize(16).fontWeight(FontWeight.Medium)
                if (this.comments.length === 0) {
                  Text('暂时还没有评论，快来抢沙发～').opacity(0.6)
                } else {
                  ForEach(this.comments, (c: Comment) => {
                    Column({ space: 4 }) {
                      Row({ space: 6 }) {
                        Text(c.nickname || '匿名用户').fontSize(14).fontWeight(FontWeight.Medium)
                        Text(this.formatTime(c.createdAt)).fontSize(12).opacity(0.6)
                      }
                      Text(c.content).fontSize(14).lineHeight(20)
                    }
                    .padding(10)
                    .borderRadius(10)
                    .backgroundColor('#FAFAFA')
                  })
                }
              }
              .padding(12)
              .borderRadius(12)
              .backgroundColor('#F5F5F5')
            }
            .padding({ top: 8, bottom: 4 })

            Divider().margin({ top: 4, bottom: 4 })

            // 正文
            Text(this.article.content)
              .fontSize(15)
              .lineHeight(22)
              .width('100%')
              .margin({ top: 10 })
          }
          .padding(16)
          .width('100%')
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
  }
}
