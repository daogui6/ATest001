/**
 * 通知页面 - 用户消息通知管理
 * 
 * 功能概述：
 * - 展示用户收到的评论点赞和回复通知
 * - 支持标记已读和全部已读操作
 * - 提供通知关联文章的快速跳转
 * - 实时同步通知状态变化
 * 
 * 组件结构：
 * - Entry标记为独立页面入口
 * - Component封装通知管理逻辑
 * - 全局状态同步通知版本
 * 
 * 状态管理：
 * - 通知列表数据状态
 * - 用户登录状态验证
 * - 动画效果控制状态
 * - 已读状态同步管理
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

// 数据模型和存储导入
import type { NotificationItem } from '../model/Notification';
import { NotificationStore } from '../store/NotificationStore';
import { FavoriteStore } from '../store/FavoriteStore';

// 全局状态初始化
AppStorage.setOrCreate('notification_version', 0);
AppStorage.setOrCreate('session_version', 0);

/**
 * 通知页面主组件
 */
@Entry
@Component
export struct NotificationPage {
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  // 全局状态同步
  @StorageLink('notification_version')
  @Watch('onNotificationVersionChange')
  notificationVersion: number = 0;
  
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;

  // 组件内部状态
  @State uid: string = '0';
  @State notifications: NotificationItem[] = [];
  
  // 动画状态
  @State headerOpacity: number = 0;
  @State headerOffset: number = 12;
  @State listOpacity: number = 0;
  @State listOffset: number = 16;

  /**
   * 通知版本变化监听
   */
  private onNotificationVersionChange() {
    this.refresh();
  }

  /**
   * 会话版本变化监听
   */
  private onSessionVersionChange() {
    this.refresh();
  }

  /**
   * 刷新通知数据
   * 从存储中加载用户通知列表
   */
  private async refresh() {
    const ctx = this.hostCtx();
    this.uid = await FavoriteStore.getUid(ctx);
    
    // 未登录用户处理
    if (this.uid === '0') {
      this.notifications = [];
      return;
    }
    
    // 加载通知数据
    this.notifications = await NotificationStore.load(ctx, this.uid);
  }

  /**
   * 时间格式化工具
   */
  private formatTime(ts: number): string {
    const d = new Date(ts);
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  /**
   * 生成通知标题
   * 根据通知类型显示不同的标题文本
   */
  private renderTitle(item: NotificationItem): string {
    if (item.type === 'comment_like') {
      return `${item.fromNickname} 点赞了你的评论`;
    }
    return `${item.fromNickname} 回复了你的评论`;
  }

  /**
   * 内存中标记所有通知为已读
   * 用于UI状态的即时更新
   */
  private markNotificationsReadInMemory(): void {
    const updated: NotificationItem[] = [];
    for (let i = 0; i < this.notifications.length; i++) {
      const item = this.notifications[i];
      item.read = true;
      updated.push(item);
    }
    this.notifications = updated;
  }

  /**
   * 内存中标记单个通知为已读
   */
  private markNotificationReadInMemory(targetId: string): void {
    const updated: NotificationItem[] = [];
    for (let i = 0; i < this.notifications.length; i++) {
      const item = this.notifications[i];
      if (item.id === targetId) {
        item.read = true;
      }
      updated.push(item);
    }
    this.notifications = updated;
  }

  /**
   * 标记所有通知为已读
   */
  private async markAllRead() {
    if (this.uid === '0') {
      promptAction.showToast({ message: '请先登录' });
      return;
    }
    
    await NotificationStore.markAllRead(this.hostCtx(), this.uid);
    this.markNotificationsReadInMemory();
    
    // 触发全局状态同步
    const v = (AppStorage.get('notification_version') as number) ?? 0;
    AppStorage.set('notification_version', v + 1);
  }

  /**
   * 标记单个通知为已读
   */
  private async markNotificationRead(item: NotificationItem) {
    if (this.uid === '0') {
      return;
    }
    
    if (item.read) {
      return;
    }
    
    await NotificationStore.markRead(this.hostCtx(), this.uid, item.id);
    this.markNotificationReadInMemory(item.id);
    
    // 触发全局状态同步
    const v = (AppStorage.get('notification_version') as number) ?? 0;
    AppStorage.set('notification_version', v + 1);
  }

  /**
   * 跳转到通知关联的文章
   */
  private async openArticle(item: NotificationItem) {
    try {
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id: item.articleId }
      });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  /**
   * UI构建方法
   * 创建通知列表界面
   */
  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Text('←')
          .fontSize(20)
          .margin({ left: 16 })
          .onClick(() => router.back());

        Text('通知')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ right: 36 })

        // 全部已读按钮
        Text('全部已读')
          .fontSize(12)
          .opacity(0.7)
          .margin({ right: 16 })
          .onClick(async () => await this.markAllRead());
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
      } else if (this.notifications.length === 0) {
        // 空状态提示
        Text('暂无通知').margin(16).opacity(0.7)
          .opacity(this.listOpacity)
          .translate({ x: 0, y: this.listOffset })
      } else {
        // 通知列表
        List() {
          ForEach(this.notifications, (item: NotificationItem) => {
            ListItem() {
              Column({ space: 6 }) {
                // 通知标题行
                Row({ space: 6 }) {
                  // 未读状态指示器
                  if (!item.read) {
                    Text('●').fontSize(10).fontColor('#4C6FFF')
                  }
                  Text(this.renderTitle(item)).fontSize(14).fontWeight(FontWeight.Medium)
                }
                
                // 关联文章信息
                Text(`文章：${item.articleTitle}`).fontSize(12).opacity(0.7)
                
                // 通知内容（如果有）
                if (item.content) {
                  Text(item.content).fontSize(12).opacity(0.6).maxLines(2)
                }
                
                // 通知时间
                Text(this.formatTime(item.createdAt)).fontSize(11).opacity(0.5)
              }
              .width('100%')
              .padding(12)
              .margin({ bottom: 12 })
              .borderRadius(16)
              .backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#E9EEF5' })
              .onClick(async () => {
                // 点击通知：标记已读并跳转文章
                await this.markNotificationRead(item);
                await this.openArticle(item);
              })
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
    .onAppear(async () => {
      // 页面显示时的初始化
      await this.refresh();
      
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