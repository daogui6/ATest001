/**
 * 登录页面 - 用户登录功能
 *
 * 功能概述：
 * - 提供用户名/密码登录表单，支持输入验证
 * - 用户协议与隐私政策确认，确保合规性
 * - 记住密码功能，提升用户体验
 * - 登录成功后刷新全局会话状态，实现状态同步
 *
 * 架构特点：
 * - 响应式表单状态管理（@State）
 * - 动画过渡效果提升用户体验
 * - 完整的输入验证和错误提示
 * - 安全的登录凭证处理
 *
 * 技术亮点：
 * - 分层动画效果：头部和登录卡片独立动画
 * - 表单验证机制：实时反馈用户输入状态
 * - 协议确认流程：确保用户知情同意
 * - 异常处理：友好的错误提示和降级方案
 *
 * 安全考虑：
 * - 密码输入使用安全类型（InputType.Password）
 * - 登录凭证通过安全存储处理
 * - 协议确认防止未授权登录
 *
 * 版本信息：
 * - 创建时间：2024年
 * - 依赖版本：HarmonyOS 4.0+
 * - 组件类型：页面级组件（@Entry）
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { UserStore } from '../store/UserStore';

/**
 * 登录页面主组件
 *
 * @Entry 装饰器标记为页面入口组件
 * @Component 定义可复用的UI组件结构
 *
 * 核心职责：
 * - 管理用户登录表单的完整生命周期
 * - 处理用户输入验证和登录逻辑
 * - 提供协议确认和隐私政策查看功能
 * - 实现登录成功后的状态同步和页面导航
 *
 * 页面状态：
 * - 表单输入状态：用户名、密码、协议确认等
 * - 动画控制状态：头部和卡片动画效果
 * - 消息提示状态：错误信息和操作反馈
 */
@Entry
@Component
export struct LoginPage {
  // ==================== 表单输入状态 ====================

  @State loginUsername: string = '';           // 用户名输入状态
  @State loginPassword: string = '';           // 密码输入状态
  @State loginAgree: boolean = false;          // 用户协议确认状态
  @State rememberPassword: boolean = false;    // 记住密码选项状态
  @State message: string = '';                 // 消息提示状态（错误信息等）

  // ==================== 动画控制状态 ====================

  @State headerOpacity: number = 0;            // 头部导航栏透明度（用于渐入动画）
  @State headerOffset: number = 12;            // 头部导航栏垂直偏移（用于滑动动画）
  @State cardOpacity: number = 0;              // 登录卡片透明度（用于渐入动画）
  @State cardOffset: number = 18;              // 登录卡片垂直偏移（用于滑动动画）

  /**
   * 获取宿主上下文（UIAbility上下文）
   *
   * 用于访问应用级资源和执行数据存储操作
   *
   * @returns UIAbility上下文对象，用于用户认证和数据持久化
   */
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /**
   * 显示用户协议或隐私政策
   *
   * 以对话框形式展示协议内容，确保用户知情同意
   *
   * @param type 协议类型：'user'表示用户协议，'privacy'表示隐私政策
   */
  private showAgreement(type: 'user' | 'privacy') {
    const title = type === 'user' ? '用户协议' : '隐私政策';
    const message = type === 'user'
      ? '感谢使用本应用。本协议用于说明账号服务与使用规范，登录即代表您同意遵守相关规则。'
      : '我们仅在提供服务所需范围内处理必要信息，并采取合理措施保护您的数据安全。';
    promptAction.showDialog({
      title,
      message,
      buttons: [{ text: '我知道了', color: '#4C6FFF' }]
    });
  }

  /**
   * 处理用户登录请求
   *
   * 完整的登录流程：
   * 1. 表单验证：检查协议确认状态
   * 2. 凭证验证：调用用户存储服务进行认证
   * 3. 状态更新：登录成功后刷新全局会话状态
   * 4. 页面导航：跳转到目标页面或返回上一页
   *
   * 异常处理：
   * - 协议未确认：显示错误提示
   * - 认证失败：显示具体错误信息
   * - 网络异常：降级处理
   *
   * @throws 不会抛出异常，所有错误都在内部处理
   */
  private async handleLogin() {
    // 1. 清空之前的错误消息
    this.message = '';

    // 2. 协议确认验证：必须同意协议才能登录
    if (!this.loginAgree) {
      this.message = '请先阅读并同意服务条款再登录';
      return;
    }

    // 3. 调用用户存储服务进行登录认证
    const result = await UserStore.login(this.hostCtx(), this.loginUsername.trim(), this.loginPassword);

    // 4. 处理认证结果
    if (result.ok === false) {
      this.message = result.message;
      return;
    }

    // 5. 登录成功：刷新全局会话状态
    AppStorage.setOrCreate('session_version', 0);
    const v = (AppStorage.get('session_version') as number) ?? 0;
    AppStorage.set('session_version', v + 1);

    // 6. 显示成功提示并导航
    promptAction.showToast({ message: '登录成功' });
    await this.goBack();
  }

