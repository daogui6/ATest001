/**
 * 隐私中心页面 - 隐私设置与数据管理
 *
 * 功能概述：
 * - 管理隐私开关设置（个性化推荐/数据统计/广告偏好等）
 * - 查看隐私协议说明和政策内容
 * - 提供用户数据清理入口（浏览历史/离线下载等）
 * - 隐私设置的持久化存储和实时同步
 *
 * 架构特点：
 * - 简洁的状态管理设计（@State）
 * - 隐私设置的本地持久化存储
 * - 数据清理操作的全局状态同步
 * - 用户友好的设置界面和操作反馈
 *
 * 技术亮点：
 * - 隐私开关的实时状态同步
 * - 数据清理的全局状态通知机制
 * - 设置项的持久化存储管理
 * - 操作结果的即时用户反馈
 *
 * 隐私设置项：
 * - 个性化推荐：基于用户行为的个性化内容推荐
 * - 数据统计：匿名化数据收集用于产品优化
 * - 个性化广告：基于兴趣的广告内容展示
 *
 * 数据管理功能：
 * - 隐私政策查看：了解数据处理规范
 * - 浏览历史清理：清除个人浏览记录
 * - 离线下载清理：删除本地缓存内容
 *
 * 版本信息：
 * - 创建时间：2024年
 * - 依赖版本：HarmonyOS 4.0+
 * - 组件类型：页面级组件（@Entry）
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { Prefs } from '../store/Prefs';
import { HistoryStore } from '../store/HistoryStore';
import { DownloadStore } from '../store/DownloadStore';

/**
 * 隐私中心页面主组件
 *
 * @Entry 装饰器标记为页面入口组件
 * @Component 定义可复用的UI组件结构
 *
 * 核心职责：
 * - 管理用户隐私设置的完整生命周期
 * - 提供隐私政策查看和数据清理功能
 * - 确保隐私设置的持久化和实时同步
 * - 处理用户操作的安全性和合规性
 */
@Entry
@Component
export struct PrivacyCenterPage {
  // ==================== 隐私设置存储键名定义 ====================

  private KEY_PERSONALIZED = 'privacy.personalized';  // 个性化推荐设置键名
  private KEY_ANALYTICS = 'privacy.analytics';        // 数据统计设置键名
  private KEY_ADS = 'privacy.ads';                    // 广告偏好设置键名

  // ==================== 隐私设置状态管理 ====================

  @State personalized: boolean = true;    // 个性化推荐开关状态
  @State analytics: boolean = true;       // 数据统计开关状态
  @State ads: boolean = false;            // 个性化广告开关状态

  /**
   * 获取宿主上下文（UIAbility上下文）
   *
   * 用于访问应用级资源和执行数据存储操作
   *
   * @returns UIAbility上下文对象，用于数据持久化操作
   */
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /**
   * 组件生命周期方法：页面即将显示时调用
   *
   * 用于页面初始化操作，从持久化存储加载隐私设置
   * 确保页面显示时展示用户的当前隐私设置状态
   */
  async aboutToAppear() {
    const ctx = this.hostCtx();

    // 从持久化存储加载隐私设置，使用默认值作为兜底
    this.personalized = await Prefs.getBool(ctx, this.KEY_PERSONALIZED, true);
    this.analytics = await Prefs.getBool(ctx, this.KEY_ANALYTICS, true);
    this.ads = await Prefs.getBool(ctx, this.KEY_ADS, false);
  }

  /**
   * 保存隐私设置到持久化存储
   *
   * 将用户的隐私设置保存到本地存储，并提供操作反馈
   *
   * @param key 设置项的存储键名
   * @param value 设置项的新值
   */
  private async saveSetting(key: string, value: boolean) {
    // 保存设置到持久化存储
    await Prefs.putBool(this.hostCtx(), key, value);

    // 提供操作成功反馈
    promptAction.showToast({ message: '隐私设置已更新' });
  }

  /**
   * 打开隐私政策说明对话框
   *
   * 以对话框形式展示隐私政策内容，确保用户知情同意
   * 提供简洁明了的隐私政策说明
   */
  private async openPolicy() {
    promptAction.showDialog({
      title: '隐私政策',
      message: '我们仅在提供服务所需范围内处理必要信息，并采取合理措施保护您的数据安全。',
      buttons: [{ text: '我知道了', color: '#4C6FFF' }]
    });
  }

  /**
   * 清除用户浏览历史数据
   *
   * 完整的浏览历史清理流程：
   * 1. 从存储中清除浏览历史记录
   * 2. 触发全局状态同步（通知其他页面更新）
   * 3. 提供操作成功反馈
   */
  private async clearHistory() {
    // 1. 清除浏览历史记录
    await HistoryStore.clear(this.hostCtx());

    // 2. 触发全局状态同步：通知其他页面浏览历史已更新
    AppStorage.setOrCreate('history_version', 0);
    const v = (AppStorage.get('history_version') as number) ?? 0;
    AppStorage.set('history_version', v + 1);

    // 3. 提供操作成功反馈
    promptAction.showToast({ message: '浏览历史已清除' });
  }

