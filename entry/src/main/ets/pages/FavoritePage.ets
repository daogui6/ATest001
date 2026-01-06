import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

import type { Article } from '../model/Article';
import { FavoriteStore } from '../store/FavoriteStore';
import { ArticleStore } from '../store/ArticleStore';
import { fetchArticlesByIds } from '../service/WanService';
import type { ThemePalette } from '../store/ThemeStore';
import { DARK_MODE_STORAGE_KEY, ThemeStore } from '../store/ThemeStore';

// ✅ 确保 key 存在（避免首次 get 为 undefined）
AppStorage.setOrCreate('fav_version', 0);
AppStorage.setOrCreate('session_version', 0);

@Component
export struct FavoritePage {
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  // ✅ 监听全局变化：收藏变化 / 登录变化
  @StorageLink('fav_version')
  @Watch('onFavVersionChange')
  favVersion: number = 0;
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;
  @State uid: string = '0';
  @State favIds: Set<number> = new Set<number>();
  @State favArticles: Article[] = [];
  @StorageLink(DARK_MODE_STORAGE_KEY)
  isDarkMode: boolean = false;

  private onFavVersionChange() {
    this.refresh();
  }

  private onSessionVersionChange() {
    this.refresh();
  }

  private palette(): ThemePalette {
    return ThemeStore.palette(this.isDarkMode);
  }

  private async refresh() {
    const ctx = this.hostCtx();
    this.uid = await FavoriteStore.getUid(ctx);

    if (this.uid === '0') {
      this.favIds = new Set<number>();
      this.favArticles = [];
      return;
    }

    const set = await FavoriteStore.loadFavSet(ctx, this.uid);
    this.favIds = set;
    try {
      const remote = await fetchArticlesByIds(set);
      const remoteIds = new Set(remote.map(item => item.id));
      const cached = await FavoriteStore.pickCachedArticles(ctx, set);
      const merged = [...remote];
      cached.forEach(item => {
        if (!remoteIds.has(item.id)) {
          merged.push(item);
        }
      });
      this.favArticles = merged;
    } catch (e) {
      promptAction.showToast({ message: (e as Error)?.message ?? '收藏数据加载失败' });
      this.favArticles = await FavoriteStore.pickCachedArticles(ctx, set);
    }
  }

  // ✅ 安全跳转（解决 ArkTSCheck：可能抛异常）
  private async openDetail(article: Article) {
    try {
      ArticleStore.setArticles(this.favArticles);
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id: article.id, article: article }
      });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  private async removeFav(id: number) {
    if (this.uid === '0') {
      promptAction.showToast({ message: '请先登录' });
      return;
    }
    const ctx = this.hostCtx();
    const next = new Set(this.favIds);
    next.delete(id);
    this.favIds = next;
    await FavoriteStore.saveFavSet(ctx, this.uid, next);
    this.favArticles = this.favArticles.filter(item => item.id !== id);
    await FavoriteStore.removeArticleSnapshot(ctx, id);
    // ✅ 同样广播一次（防止其他页面需要刷新）
    AppStorage.setOrCreate('fav_version', 0);
    const v = (AppStorage.get('fav_version') as number) ?? 0;
    AppStorage.set('fav_version', v + 1);
  }

  build() {
    const colors = this.palette();
    Column() {
      Text('收藏').fontSize(22).fontWeight(FontWeight.Bold).fontColor(colors.primaryText).margin({ top: 16, left: 16, bottom: 12 })

      if (this.uid === '0') {
        Text('请先去【我的】页登录').margin(16).opacity(0.7).fontColor(colors.secondaryText)
      } else if (this.favArticles.length === 0) {
        Text('暂无收藏').margin(16).opacity(0.7).fontColor(colors.secondaryText)
      } else {
        List() {
          ForEach(this.favArticles, (item: Article) => {
            ListItem() {
              Row() {
                Column({ space: 6 }) {
                  Text(item.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(colors.primaryText)
                  Text(item.desc).fontSize(13).opacity(0.7).fontColor(colors.secondaryText).maxLines(2)
                }.layoutWeight(1)

                // ✅ 取消收藏（用 gesture 更稳，避免触发卡片跳转）
                Text('❤️')
                  .fontSize(22)
                  .margin({ left: 10 })
                  .gesture(
                    TapGesture().onAction(async () => {
                      await this.removeFav(item.id);
                    })
                  )
              }
              .padding(12)
              .margin({ left: 16, right: 16, bottom: 12 })
              .borderRadius(12)
              .backgroundColor(colors.card)
              // ✅ 点卡片进正文
              .onClick(async () => {
                await this.openDetail(item);
              })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(colors.background)
    .onAppear(() => {
      this.refresh();
    })
  }
}
