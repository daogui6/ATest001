import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

import type { Article } from '../model/Article';
import { ArticleStore } from '../store/ArticleStore';
import { FavoriteStore } from '../store/FavoriteStore';
import { searchArticles } from '../service/WanService';
import type { ThemePalette } from '../store/ThemeStore';
import { DARK_MODE_STORAGE_KEY, ThemeStore } from '../store/ThemeStore';

AppStorage.setOrCreate('fav_version', 0);
AppStorage.setOrCreate('session_version', 0);

@Entry
@Component
export struct SearchPage {
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  @State keyword: string = '';
  @State results: Article[] = [];
  @State loading: boolean = false;
  @State errorMsg: string = '';
  @State hasSearched: boolean = false;
  @State uid: string = '0';
  @State favIds: Set<number> = new Set<number>();

  @StorageLink('fav_version')
  @Watch('onFavVersionChange')
  favVersion: number = 0;
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;
  @StorageLink(DARK_MODE_STORAGE_KEY)
  isDarkMode: boolean = false;

  async aboutToAppear() {
    await this.refreshFav();
  }

  private onFavVersionChange() {
    this.refreshFav();
  }

  private onSessionVersionChange() {
    this.refreshFav();
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

  private get colors(): ThemePalette {
    return ThemeStore.safePalette(this.isDarkMode);
  }

  private async performSearch() {
    const kw = this.keyword.trim();
    if (kw.length === 0) {
      promptAction.showToast({ message: '请输入关键词' });
      return;
    }

    this.loading = true;
    this.errorMsg = '';
    this.hasSearched = true;

    try {
      const list = await searchArticles(kw);
      this.results = list;
    } catch (e) {
      this.errorMsg = (e as Error)?.message ?? '搜索失败';
      this.results = [];
    } finally {
      this.loading = false;
    }
  }

  private async bumpFavVersion() {
    const v = (AppStorage.get('fav_version') as number) ?? 0;
    AppStorage.set('fav_version', v + 1);
  }

  private async toggleFav(article: Article) {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);
    if (uid === '0') {
      promptAction.showToast({ message: '请先在【我的】里登录' });
      return;
    }

    const next = new Set(this.favIds);
    if (next.has(article.id)) {
      next.delete(article.id);
      await FavoriteStore.removeArticleSnapshot(ctx, article.id);
    } else {
      next.add(article.id);
      await FavoriteStore.saveArticleSnapshot(ctx, article);
    }

    this.favIds = next;
    await FavoriteStore.saveFavSet(ctx, uid, next);
    await this.bumpFavVersion();
  }

  private async openDetail(article: Article) {
    try {
      ArticleStore.setArticles(this.results);
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id: article.id, article: article }
      });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(20)
          .fontColor(this.colors.primaryText)
          .onClick(() => router.back());
        Text('搜索')
          .fontSize(22)
           .fontColor(this.colors.primaryText)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .alignItems(VerticalAlign.Center)
      .padding({ top: 16, left: 16, right: 16, bottom: 12 })

      Row({ space: 8 }) {
        TextInput({ placeholder: '输入关键词', text: this.keyword })
          .layoutWeight(1)
          .backgroundColor(this.colors.inputBackground)
          .fontColor(this.colors.primaryText)
          .onChange((v) => { this.keyword = v; })
        Button('搜索', { type: ButtonType.Capsule })
          .onClick(async () => await this.performSearch())
      }
      .padding({ left: 16, right: 16, bottom: 12 })

      if (!this.hasSearched) {
        Text('支持远端搜索 WanAndroid 文章，试试输入“鸿蒙”或“AI”。')
          .fontSize(13)
          .fontColor(this.colors.secondaryText)
          .opacity(0.7)
          .margin({ left: 16, right: 16, bottom: 8 })
      }

      if (this.loading) {
        Row({ space: 8 }) {
          LoadingProgress()
          Text('正在搜索...').opacity(0.7).fontColor(this.colors.secondaryText)
        }
        .padding(16)
      } else if (this.errorMsg) {
        Column({ space: 6 }) {
          Text('搜索失败，请稍后重试').fontSize(13).opacity(0.7).fontColor(this.colors.secondaryText)
          Text(this.errorMsg).fontSize(12).opacity(0.6).fontColor(this.colors.secondaryText)
        }
        .padding({ left: 16, right: 16, bottom: 6 })
      } else if (this.hasSearched && this.results.length === 0) {
        Text('未找到相关内容').margin({ left: 16, right: 16, bottom: 8 }).opacity(0.7).fontColor(this.colors.secondaryText)
      }

      List() {
        ForEach(this.results, (item: Article) => {
          ListItem() {
            Row() {
              Column({ space: 6 }) {
                Text(item.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.colors.primaryText)
                Text(item.desc).fontSize(13).opacity(0.7).fontColor(this.colors.secondaryText).maxLines(2)
                Text(`作者：${item.author}`).fontSize(12).opacity(0.6).fontColor(this.colors.secondaryText)
              }
              .layoutWeight(1)

              Text(this.favIds.has(item.id) ? '❤️' : '🤍')
                .fontSize(22)
                .margin({ left: 10 })
                .gesture(
                  TapGesture().onAction(async () => {
                    await this.toggleFav(item);
                  })
                )
            }
            .padding(12)
            .margin({ left: 16, right: 16, bottom: 12 })
            .borderRadius(12)
            .backgroundColor(this.colors.card)
            .onClick(async () => { await this.openDetail(item); })
          }
        }, (item: Article) => item.id.toString())
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors.background)
  }
}