  /**
   * 清除用户离线下载内容
   *
   * 完整的离线下载清理流程：
   * 1. 获取当前用户ID
   * 2. 从存储中清除离线下载记录
   * 3. 触发全局状态同步（通知其他页面更新）
   * 4. 提供操作成功反馈
   */
  private async clearDownloads() {
    const ctx = this.hostCtx();

    // 1. 获取当前用户ID
    const uid = await DownloadStore.getUid(ctx);

    // 2. 清除用户的离线下载记录
    await DownloadStore.clearDownloads(ctx, uid);

    // 3. 触发全局状态同步：通知其他页面离线下载已更新
    AppStorage.setOrCreate('download_version', 0);
    const v = (AppStorage.get('download_version') as number) ?? 0;
    AppStorage.set('download_version', v + 1);

    // 4. 提供操作成功反馈
    promptAction.showToast({ message: '离线下载已清除' });
  }

  /**
   * 页面UI构建方法
   *
   * 采用卡片式布局，提供清晰的隐私设置界面：
   * - Stack布局：背景层 + 内容层分离
   * - Scroll容器：支持内容滚动浏览
   * - 分组设计：隐私设置和数据管理分开显示
   * - 直观的操作控件：开关和按钮
   *
   * 布局层次：
   * 1. Stack层：背景图片 + 主内容区域
   * 2. Column层：头部导航 + 滚动内容
   * 3. 卡片分组：隐私设置卡片 + 数据管理卡片
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
        Row() {
          // 返回按钮：提供页面导航功能
          Text('←')
            .fontSize(20)
            .margin({ left: 16 })
            .onClick(() => router.back());

          // 页面标题：居中显示，突出页面功能
          Text('隐私中心')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Blank().width(36)  // 占位元素：保持布局平衡
        }
        .alignItems(VerticalAlign.Center)
        .padding({ top: 16, right: 16, bottom: 12 })

        // ==================== 主体内容区域 ====================
        Scroll() {
          Column({ space: 16 }) {
            // ==================== 隐私设置卡片 ====================
            Column({ space: 10 }) {
              // 分组标题
              Text('隐私设置').fontSize(16).fontWeight(FontWeight.Medium)

              // 个性化推荐开关
              Row() {
                Text('个性化推荐').fontSize(14)
                Blank().layoutWeight(1)  // 弹性空间：实现右对齐
                Toggle({ type: ToggleType.Switch, isOn: this.personalized })
                  .onChange(async (value: boolean) => {
                    this.personalized = value;
                    await this.saveSetting(this.KEY_PERSONALIZED, value);
                  })
              }

              // 数据统计开关
              Row() {
                Text('使用数据统计优化体验').fontSize(14)
                Blank().layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.analytics })
                  .onChange(async (value: boolean) => {
                    this.analytics = value;
                    await this.saveSetting(this.KEY_ANALYTICS, value);
                  })
              }

              // 个性化广告开关
              Row() {
                Text('个性化广告').fontSize(14)
                Blank().layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.ads })
                  .onChange(async (value: boolean) => {
                    this.ads = value;
                    await this.saveSetting(this.KEY_ADS, value);
                  })
              }
            }
            .padding(16)
            .borderRadius(16)
            .backgroundColor('#FFFFFF')
            .border({ width: 1, color: '#E9EEF5' })
            .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })

            // ==================== 数据管理卡片 ====================
            Column({ space: 10 }) {
              // 分组标题
              Text('数据管理').fontSize(16).fontWeight(FontWeight.Medium)

              // 隐私政策查看按钮
              Button('查看隐私政策', { type: ButtonType.Capsule })
                .onClick(async () => await this.openPolicy())

              // 浏览历史清理按钮（黄色警示色）
              Button('清除浏览历史', { type: ButtonType.Capsule })
                .backgroundColor('#FEF3C7')
                .fontColor('#92400E')
                .onClick(async () => await this.clearHistory())

              // 离线下载清理按钮（红色警示色）
              Button('清除离线下载', { type: ButtonType.Capsule })
                .backgroundColor('#FEE2E2')
                .fontColor('#B91C1C')
                .onClick(async () => await this.clearDownloads())
            }
            .padding(16)
            .borderRadius(16)
            .backgroundColor('#FFFFFF')
            .border({ width: 1, color: '#E9EEF5' })
            .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })
          }
          .padding({ left: 16, right: 16, bottom: 16 })
        }
        .layoutWeight(1)  // 弹性布局：占据剩余垂直空间
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}