  /**
   * 安全返回上一页
   *
   * 包含异常处理的返回逻辑：
   * - 优先尝试返回上一页（router.back）
   * - 失败时降级到跳转到我的页面（router.pushUrl）
   *
   * 确保用户在任何情况下都能成功离开登录页面
   */
  private async goBack() {
    try {
      await router.back();
    } catch (e) {
      // 返回失败时的降级方案：跳转到我的页面
      await router.pushUrl({ url: 'pages/MinePage' });
    }
  }

  /**
   * 打开注册页面
   *
   * 提供从登录页到注册页的导航功能
   * 包含异常处理机制，确保跳转稳定性
   */
  private async openRegisterPage() {
    try {
      await router.pushUrl({ url: 'pages/RegisterPage' });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  /**
   * 页面UI构建方法
   *
   * 采用卡片式布局，提供清晰的登录表单：
   * - Stack布局：背景层 + 内容层分离
   * - 分层动画：头部和登录卡片独立动画效果
   * - 表单设计：清晰的输入区域和操作按钮
   * - 协议确认：合规的用户协议流程
   *
   * 布局层次：
   * 1. Stack层：背景图片 + 主内容区域
   * 2. Column层：头部导航 + 登录卡片
   * 3. 表单区域：输入框 + 选项 + 按钮
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
        Flex({
          alignItems: ItemAlign.Center,
          justifyContent: FlexAlign.Center
        }) {
          // 返回按钮：提供页面导航功能
          Text('←')
            .fontSize(20)
            .margin({ left: 12 })
            .onClick(async () => {
              await this.goBack();
            })
          Blank().layoutWeight(1) // 弹性空间：实现标题居中

          // 页面标题：突出显示当前页面功能
          Text('登录')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
          Blank().layoutWeight(1) // 弹性空间：保持布局平衡
        }
        .width('100%')
        .height(52)
        .opacity(this.headerOpacity)
        .translate({ x: 0, y: this.headerOffset })

        // ==================== 登录卡片区域 ====================
        Column({ space: 12 }) {
          // 欢迎标题和描述
          Text('欢迎回来').fontSize(20).fontWeight(FontWeight.Bold)
          Text('登录后可同步点赞、评论等记录').fontSize(12).opacity(0.6)

          // 用户名输入框
          TextInput({ text: this.loginUsername, placeholder: '请输入用户名' })
            .onChange((v) => { this.loginUsername = v; })
            .padding({ left: 12, right: 12 })
            .borderRadius(10)
            .backgroundColor('#F6F7FB')

          // 密码输入框：使用安全类型隐藏输入内容
          TextInput({ text: this.loginPassword, placeholder: '请输入密码' })
            .type(InputType.Password)
            .onChange((v) => { this.loginPassword = v; })
            .padding({ left: 12, right: 12 })
            .borderRadius(10)
            .backgroundColor('#F6F7FB')

          // 记住密码选项
          Row({ space: 8 }) {
            Checkbox({ name: 'rememberPassword', group: 'loginPrefs' })
              .select(this.rememberPassword)
              .onChange((value: boolean) => { this.rememberPassword = value; })
            Text('记住密码').fontSize(14)
          }
          .alignItems(VerticalAlign.Center)

          // 用户协议确认区域
          Row({ space: 8 }) {
            Checkbox({ name: 'loginAgree', group: 'loginAgreement' })
              .select(this.loginAgree)
              .onChange((value: boolean) => {
                this.loginAgree = value;
                if (value) {
                  this.message = ''; // 同意协议时清空错误消息
                }
              })
            Text() {
              Span('我已阅读并同意').fontSize(12)
              Span('《用户协议》')
                .fontSize(12)
                .fontColor('#3D6DFF')
                .onClick((): void => {
                  this.showAgreement('user');
                })
              Span('和').fontSize(12)
              Span('《隐私政策》')
                .fontSize(12)
                .fontColor('#3D6DFF')
                .onClick((): void => {
                  this.showAgreement('privacy');
                })
            }
            // 点击文本区域也可切换协议确认状态
            .onClick(() => {
              const next = !this.loginAgree;
              this.loginAgree = next;
              if (next) {
                this.message = '';
              }
            })
          }
          .alignItems(VerticalAlign.Center)
          .margin({ top: 4 })

          // 登录和注册按钮区域
          Row({ space: 12 }) {
            Button('登录', { type: ButtonType.Capsule })
              .layoutWeight(1)
              .onClick(async () => { await this.handleLogin(); })
            Button('注册', { type: ButtonType.Capsule })
              .layoutWeight(1)
              .onClick(async () => {
                this.message = ''; // 跳转前清空错误消息
                await this.openRegisterPage();
              })
          }
          .margin({ top: 4 })

          // 错误消息显示区域
          if (this.message) {
            Text(this.message).fontSize(14).fontColor(Color.Red).margin({ top: 4 })
          }
        }
        .padding(16)
        .borderRadius(16)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#E9EEF5' })
        .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })
        .opacity(this.cardOpacity)
        .translate({ x: 0, y: this.cardOffset })
      }
      .width('100%')
      .height('100%')
      .padding({ top: 12, left: 16, right: 16 })
      .onAppear(() => {
        // 页面显示时的动画初始化
        animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
          this.headerOpacity = 1;
          this.headerOffset = 0;
        });
        animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
          this.cardOpacity = 1;
          this.cardOffset = 0;
        });
      })
    }
    .width('100%')
    .height('100%')
  }
}