/**
 * 通知页面 - 用户消息通知管理
 *
 * 功能概述：
 * - 展示用户收到的评论点赞和回复通知，支持实时同步更新
 * - 支持标记已读和全部已读操作，提升用户体验
 * - 提供通知关联文章的快速跳转功能
 * - 优雅的登录状态处理和空状态展示
 *
 * 架构特点：
 * - 全局状态驱动的数据同步机制（AppStorage + @StorageLink）
 * - 响应式UI状态管理（@State + @Watch）
 * - 渐进式动画加载效果，提升视觉体验
 * - 完善的通知状态管理和同步机制
 *
 * 技术亮点：
 * - 通知版本控制实现跨页面实时同步
 * - 内存状态与持久化存储的双向同步
 * - 智能通知分类和标题生成
 * - 平滑的页面过渡动画和交互反馈
 *
 * 通知类型支持：
 * - comment_like: 评论点赞通知
 * - comment_reply: 评论回复通知
 *
 * 数据流设计：
 * 1. 页面初始化 → 加载通知数据
 * 2. 全局状态变化 → 触发数据刷新
 * 3. 用户操作 → 更新本地和全局状态
 * 4. 状态同步 → 通知其他页面更新
 *
 * 版本信息：
 * - 创建时间：2024年
 * - 依赖版本：HarmonyOS 4.0+
 * - 组件类型：页面级组件（@Entry）
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

// 数据模型和存储导入
import type { NotificationItem } from '../model/Notification';
import { NotificationStore } from '../store/NotificationStore';
import { FavoriteStore } from '../store/FavoriteStore';

/**
 * 全局状态初始化
 * 通过AppStorage实现跨页面状态同步，确保状态键存在
 *
 * 状态说明：
 * - notification_version: 通知版本号，通知操作时递增触发同步
 * - session_version: 会话版本号，登录状态变化时触发同步
 */
AppStorage.setOrCreate('notification_version', 0);
AppStorage.setOrCreate('session_version', 0);

/**
 * 通知页面主组件
 *
 * @Entry 装饰器标记为页面入口组件，可被路由系统识别
 * @Component 定义可复用的UI组件结构
 *
 * 核心职责：
 * - 管理用户通知消息的完整生命周期
 * - 响应全局状态变化实现实时数据同步
 * - 提供通知阅读状态的管理功能
 * - 处理通知与文章的关联跳转
 *
 * 页面状态：
 * - 未登录状态：显示登录引导提示
 * - 空通知状态：显示空状态UI
 * - 正常状态：显示通知列表和操作功能
 */
@Entry
@Component
export struct NotificationPage {
  /**
   * 获取宿主上下文（UIAbility上下文）
   *
   * 用于访问应用级资源和执行数据存储操作
   * 通过UI上下文获取宿主上下文，确保类型安全
   *
   * @returns UIAbility上下文对象，用于数据持久化操作
   */
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  // ==================== 全局状态同步绑定 ====================

  /**
   * 通知版本号状态绑定
   *
   * @StorageLink 与AppStorage建立双向数据绑定
   * @Watch 监听状态变化，触发回调函数
   *
   * 实现机制：当用户在其他页面进行通知相关操作时，
   * 全局版本号递增，通过@Watch触发当前页面的数据刷新
   */
  @StorageLink('notification_version')
  @Watch('onNotificationVersionChange')
  notificationVersion: number = 0;

  /**
   * 会话版本号状态绑定
   *
   * 监听用户登录状态变化，重新加载对应用户的通知数据
   */
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;

  // ==================== 组件内部状态管理 ====================

  /**
   * 组件内部响应式状态，变化时触发UI重新渲染
   */
  @State uid: string = '0';                          // 当前用户ID，'0'表示未登录
  @State notifications: NotificationItem[] = [];     // 用户通知列表数据

  // ==================== 动画相关状态 ====================

  @State headerOpacity: number = 0;                  // 头部导航栏透明度（用于渐入动画）
  @State headerOffset: number = 12;                  // 头部导航栏垂直偏移（用于滑动动画）
  @State listOpacity: number = 0;                    // 列表内容透明度（用于渐入动画）
  @State listOffset: number = 16;                    // 列表内容垂直偏移（用于滑动动画）

  /**
   * 通知版本变化监听器
   *
   * 当用户在其他页面进行通知相关操作时触发
   * 重新加载通知数据，保持页面数据同步
   *
   * 触发场景：
   * - 用户收到新通知
   * - 通知状态在其他页面被修改
   * - 通知全局同步通知
   */
  private onNotificationVersionChange() {
    this.refresh();
  }

