import router from '@ohos.router';
import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';

import type { Article } from '../model/Article';
import { FavoriteStore } from '../store/FavoriteStore';
import { callZhipu, type AiMode } from '../service/ZhipuAI';
import { HistoryStore } from '../store/HistoryStore';
import { ArticleStore } from '../store/ArticleStore';
import { fetchArticleById } from '../service/WanService';
import type { ThemePalette } from '../store/ThemeStore';
import { DARK_MODE_STORAGE_KEY, ThemeStore } from '../store/ThemeStore';

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
  @StorageLink(DARK_MODE_STORAGE_KEY)
  isDarkMode: boolean = false;
  // 监听收藏/登录变化，保证红心同步
  @StorageLink('fav_version')
  @Watch('onFavVersionChange')
  favVersion: number = 0;
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;

  private onFavVersionChange() {
    this.refreshFav();
  }

  private onSessionVersionChange() {
    this.refreshFav();
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

    // 3) 刷新收藏状态
    await this.refreshFav();
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

  private bumpFavVersion() {
    const v = (AppStorage.get('fav_version') as number) ?? 0;
    AppStorage.set('fav_version', v + 1);
  }

  private bumpHistoryVersion() {
    const v = (AppStorage.get('history_version') as number) ?? 0;
    AppStorage.set('history_version', v + 1);
  }

  private palette(): ThemePalette {
    return ThemeStore.palette(this.isDarkMode);
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
    const colors = this.palette();
    Column() {
      // 顶部栏（左返回 + 标题 + 右收藏）
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor(colors.primaryText)
          .margin({ left: 16 })
          .onClick(() => router.back());

        Text('正文')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(colors.primaryText)
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
        Text('文章不存在或参数错误').margin(16).opacity(0.7).fontColor(colors.secondaryText)
      } else {
        Scroll() {
          Column({ space: 10 }) {
            Text(this.article.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor(colors.primaryText)
            Text(`作者：${this.article.author}`).fontSize(12).opacity(0.6).fontColor(colors.secondaryText)

            Text(`原文链接：${this.article.link && this.article.link.trim().length > 0 ? this.article.link : '暂无链接'}`)
              .fontSize(12)
              .opacity(0.65)
              .fontColor(colors.secondaryText)
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
                  Text('AI生成中…').opacity(0.7).fontColor(colors.secondaryText)
                }.padding(12)
              } else if (this.aiText) {
                Text(this.aiMode === 'summary' ? 'AI总结' : 'AI锐评')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(colors.primaryText)
                  .margin({ bottom: 8 })

                Text(this.aiText)
                  .fontSize(14)
                  .lineHeight(20)
                  .opacity(0.85)
                  .fontColor(colors.primaryText)
              } else {
                Text('点击上方按钮生成 AI 总结/锐评')
                  .opacity(0.6)
                  .fontColor(colors.primaryText)
                  .padding(12)
              }
            }
            .padding(12)
            .borderRadius(12)
            .backgroundColor(colors.card)

            // 正文
            Text(this.article.content)
              .fontSize(15)
              .lineHeight(22)
              .fontColor(colors.primaryText)
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
    .backgroundColor(colors.background)
  }
}
