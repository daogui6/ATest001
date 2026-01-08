/**
 * 点赞记录页面 - 用户点赞历史管理
 * 
 * 功能概述：
 * - 展示用户点赞过的文章列表
 * - 实时同步点赞状态变化
 * - 提供文章详情跳转功能
 * 
 * 组件结构：
 * - Entry标记为独立页面入口
 * - Component封装点赞记录逻辑
 * - 全局状态同步点赞版本
 * 
 * 状态管理：
 * - 点赞文章ID集合管理
 * - 文章数据列表状态
 * - 动画效果控制状态
 * - 用户登录状态验证
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

// 数据模型和存储导入
import type { Article } from '../model/Article';
import { ArticleStore } from '../store/ArticleStore';
import { UserActionStore } from '../store/UserActionStore';
import { fetchArticlesByIds } from '../service/WanService';

// 全局状态初始化
AppStorage.setOrCreate('liked_version', 0);
AppStorage.setOrCreate('session_version', 0);

/**
 * 点赞记录页面主组件
 */
@Entry
@Component
export struct LikedPage {
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  // 全局状态同步
  @StorageLink('liked_version')
  @Watch('onLikedVersionChange')
  likedVersion: number = 0;
  
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;

  // 组件内部状态
  @State uid: string = '0';
  @State likedIds: Set<number> = new Set<number>();
  @State likedArticles: Article[] = [];
  
  // 动画状态
  @State headerOpacity: number = 0;
  @State headerOffset: number = 12;
  @State listOpacity: number = 0;
  @State listOffset: number = 16;

  /**
   * 点赞版本变化监听
   */
  private onLikedVersionChange() {
    this.refresh();
  }

  /**
   * 会话版本变化监听
   */
  private onSessionVersionChange() {
    this.refresh();
  }

  /**
   * 刷新点赞记录数据
   * 采用远程API优先 + 本地缓存兜底的策略
   */
  private async refresh() {
    const ctx = this.hostCtx();
    this.uid = await UserActionStore.getUid(ctx);
    
    // 未登录用户处理
    if (this.uid === '0') {
      this.likedIds = new Set<number>();
      this.likedArticles = [];
      return;
    }

    // 加载点赞文章ID集合
    const set = await UserActionStore.loadLikedSet(ctx, this.uid);
    this.likedIds = set;
    
    try {
      // 优先从远程API获取最新数据
      const remote = await fetchArticlesByIds(set);
      const remoteIds = new Set(remote.map(item => item.id));
      
      // 使用本地缓存作为兜底
      const cached = await UserActionStore.pickCachedLikedArticles(ctx, set);
      
      // 合并数据避免重复
      const merged = [...remote];
      cached.forEach(item => {
        if (!remoteIds.has(item.id)) {
          merged.push(item);
        }
      });
      
      this.likedArticles = merged;
    } catch (e) {
      // 远程API失败时的降级处理
      promptAction.showToast({ message: (e as Error)?.message ?? '点赞数据加载失败' });
      this.likedArticles = await UserActionStore.pickCachedLikedArticles(ctx, set);
    }
  }

  /**
   * 安全跳转到文章详情页
   */
  private async openDetail(article: Article) {
    try {
      ArticleStore.setArticles(this.likedArticles);
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id: article.id, article: article }
      });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  /**
   * UI构建方法
   * 创建点赞记录列表界面
   */
  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Text('←')
          .fontSize(20)
          .margin({ left: 16 })
          .onClick(() => router.back());

        Text('点赞过')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ right: 36 })
      }
      .alignItems(VerticalAlign.Center)
      .padding({ top: 16, right: 16, bottom: 12 })
      .opacity(this.headerOpacity)
      .translate({ x: 0, y: this.headerOffset })

      // 主体内容区域
      if (this.uid === '0') {
        // 未登录状态提示
        Text('请先去【我的】页登录').margin(16).opacity(0.7)
          .opacity(this.listOpacity)
          .translate({ x: 0, y: this.listOffset })
      } else if (this.likedArticles.length === 0) {
        // 空状态提示
        Text('暂无点赞记录').margin(16).opacity(0.7)
          .opacity(this.listOpacity)
          .translate({ x: 0, y: this.listOffset })
      } else {
        // 点赞文章列表
        List() {
          ForEach(this.likedArticles, (item: Article) => {
            ListItem() {
              Column({ space: 6 }) {
                Text(item.title)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .maxLines(2)
                Text(item.desc).fontSize(13).opacity(0.7).maxLines(2)
                Text(`作者：${item.author}`).fontSize(12).opacity(0.6)
              }
              .width('100%')
              .height(120)
              .padding(12)
              .margin({ bottom: 12 })
              .borderRadius(16)
              .backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#E9EEF5' })
              .justifyContent(FlexAlign.SpaceBetween)
              .onClick(async () => await this.openDetail(item))
            }
          })
        }
        .padding({ left: 16, right: 16 })
        .width('100%')
        .layoutWeight(1)
        .opacity(this.listOpacity)
        .translate({ x: 0, y: this.listOffset })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F7FB')
    .onAppear(() => {
      // 页面显示时的初始化
      this.refresh();
      
      // 分层动画效果
      animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.headerOpacity = 1;
        this.headerOffset = 0;
      });
      animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
        this.listOpacity = 1;
        this.listOffset = 0;
      });
    })
  }
}