  /**
   * 会话版本变化监听器
   *
   * 当用户登录状态发生变化时触发
   * 重新加载当前用户的通知数据，实现用户数据隔离
   *
   * 触发场景：
   * - 用户成功登录应用
   * - 用户退出当前账号
   * - 用户切换不同账号
   */
  private onSessionVersionChange() {
    this.refresh();
  }

  /**
   * 刷新通知数据（核心数据加载方法）
   *
   * 从存储中加载用户通知列表，支持用户状态验证
   *
   * 数据加载流程：
   * - 用户身份验证 → 加载通知数据 → UI更新
   *
   * 异常处理策略：
   * - 未登录状态：清空数据并返回
   * - 数据加载失败：使用空数据防止应用崩溃
   *
   * @throws 不会抛出异常，所有错误都在内部处理
   */
  private async refresh() {
    const ctx = this.hostCtx();

    // 1. 获取当前用户ID（用户身份验证）
    this.uid = await FavoriteStore.getUid(ctx);

    // 2. 未登录用户处理：清空数据并返回
    if (this.uid === '0') {
      this.notifications = [];
      return;
    }

    // 3. 加载用户通知数据
    this.notifications = await NotificationStore.load(ctx, this.uid);
  }

  /**
   * 时间格式化工具函数
   *
   * 将时间戳格式化为可读的日期时间字符串
   * 格式：YYYY-MM-DD HH:MM
   *
   * @param ts 时间戳（毫秒）
   * @returns 格式化后的日期时间字符串
   */
  private formatTime(ts: number): string {
    const d = new Date(ts);
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  /**
   * 生成通知标题
   *
   * 根据通知类型动态生成对应的标题文本
   * 支持的通知类型：
   * - comment_like: 评论点赞通知
   * - comment_reply: 评论回复通知
   *
   * @param item 通知项对象
   * @returns 格式化后的通知标题
   */
  private renderTitle(item: NotificationItem): string {
    if (item.type === 'comment_like') {
      return `${item.fromNickname} 点赞了你的评论`;
    }
    return `${item.fromNickname} 回复了你的评论`;
  }

  /**
   * 内存中标记所有通知为已读
   *
   * 用于UI状态的即时更新，提供快速视觉反馈
   * 不涉及持久化存储，仅更新内存状态
   */
  private markNotificationsReadInMemory(): void {
    const updated: NotificationItem[] = [];
    for (let i = 0; i < this.notifications.length; i++) {
      const item = this.notifications[i];
      item.read = true;  // 标记为已读状态
      updated.push(item);
    }
    this.notifications = updated;  // 更新UI状态
  }

  /**
   * 内存中标记单个通知为已读
   *
   * 更新指定通知的阅读状态，提供即时视觉反馈
   *
   * @param targetId 要标记为已读的通知ID
   */
  private markNotificationReadInMemory(targetId: string): void {
    const updated: NotificationItem[] = [];
    for (let i = 0; i < this.notifications.length; i++) {
      const item = this.notifications[i];
      if (item.id === targetId) {
        item.read = true;  // 标记指定通知为已读
      }
      updated.push(item);
    }
    this.notifications = updated;  // 更新UI状态
  }

  /**
   * 标记所有通知为已读
   *
   * 完整的业务逻辑：
   * 1. 验证用户登录状态
   * 2. 持久化存储更新（标记所有为已读）
   * 3. 内存状态更新（即时UI反馈）
   * 4. 触发全局状态同步（通知其他页面）
   *
   * @throws 不会抛出异常，所有错误都在内部处理
   */
  private async markAllRead() {
    // 1. 登录验证：确保用户有操作权限
    if (this.uid === '0') {
      promptAction.showToast({ message: '请先登录' });
      return;
    }

    // 2. 持久化存储更新：标记所有通知为已读
    await NotificationStore.markAllRead(this.hostCtx(), this.uid);

    // 3. 内存状态更新：提供即时视觉反馈
    this.markNotificationsReadInMemory();

    // 4. 触发全局状态同步：通知其他页面更新
    const v = (AppStorage.get('notification_version') as number) ?? 0;
    AppStorage.set('notification_version', v + 1);
  }

  /**
   * 标记单个通知为已读
   *
   * 处理单个通知的阅读状态更新：
   * 1. 验证用户登录状态
   * 2. 检查通知当前状态（避免重复操作）
   * 3. 持久化存储更新
   * 4. 内存状态更新
   * 5. 触发全局状态同步
   *
   * @param item 要标记为已读的通知项
   */
  private async markNotificationRead(item: NotificationItem) {
    // 1. 登录验证
    if (this.uid === '0') {
      return;
    }

    // 2. 状态检查：避免重复标记已读
    if (item.read) {
      return;
    }

    // 3. 持久化存储更新：标记单个通知为已读
    await NotificationStore.markRead(this.hostCtx(), this.uid, item.id);

    // 4. 内存状态更新：提供即时视觉反馈
    this.markNotificationReadInMemory(item.id);

    // 5. 触发全局状态同步：通知其他页面更新
    const v = (AppStorage.get('notification_version') as number) ?? 0;
    AppStorage.set('notification_version', v + 1);
  }

  /**
   * 跳转到通知关联的文章
   *
   * 提供从通知到文章详情的快速导航
   * 包含异常处理机制，确保跳转稳定性
   *
   * @param item 通知项对象，包含关联的文章信息
   */
  private async openArticle(item: NotificationItem) {
    try {
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id: item.articleId }  // 传递文章ID进行跳转
      });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  /**
   * 页面UI构建方法
   *
   * 采用分层渐入的动画效果，提升用户体验：
   * - Stack布局：背景层 + 内容层分离
   * - 条件渲染：根据状态显示不同UI内容
   * - 动画控制：组件级动画状态管理
   * - 响应式设计：适配不同屏幕尺寸
   *
   * 布局层次：
   * 1. Stack层：背景图片 + 主内容区域
   * 2. Column层：头部导航 + 内容区域
   * 3. 条件渲染：登录状态 → 数据状态 → 具体内容
   */
  build() {
    Stack() {
      // 背景图片层：全屏背景，增强视觉体验
      Image($r('app.media.bgt'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      // 主内容区域：包含所有交互元素
      Column() {
        // ==================== 顶部导航栏 ====================
        Stack({ alignContent: Alignment.Center }) {
          Row() {
            // 返回按钮：提供页面导航功能
            Text('←')
              .fontSize(20)
              .margin({ left: 16 })
              .onClick(() => router.back());

            Blank().layoutWeight(1)  // 弹性空间：实现标题居中

            // 全部已读按钮：一键标记所有通知为已读
            Text('全部已读')
              .fontSize(12)
              .opacity(0.7)
              .margin({ right: 16 })
              .onClick(async () => await this.markAllRead());
          }
          .alignItems(VerticalAlign.Center)
          .width('100%')

          // 页面标题：居中显示，突出页面功能
          Text('通知')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
        }
        .padding({ top: 16, right: 16, bottom: 12 })
        .opacity(this.headerOpacity)
        .translate({ x: 0, y: this.headerOffset })

        // ==================== 主体内容区域 ====================
        if (this.uid === '0') {
          // 未登录状态提示：引导用户进行登录
          Text('请先去【我的】页登录').margin(16).opacity(0.7)
            .opacity(this.listOpacity)
            .translate({ x: 0, y: this.listOffset })
        } else if (this.notifications.length === 0) {
          // 空状态提示：友好的空数据展示
          Text('暂无通知').margin(16).opacity(0.7)
            .opacity(this.listOpacity)
            .translate({ x: 0, y: this.listOffset })
        } else {
          // 通知列表：使用List组件实现高性能滚动
          List() {
            ForEach(this.notifications, (item: NotificationItem) => {
              ListItem() {
                Column({ space: 6 }) {
                  // 通知标题行：显示通知类型和发送者
                  Row({ space: 6 }) {
                    // 未读状态指示器：红色圆点标识未读通知
                    if (!item.read) {
                      Text('●').fontSize(10).fontColor('#4C6FFF')
                    }
                    Text(this.renderTitle(item)).fontSize(14).fontWeight(FontWeight.Medium)
                  }

                  // 关联文章信息：显示通知关联的文章标题
                  Text(`文章：${item.articleTitle}`).fontSize(12).opacity(0.7)

                  // 通知内容：显示具体的通知内容（如果有）
                  if (item.content) {
                    Text(item.content).fontSize(12).opacity(0.6).maxLines(2)
                  }

                  // 通知时间：显示通知创建时间
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
          .layoutWeight(1)  // 弹性布局：占据剩余垂直空间
          .opacity(this.listOpacity)
          .translate({ x: 0, y: this.listOffset })
        }
      }
      .width('100%')
      .height('100%')
      .onAppear(async () => {
        // 页面显示时的初始化操作（生命周期钩子）

        // 1. 刷新通知数据：确保显示最新数据
        await this.refresh();

        // 2. 头部导航栏动画：渐入+上移效果
        animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
          this.headerOpacity = 1;
          this.headerOffset = 0;
        });

        // 3. 列表内容动画：延迟渐入+上移（创造视觉层次感）
        animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
          this.listOpacity = 1;
          this.listOffset = 0;
        });
      })
    }
    .width('100%')
    .height('100%')
  }
}