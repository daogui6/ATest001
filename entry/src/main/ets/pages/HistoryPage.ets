/**
 * 历史记录页面 - 用户阅读历史管理
 * 
 * 功能概述：
 * - 展示用户阅读过的文章历史记录
 * - 支持清空历史记录功能
 * - 提供历史文章快速跳转
 * - 实时同步阅读历史变化
 * 
 * 架构特点：
 * - 全局状态驱动的数据同步机制
 * - 渐进式动画加载效果
 * - 简洁的列表展示界面
 * - 响应式UI状态管理
 * 
 * 技术亮点：
 * - 历史版本控制实现实时同步
 * - 平滑的页面过渡动画
 * - 安全的页面跳转机制
 * - 优雅的空状态处理
 */

// 导入HarmonyOS系统模块
import type common from '@ohos.app.ability.common'; // UIAbility上下文类型
import promptAction from '@ohos.promptAction'; // 用户提示操作
import router from '@ohos.router'; // 页面路由导航

// 导入应用数据模型和存储模块
import type { Article } from '../model/Article'; // 文章数据模型
import { HistoryStore } from '../store/HistoryStore'; // 历史记录存储管理

/**
 * 全局状态初始化
 * 通过AppStorage实现跨页面状态同步
 * history_version: 历史版本号，阅读操作时递增触发同步
 */
AppStorage.setOrCreate('history_version', 0);

/**
 * 历史记录页面主组件
 * 
 * Entry装饰器标记为页面入口组件
 * Component定义可复用的UI组件结构
 * 
 * 核心职责：
 * - 管理用户阅读历史记录
 * - 响应全局状态变化实时更新
 * - 提供历史记录的浏览和清理功能
 */
@Entry
@Component
export struct HistoryPage {
  /**
   * 获取宿主上下文
   * 用于访问UIAbility上下文，执行数据存储等操作
   */
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /**
   * 组件内部状态管理
   * State管理的响应式状态，变化时触发UI重新渲染
   */
  @State history: Article[] = []; // 阅读历史文章列表
  @State loading: boolean = false; // 数据加载状态
  
  // 动画相关状态
  @State headerOpacity: number = 0; // 头部导航栏透明度
  @State headerOffset: number = 12; // 头部导航栏垂直偏移
  @State listOpacity: number = 0; // 列表内容透明度
  @State listOffset: number = 16; // 列表内容垂直偏移
  
  /**
   * 全局状态同步绑定
   * StorageLink与AppStorage建立双向数据绑定
   * Watch监听状态变化，触发回调函数
   * 
   * 实现机制：当用户在其他页面阅读文章时，
   * 全局版本号递增，触发当前页面的数据刷新
   */
  @StorageLink('history_version')
  @Watch('onHistoryVersionChange')
  historyVersion: number = 0; // 历史版本号，阅读操作时递增

  /**
   * 组件生命周期：页面即将显示
   * 在此阶段执行数据初始化操作
   */
  async aboutToAppear() {
    await this.loadHistory();
  }

  /**
   * 历史版本变化监听器
   * 当用户在其他页面阅读文章时触发
   * 重新加载历史记录数据
   */
  private onHistoryVersionChange() {
    this.loadHistory();
  }

  /**
   * 加载历史记录数据
   * 从本地存储中读取用户的阅读历史
   */
  private async loadHistory() {
    this.loading = true; // 开始加载
    const list = await HistoryStore.loadHistory(this.hostCtx()); // 从存储加载数据
    this.history = list; // 更新历史记录
    this.loading = false; // 加载完成
  }

  /**
   * 清空历史记录
   * 清除用户的所有阅读历史
   */
  private async clearHistory() {
    await HistoryStore.clear(this.hostCtx()); // 清除存储中的数据
    this.history = []; // 更新本地状态
    promptAction.showToast({ message: '已清空历史' }); // 用户反馈
  }

  /**
   * 安全跳转到文章详情页
   * 包含异常处理机制，确保跳转稳定性
   * 
   * @param id 要查看的文章ID
   */
  private async openDetail(id: number) {
    try {
      // 跳转到文章详情页，传递文章ID
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id }
      });
    } catch (e) {
      // 跳转失败时的友好提示
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  /**
   * 页面UI构建
   * 采用分层渐入的动画效果，提升用户体验
   */
  build() {
    Column() {
      // 顶部导航栏
      Row() {
        // 返回按钮
        Text('←')
          .fontSize(20)
          .margin({ left: 16 })
          .onClick(() => router.back());

        // 页面标题
        Text('阅读历史')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 动态操作按钮：有历史时显示清空按钮，无历史时显示占位
        if (this.history.length > 0) {
          Button('清空', { type: ButtonType.Capsule })
            .onClick(async () => await this.clearHistory());
        } else {
          Blank().width(78) // 占位保持布局平衡
        }
      }
      .alignItems(VerticalAlign.Center)
      .padding({ top: 16, right: 16, bottom: 12 })
      .opacity(this.headerOpacity)
      .translate({ x: 0, y: this.headerOffset })

      // 主体内容区域
      if (this.loading) {
        // 加载中状态
        Row({ space: 8 }) {
          LoadingProgress()
          Text('正在加载历史...').opacity(0.7)
        }
        .padding(16)
        .opacity(this.listOpacity)
        .translate({ x: 0, y: this.listOffset })
      } else if (this.history.length === 0) {
        // 空状态提示
        Text('暂无阅读记录').margin(16).opacity(0.7)
          .opacity(this.listOpacity)
          .translate({ x: 0, y: this.listOffset })
      } else {
        // 历史记录列表
        List() {
          ForEach(this.history, (item: Article) => {
            ListItem() {
              Row() {
                Column({ space: 6 }) {
                  // 文章标题
                  Text(item.title).fontSize(16).fontWeight(FontWeight.Medium)
                  // 文章描述
                  Text(item.desc).fontSize(13).opacity(0.7).maxLines(2)
                  // 作者信息
                  Text(`作者：${item.author}`).fontSize(12).opacity(0.6)
                }
                .layoutWeight(1) // 占据剩余空间
              }
              .padding(12)
              .margin({ left: 16, right: 16, bottom: 12 })
              .borderRadius(16)
              .backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#E9EEF5' }) // 细边框增强视觉层次
              .onClick(async () => await this.openDetail(item.id))
            }
          })
        }
        .width('100%')
        .layoutWeight(1) // 占据剩余垂直空间
        .opacity(this.listOpacity)
        .translate({ x: 0, y: this.listOffset })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F7FB') // 浅灰色背景提升内容可读性
    .onAppear(() => {
      // 页面显示时的动画效果
      
      // 头部导航栏动画：渐入+上移
      animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.headerOpacity = 1;
        this.headerOffset = 0;
      });
      
      // 列表内容动画：延迟渐入+上移（创造层次感）
      animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
        this.listOpacity = 1;
        this.listOffset = 0;
      });
    })
  }
}